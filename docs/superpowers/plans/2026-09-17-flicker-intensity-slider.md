# Flicker Intensity Slider & Dip Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the "near-off" dip mechanism from the candle flicker simulation and add a persisted, global intensity slider that scales flicker amplitude around each preset's mean, with a hard floor so the torch never looks off.

**Architecture:** Pure computation (noise → level → intensity-scaled level with floor) lives in `FlickerPreset` as a testable, `AVCaptureDevice`-independent function. `TorchController` owns the mutable `intensity` state (persisted via `UserDefaults`) and calls into that pure function each tick. `ContentView` adds a `Slider` bound to `TorchController.intensity`.

**Tech Stack:** Swift 5.0, SwiftUI, AVFoundation, XCTest, xcodegen-generated Xcode project (`Candle.xcodeproj`, scheme `Candle`).

## Global Constraints

- Deployment target: iOS 17.0 (from `project.yml`).
- No new dependencies; standard library / Foundation / SwiftUI / AVFoundation only.
- `floorLevel = 0.15` is a fixed constant, applied regardless of preset or intensity — the torch must never render at a level a user would perceive as "off".
- Intensity is a single global `Double` in `0...1`, shared across all three presets (not per-preset).
- Intensity is persisted in `UserDefaults` under key `"flickerIntensity"`, restored on next launch; default `1.0` when no stored value exists.
- Preset selection persistence is explicitly out of scope (unchanged from current behavior).
- The dip mechanism (`dipChance`, `dipTicksRemaining`, `dipLevel`) is removed entirely — no preset produces intentional near-off dips anymore.
- Tuning the exact preset ranges (e.g. widening "Sanft") is out of scope for this plan — a follow-up after manual on-device testing.

---

### Task 1: Remove the dip mechanism from `FlickerPreset`

**Files:**
- Modify: `Candle/Models/FlickerPreset.swift`
- Modify: `CandleTests/FlickerPresetTests.swift`

**Interfaces:**
- Produces: `FlickerPreset.init(name: String, minLevel: Float, maxLevel: Float, timeStep: Double)` — no `dipChance` parameter. `FlickerPreset.level(forNoise:)` unchanged.

- [ ] **Step 1: Update `FlickerPreset.swift` — drop `dipChance`**

Replace the full file contents:

```swift
struct FlickerPreset: Hashable {
    let name: String
    let minLevel: Float
    let maxLevel: Float
    let timeStep: Double

    func level(forNoise noise: Double) -> Float {
        let clampedNoise = max(-1.0, min(1.0, noise))
        let t = Float((clampedNoise + 1.0) / 2.0)
        return minLevel + t * (maxLevel - minLevel)
    }

    static let soft = FlickerPreset(name: "Sanft", minLevel: 0.65, maxLevel: 0.85, timeStep: 0.02)
    static let normal = FlickerPreset(name: "Normal", minLevel: 0.45, maxLevel: 0.85, timeStep: 0.05)
    static let wild = FlickerPreset(name: "Wild", minLevel: 0.15, maxLevel: 0.90, timeStep: 0.10)

    static let all: [FlickerPreset] = [.soft, .normal, .wild]
}
```

- [ ] **Step 2: Update `FlickerPresetTests.swift` — drop `dipChance` from every call**

Replace the full file contents:

```swift
import XCTest
@testable import Candle

final class FlickerPresetTests: XCTestCase {
    func test_levelAtMinimumNoiseReturnsMinLevel() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05)
        XCTAssertEqual(preset.level(forNoise: -1.0), 0.2, accuracy: 0.0001)
    }

    func test_levelAtMaximumNoiseReturnsMaxLevel() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05)
        XCTAssertEqual(preset.level(forNoise: 1.0), 0.9, accuracy: 0.0001)
    }

    func test_levelAtZeroNoiseReturnsMidpoint() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.8, timeStep: 0.05)
        XCTAssertEqual(preset.level(forNoise: 0.0), 0.5, accuracy: 0.0001)
    }

    func test_levelClampsOutOfRangeNoise() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05)
        XCTAssertEqual(preset.level(forNoise: 5.0), 0.9, accuracy: 0.0001)
        XCTAssertEqual(preset.level(forNoise: -5.0), 0.2, accuracy: 0.0001)
    }

    func test_allPresetsHaveUniqueNames() {
        let names = Set(FlickerPreset.all.map(\.name))
        XCTAssertEqual(names.count, FlickerPreset.all.count)
    }
}
```

