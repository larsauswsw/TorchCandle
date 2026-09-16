# Candle Flicker App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftUI iOS app ("Candle") that flickers the rear torch LED like a candle flame, with a start/stop toggle and three intensity presets (Sanft / Normal / Wild).

**Architecture:** An `xcodegen`-scaffolded SwiftUI app with two pure, unit-tested model types (`PerlinNoise`, `FlickerPreset`) that drive a hardware-facing `TorchController` (`ObservableObject`, wraps `AVCaptureDevice` torch APIs and app-lifecycle handling), consumed by a single `ContentView`.

**Tech Stack:** Swift 5 (language mode), SwiftUI, AVFoundation, XCTest, xcodegen 2.46.0 for project generation.

## Global Constraints

- Deployment target: iOS 17.0 (from spec)
- Bundle ID: `de.lars-miesner.candle` (from spec, corrected by user)
- App name / display name: `Candle` (from spec)
- Project scaffolding: `xcodegen` (v2.46.0 confirmed installed) generates `Candle.xcodeproj` from `project.yml`; the generated `.xcodeproj` is **not** committed to git — regenerate with `xcodegen generate` after every clone or `project.yml` change
- Swift language version: `5.0` (avoids Swift 6 strict-concurrency friction for the `Timer`-driven `TorchController`, per spec's simplicity goal)
- No external dependencies/packages (spec: custom ~30-line Perlin noise, no library)
- No `NSCameraUsageDescription` needed — torch-only control without an active capture session does not require camera permission (from spec's Error Handling section)
- No custom brightness/speed sliders — only the three fixed presets Sanft/Normal/Wild (spec: Out of Scope)
- No persistence of preset selection across app launches (spec: Out of Scope, YAGNI)
- Build/test verification destination on this machine: `platform=iOS Simulator,name=iPhone 17` (confirmed available via `xcrun simctl list devices available`)

---

## Task 1: Project Scaffolding

**Files:**
- Create: `project.yml`
- Create: `.gitignore`
- Create: `Candle/CandleApp.swift`
- Create: `Candle/ContentView.swift`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: a buildable Xcode project (`Candle.xcodeproj`, generated, not committed) with a placeholder `ContentView` that later tasks will modify

- [ ] **Step 1: Write `project.yml`**

```yaml
name: Candle
options:
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "5.0"
targets:
  Candle:
    type: application
    platform: iOS
    sources:
      - path: Candle
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: de.lars-miesner.candle
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Candle
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        TARGETED_DEVICE_FAMILY: "1"
  CandleTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: CandleTests
    dependencies:
      - target: Candle
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
schemes:
  Candle:
    build:
      targets:
        Candle: all
        CandleTests: [test]
    test:
      targets:
        - CandleTests
    run:
      config: Debug
```

- [ ] **Step 2: Write `.gitignore`**

```
.build/
DerivedData/
*.xcodeproj
xcuserdata/
.swiftpm/
```

- [ ] **Step 3: Write `Candle/CandleApp.swift`**

```swift
import SwiftUI

@main
struct CandleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 4: Write placeholder `Candle/ContentView.swift`**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Candle")
            .padding()
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 5: Generate the Xcode project**

Run: `cd /Users/lars/Development/iOS/Kerze && xcodegen generate`
Expected: `Created project at /Users/lars/Development/iOS/Kerze/Candle.xcodeproj`

- [ ] **Step 6: Verify it builds for the simulator**

Run: `xcodebuild build -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: output ends with `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add project.yml .gitignore Candle/CandleApp.swift Candle/ContentView.swift
git commit -m "Scaffold Candle Xcode project with xcodegen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YVvFeRhemQuoedyxVTy6SF"
```

---

## Task 2: Perlin Noise Generator

**Files:**
- Create: `Candle/Models/SeededGenerator.swift`
- Create: `Candle/Models/PerlinNoise.swift`
- Test: `CandleTests/PerlinNoiseTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `PerlinNoise` with `init(seed: UInt64)`, `init()`, and `func value(at t: Double) -> Double` (returns a value in `[-1, 1]`); `SeededGenerator: RandomNumberGenerator` with `init(seed: UInt64)`

- [ ] **Step 1: Write the failing tests**

Create `CandleTests/PerlinNoiseTests.swift`:

```swift
import XCTest
@testable import Candle

final class PerlinNoiseTests: XCTestCase {
    func test_valueStaysWithinExpectedRange() {
        let noise = PerlinNoise(seed: 42)
        var t = 0.0
        while t < 50 {
            let value = noise.value(at: t)
            XCTAssertGreaterThanOrEqual(value, -1.0)
            XCTAssertLessThanOrEqual(value, 1.0)
            t += 0.037
        }
    }

    func test_sameSeedProducesSameSequence() {
        let noiseA = PerlinNoise(seed: 123)
        let noiseB = PerlinNoise(seed: 123)

        for i in stride(from: 0.0, to: 10.0, by: 0.5) {
            XCTAssertEqual(noiseA.value(at: i), noiseB.value(at: i), accuracy: 0.0000001)
        }
    }
}
```

- [ ] **Step 2: Regenerate project and run test to verify it fails**

Run: `xcodegen generate && xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: build fails with `cannot find 'PerlinNoise' in scope`

- [ ] **Step 3: Write `Candle/Models/SeededGenerator.swift`**

```swift
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Step 4: Write `Candle/Models/PerlinNoise.swift`**

```swift
import Foundation

struct PerlinNoise {
    private let permutation: [Int]

    init(seed: UInt64) {
        var generator = SeededGenerator(seed: seed)
        var perm = Array(0..<256)
        perm.shuffle(using: &generator)
        permutation = perm + perm
    }

    init() {
        self.init(seed: UInt64.random(in: UInt64.min...UInt64.max))
    }

    func value(at t: Double) -> Double {
        let ti = Int(floor(t))
        let x0 = ((ti % 256) + 256) % 256
        let x1 = (x0 + 1) % 256
        let xf = t - floor(t)

        let fade = xf * xf * xf * (xf * (xf * 6 - 15) + 10)

        let g0 = gradient(permutation[x0])
        let g1 = gradient(permutation[x1])

        let d0 = g0 * xf
        let d1 = g1 * (xf - 1)

        return lerp(d0, d1, fade)
    }

    private func gradient(_ hash: Int) -> Double {
        (hash & 1) == 0 ? 1.0 : -1.0
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + t * (b - a)
    }
}
```

- [ ] **Step 5: Regenerate project and run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: output ends with `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Candle/Models/SeededGenerator.swift Candle/Models/PerlinNoise.swift CandleTests/PerlinNoiseTests.swift
git commit -m "Add seeded Perlin noise generator

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YVvFeRhemQuoedyxVTy6SF"
```

---

## Task 3: Flicker Presets

**Files:**
- Create: `Candle/Models/FlickerPreset.swift`
- Test: `CandleTests/FlickerPresetTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `FlickerPreset: Hashable` with fields `name: String`, `minLevel: Float`, `maxLevel: Float`, `timeStep: Double`, `dipChance: Double`, method `func level(forNoise noise: Double) -> Float`, and static members `.soft`, `.normal`, `.wild`, `.all: [FlickerPreset]`

- [ ] **Step 1: Write the failing tests**

Create `CandleTests/FlickerPresetTests.swift`:

```swift
import XCTest
@testable import Candle

final class FlickerPresetTests: XCTestCase {
    func test_levelAtMinimumNoiseReturnsMinLevel() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05, dipChance: 0)
        XCTAssertEqual(preset.level(forNoise: -1.0), 0.2, accuracy: 0.0001)
    }

    func test_levelAtMaximumNoiseReturnsMaxLevel() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05, dipChance: 0)
        XCTAssertEqual(preset.level(forNoise: 1.0), 0.9, accuracy: 0.0001)
    }

    func test_levelAtZeroNoiseReturnsMidpoint() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.8, timeStep: 0.05, dipChance: 0)
        XCTAssertEqual(preset.level(forNoise: 0.0), 0.5, accuracy: 0.0001)
    }

    func test_levelClampsOutOfRangeNoise() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05, dipChance: 0)
        XCTAssertEqual(preset.level(forNoise: 5.0), 0.9, accuracy: 0.0001)
        XCTAssertEqual(preset.level(forNoise: -5.0), 0.2, accuracy: 0.0001)
    }

    func test_allPresetsHaveUniqueNames() {
        let names = Set(FlickerPreset.all.map(\.name))
        XCTAssertEqual(names.count, FlickerPreset.all.count)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: build fails with `cannot find 'FlickerPreset' in scope`

- [ ] **Step 3: Write `Candle/Models/FlickerPreset.swift`**

```swift
struct FlickerPreset: Hashable {
    let name: String
    let minLevel: Float
    let maxLevel: Float
    let timeStep: Double
    let dipChance: Double

    func level(forNoise noise: Double) -> Float {
        let clampedNoise = max(-1.0, min(1.0, noise))
        let t = Float((clampedNoise + 1.0) / 2.0)
        return minLevel + t * (maxLevel - minLevel)
    }

    static let soft = FlickerPreset(name: "Sanft", minLevel: 0.65, maxLevel: 0.85, timeStep: 0.02, dipChance: 0.0)
    static let normal = FlickerPreset(name: "Normal", minLevel: 0.45, maxLevel: 0.85, timeStep: 0.05, dipChance: 0.01)
    static let wild = FlickerPreset(name: "Wild", minLevel: 0.15, maxLevel: 0.90, timeStep: 0.10, dipChance: 0.04)

    static let all: [FlickerPreset] = [.soft, .normal, .wild]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: output ends with `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Candle/Models/FlickerPreset.swift CandleTests/FlickerPresetTests.swift
git commit -m "Add flicker presets with noise-to-brightness mapping

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YVvFeRhemQuoedyxVTy6SF"
```

---

## Task 4: Torch Controller

**Files:**
- Create: `Candle/Controllers/TorchController.swift`

**Interfaces:**
- Consumes: `PerlinNoise` (Task 2: `init()`, `func value(at t: Double) -> Double`), `FlickerPreset` (Task 3: `.normal`, `func level(forNoise:) -> Float`, `dipChance`, `timeStep`)
- Produces: `TorchController: ObservableObject` with `@Published private(set) var isRunning: Bool`, `@Published var preset: FlickerPreset`, `@Published private(set) var isTorchAvailable: Bool`, `func start()`, `func stop()`, `func handleScenePhaseChange(_ phase: ScenePhase)`

This task has no hardware-dependent unit tests (per spec: torch hardware isn't simulatable). It is verified by a successful build, since `hasTorch` guards make all torch code paths safe to compile and run without hardware (they simply no-op).

- [ ] **Step 1: Write `Candle/Controllers/TorchController.swift`**

```swift
import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class TorchController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var preset: FlickerPreset = .normal
    @Published private(set) var isTorchAvailable: Bool

    private let device: AVCaptureDevice?
    private var timer: Timer?
    private var noise = PerlinNoise()
    private var t: Double = 0
    private var dipTicksRemaining = 0
    private var wasRunningBeforeBackground = false

    private let tickInterval: TimeInterval = 0.05
    private let dipLevel: Float = 0.05

    init() {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        self.device = device
        self.isTorchAvailable = device?.hasTorch ?? false
    }

    func start() {
        guard isTorchAvailable, !isRunning else { return }
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
        setTorch(level: nil)
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if wasRunningBeforeBackground {
                wasRunningBeforeBackground = false
                start()
            }
        case .inactive, .background:
            if isRunning {
                wasRunningBeforeBackground = true
                stop()
            }
        @unknown default:
            break
        }
    }

    private func tick() {
        t += preset.timeStep
        var level: Float

        if dipTicksRemaining > 0 {
            dipTicksRemaining -= 1
            level = dipLevel
        } else {
            let noiseValue = noise.value(at: t)
            level = preset.level(forNoise: noiseValue)
            if preset.dipChance > 0, Double.random(in: 0...1) < preset.dipChance {
                dipTicksRemaining = 1
                level = dipLevel
            }
        }

        setTorch(level: level)
    }

    private func setTorch(level: Float?) {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if let level {
                try device.setTorchModeOn(level: level)
            } else {
                device.torchMode = .off
            }
        } catch {
            print("TorchController error: \(error)")
            timer?.invalidate()
            timer = nil
            isRunning = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
```

- [ ] **Step 2: Regenerate project and verify it builds**

Run: `xcodegen generate && xcodebuild build -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: output ends with `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Candle/Controllers/TorchController.swift
git commit -m "Add TorchController driving torch level from Perlin noise

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YVvFeRhemQuoedyxVTy6SF"
```

---

## Task 5: Wire Up ContentView and Final Verification

**Files:**
- Modify: `Candle/ContentView.swift` (replace placeholder body from Task 1)

**Interfaces:**
- Consumes: `TorchController` (Task 4: `isRunning`, `preset`, `isTorchAvailable`, `start()`, `stop()`, `handleScenePhaseChange(_:)`), `FlickerPreset.all` (Task 3)
- Produces: the finished app UI (final deliverable of this plan)

- [ ] **Step 1: Replace `Candle/ContentView.swift` with the full UI**

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var controller = TorchController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 32) {
            Picker("Preset", selection: $controller.preset) {
                ForEach(FlickerPreset.all, id: \.self) { preset in
                    Text(preset.name).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button(action: toggle) {
                VStack(spacing: 12) {
                    Image(systemName: controller.isRunning ? "flame.fill" : "flame")
                        .font(.system(size: 72))
                    Text(controller.isRunning ? "Löschen" : "Anzünden")
                        .font(.title2)
                }
                .frame(width: 220, height: 220)
                .background(controller.isRunning ? Color.orange : Color.gray.opacity(0.2))
                .foregroundColor(controller.isRunning ? .white : .primary)
                .clipShape(Circle())
            }
            .disabled(!controller.isTorchAvailable)

            if !controller.isTorchAvailable {
                Text("Kein Blitzlicht verfügbar")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onChange(of: scenePhase) { _, newPhase in
            controller.handleScenePhaseChange(newPhase)
        }
    }

    private func toggle() {
        if controller.isRunning {
            controller.stop()
        } else {
            controller.start()
        }
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Regenerate project and run the full test suite**

Run: `xcodegen generate && xcodebuild test -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: output ends with `** TEST SUCCEEDED **` (all `PerlinNoiseTests` and `FlickerPresetTests` pass)

- [ ] **Step 3: Verify a clean simulator build**

Run: `xcodebuild build -project Candle.xcodeproj -scheme Candle -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: output ends with `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Candle/ContentView.swift
git commit -m "Wire ContentView to TorchController for candle flicker UI

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YVvFeRhemQuoedyxVTy6SF"
```

**After this task:** open `Candle.xcodeproj` in Xcode, select your physical iPhone as the run destination, and run the app to test the real torch flicker (torch hardware cannot be exercised in the simulator or via `xcodebuild`).