- [ ] **Step 3: Run the tests to verify everything still compiles and passes**

Run: `xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** TEST SUCCEEDED **`, `Executed 9 tests, with 0 failures`

- [ ] **Step 4: Commit**

```bash
git add Candle/Models/FlickerPreset.swift CandleTests/FlickerPresetTests.swift
git commit -m "Remove dip mechanism from FlickerPreset"
```

---

### Task 2: Add the pure intensity-scaling function to `FlickerPreset`

**Files:**
- Modify: `Candle/Models/FlickerPreset.swift`
- Test: `CandleTests/FlickerPresetTests.swift`

**Interfaces:**
- Consumes: `FlickerPreset.level(forNoise:) -> Float` (from Task 1), `minLevel`/`maxLevel: Float` (stored properties).
- Produces: `FlickerPreset.scaledLevel(forNoise: Double, intensity: Double, floor: Float) -> Float` — used by `TorchController` in Task 3.

- [ ] **Step 1: Write the failing tests**

Append to `CandleTests/FlickerPresetTests.swift` (inside the `FlickerPresetTests` class, before the final closing brace):

```swift
    func test_scaledLevelAtFullIntensityMatchesPlainLevel() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05)
        for noise in [-1.0, -0.5, 0.0, 0.5, 1.0] {
            let plain = preset.level(forNoise: noise)
            let scaled = preset.scaledLevel(forNoise: noise, intensity: 1.0, floor: 0.0)
            XCTAssertEqual(scaled, plain, accuracy: 0.0001)
        }
    }

    func test_scaledLevelAtZeroIntensityReturnsPresetMean() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.8, timeStep: 0.05)
        let mean: Float = 0.5
        for noise in [-1.0, -0.5, 0.0, 0.5, 1.0] {
            let scaled = preset.scaledLevel(forNoise: noise, intensity: 0.0, floor: 0.0)
            XCTAssertEqual(scaled, mean, accuracy: 0.0001)
        }
    }

    func test_scaledLevelNeverFallsBelowFloor() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.0, maxLevel: 1.0, timeStep: 0.05)
        let floor: Float = 0.15
        for intensity in [0.0, 0.25, 0.5, 0.75, 1.0] {
            for noise in [-1.0, -0.75, -0.5, 0.0, 0.5, 0.75, 1.0] {
                let scaled = preset.scaledLevel(forNoise: noise, intensity: intensity, floor: floor)
                XCTAssertGreaterThanOrEqual(scaled, floor)
            }
        }
    }

    func test_scaledLevelClampsOutOfRangeIntensity() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.8, timeStep: 0.05)
        let atOne = preset.scaledLevel(forNoise: 1.0, intensity: 1.0, floor: 0.0)
        let above = preset.scaledLevel(forNoise: 1.0, intensity: 5.0, floor: 0.0)
        XCTAssertEqual(above, atOne, accuracy: 0.0001)

        let atZero = preset.scaledLevel(forNoise: 1.0, intensity: 0.0, floor: 0.0)
        let below = preset.scaledLevel(forNoise: 1.0, intensity: -5.0, floor: 0.0)
        XCTAssertEqual(below, atZero, accuracy: 0.0001)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: FAIL — `value of type 'FlickerPreset' has no member 'scaledLevel'`

- [ ] **Step 3: Implement `scaledLevel` in `FlickerPreset.swift`**

Add this method inside the `FlickerPreset` struct, directly after `level(forNoise:)`:

```swift
    func scaledLevel(forNoise noise: Double, intensity: Double, floor: Float) -> Float {
        let baseLevel = level(forNoise: noise)
        let mean = (minLevel + maxLevel) / 2
        let clampedIntensity = Float(max(0.0, min(1.0, intensity)))
        let scaled = mean + (baseLevel - mean) * clampedIntensity
        return max(floor, scaled)
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** TEST SUCCEEDED **`, `Executed 13 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Candle/Models/FlickerPreset.swift CandleTests/FlickerPresetTests.swift
git commit -m "Add intensity-scaled level calculation to FlickerPreset"
```

---

### Task 3: Wire intensity + persistence into `TorchController`

**Files:**
- Modify: `Candle/Controllers/TorchController.swift`

**Interfaces:**
- Consumes: `FlickerPreset.scaledLevel(forNoise:intensity:floor:) -> Float` (from Task 2).
- Produces: `TorchController.intensity: Double` (`@Published`, range `0...1`, persisted) — bound by `ContentView`'s `Slider` in Task 4.

- [ ] **Step 1: Remove the dip state and add `intensity` + `floorLevel`**

In `Candle/Controllers/TorchController.swift`, replace the property declarations (lines 8-20 in the current file) with:

```swift
    @Published private(set) var isRunning = false
    @Published var preset: FlickerPreset = .normal
    @Published var intensity: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(intensity, forKey: TorchController.intensityDefaultsKey)
        }
    }
    @Published private(set) var isTorchAvailable: Bool

    private let device: AVCaptureDevice?
    private var timer: Timer?
    private var noise = PerlinNoise()
    private var t: Double = 0
    private var wasRunningBeforeBackground = false

    private static let intensityDefaultsKey = "flickerIntensity"
    private let tickInterval: TimeInterval = 0.05
    private let floorLevel: Float = 0.15
```

- [ ] **Step 2: Restore persisted intensity in `init()`**

Replace `init()` with:

```swift
    init() {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        self.device = device
        self.isTorchAvailable = device?.hasTorch ?? false
        if UserDefaults.standard.object(forKey: TorchController.intensityDefaultsKey) != nil {
            self.intensity = UserDefaults.standard.double(forKey: TorchController.intensityDefaultsKey)
        }
    }
```

- [ ] **Step 3: Simplify `tick()` to use `scaledLevel` and drop the dip branch**

Replace the `tick()` method with:

```swift
    private func tick() {
        t += preset.timeStep
        let noiseValue = noise.value(at: t)
        let level = preset.scaledLevel(forNoise: noiseValue, intensity: intensity, floor: floorLevel)
        setTorch(level: level)
    }
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run the existing test suite to make sure nothing broke**

Run: `xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** TEST SUCCEEDED **`, `Executed 13 tests, with 0 failures`

- [ ] **Step 6: Commit**

```bash
git add Candle/Controllers/TorchController.swift
git commit -m "Add persisted intensity control to TorchController, remove dip logic"
```

---

### Task 4: Add the intensity slider to `ContentView`

**Files:**
- Modify: `Candle/ContentView.swift`

**Interfaces:**
- Consumes: `TorchController.intensity: Double` (from Task 3).

- [ ] **Step 1: Add the slider below the preset picker**

In `Candle/ContentView.swift`, replace:

```swift
            Picker("Preset", selection: $controller.preset) {
                ForEach(FlickerPreset.all, id: \.self) { preset in
                    Text(preset.name).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
```

with:

```swift
            Picker("Preset", selection: $controller.preset) {
                ForEach(FlickerPreset.all, id: \.self) { preset in
                    Text(preset.name).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            VStack(spacing: 4) {
                Text("Intensität: \(Int(controller.intensity * 100))%")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Slider(value: $controller.intensity, in: 0...1)
                    .padding(.horizontal)
            }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run the full test suite one more time**

Run: `xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** TEST SUCCEEDED **`, `Executed 13 tests, with 0 failures`

- [ ] **Step 4: Commit**

```bash
git add Candle/ContentView.swift
git commit -m "Add intensity slider to ContentView"
```

- [ ] **Step 5: Manual on-device verification (torch hardware is not available in the Simulator)**

Install and run on a real iPhone. For each preset (Sanft, Normal, Wild), move the slider through roughly 0%, 50%, and 100% while the flame is lit, and confirm:
- The torch never looks fully off at any slider position.
- At 0% the torch is a steady, non-flickering brightness.
- At 100% the flicker matches the preset's original character, minus any near-off dips.
- Quitting and relaunching the app restores the last slider position.

Report back whether "Sanft" still feels too subtle at 100% — that tuning is a deliberate follow-up, not part of this plan.

---
