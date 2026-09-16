# Candle – Kerzenflackern-Taschenlampe (Design)

## Ziel
Eine iOS-App, die die rückseitige LED (Torch) statt konstant an/aus per Toggle
in einem realistischen Kerzenflacker-Muster betreibt. Nutzer:in kann das
Flackern starten/stoppen und zwischen drei Presets wählen (Sanft, Normal,
Wild).

## App-Identität
- Name: **Candle**
- Bundle-ID: `de.lars-miesner.candle`
- Deployment Target: iOS 17.0
- UI-Framework: SwiftUI
- Projekt-Scaffolding: `xcodegen` (`project.yml` → `Candle.xcodeproj`)

## Architektur
Zwei Kernkomponenten:

1. **`TorchController`** (`ObservableObject`) – kapselt die Hardware-Ansteuerung
   und die Flacker-Logik.
2. **`ContentView`** (SwiftUI) – Toggle-Button + Preset-Picker, bindet an
   `TorchController`.

Reine Hilfslogik (Noise-Generator, Preset→Level-Mapping) liegt in eigenen,
von SwiftUI/AVFoundation unabhängigen Typen, damit sie unit-testbar sind.

## TorchController

- Hält Referenz auf `AVCaptureDevice` (`.builtInWideAngleCamera`, `.video`,
  `.back`).
- `@Published var isRunning: Bool`
- `@Published var preset: FlickerPreset` (Sanft / Normal / Wild), auch live
  während des Laufens änderbar.
- `@Published var isTorchAvailable: Bool` – Ergebnis von
  `device?.hasTorch == true`.
- `start()`:
  - prüft `isTorchAvailable`, sonst no-op
  - startet einen `Timer` mit ~50 ms Intervall (20 Hz)
  - setzt `UIApplication.shared.isIdleTimerDisabled = true`
- `stop()`:
  - invalidiert Timer
  - setzt `torchMode = .off` via `lockForConfiguration()`
  - setzt `isIdleTimerDisabled = false`
- Timer-Tick:
  - fragt `PerlinNoise` an aktueller "Zeit" ab, mappt Rückgabewert (-1...1)
    über die Preset-Parameter auf einen Helligkeitswert `[minLevel, maxLevel]`
    (geclamped auf `(0.0, 1.0]`, da `torchLevel` keine 0 erlaubt – `torchMode`
    wird stattdessen auf `.off` gesetzt, wenn der Wert unter einen kleinen
    Schwellwert fällt, für die "Beinah-Aus"-Dips im Wild-Preset)
  - setzt `device.torchMode = .on` mit
    `try device.setTorchModeOn(level: value)` innerhalb von
    `lockForConfiguration()`/`unlockForConfiguration()`
  - Fehler beim Lock/Set werden geloggt (`print`/`os_log`), `isRunning` wird
    auf `false` zurückgesetzt, Timer gestoppt

### App-Lifecycle
- iOS gibt die Kamera-Hardware frei, sobald die App in den Hintergrund geht;
  die Torch geht dabei automatisch aus.
- `ContentView` beobachtet `\.scenePhase`:
  - `.background`/`.inactive`: `TorchController` merkt sich, ob er lief
    (`wasRunningBeforeBackground`), ruft `stop()` auf (Timer sauber beenden,
    `isRunning = false` für die UI)
  - `.active`: falls `wasRunningBeforeBackground == true`, automatisch
    `start()` erneut aufrufen

## Flicker-Algorithmus

Eigene, leichtgewichtige 1D Perlin-/Value-Noise-Implementierung
(`PerlinNoise`, ca. 30 Zeilen, keine externe Dependency):

- Deterministisch bei fixem Seed (testbar), sonst mit `Int.random` geseedet
- API: `func value(at t: Double) -> Double`, Rückgabe in `[-1, 1]`
- `TorchController` erhöht `t` pro Tick um `preset.timeStep`

### `FlickerPreset`

```swift
struct FlickerPreset {
    let name: String
    let minLevel: Float      // untere Helligkeitsgrenze
    let maxLevel: Float      // obere Helligkeitsgrenze
    let timeStep: Double     // Geschwindigkeit der Noise-Bewegung pro Tick
    let dipChance: Double    // Wahrscheinlichkeit pro Tick für einen kurzen Beinah-Aus-Dip (nur Wild)
}
```

Presets:

| Preset | minLevel | maxLevel | timeStep | dipChance |
|--------|----------|----------|----------|-----------|
| Sanft  | 0.65     | 0.85     | 0.02     | 0.0       |
| Normal | 0.45     | 0.85     | 0.05     | 0.01      |
| Wild   | 0.15     | 0.90     | 0.10     | 0.04      |

Mapping: `level = minLevel + (noise + 1) / 2 * (maxLevel - minLevel)`.
Bei Wild wird zusätzlich pro Tick mit `dipChance` gewürfelt, ob kurz (1–2
Ticks) auf einen sehr niedrigen Wert (~0.05) gesprungen wird, um das
gelegentliche "fast erlöschen" einer echten Kerze zu simulieren.

## UI (ContentView)

- Zentrierter, großer runder Button:
  - Aus-Zustand: Kerzen-Icon, Text "Anzünden"
  - An-Zustand: Kerzen-Icon (gefüllt/animiert), Text "Löschen"
  - Deaktiviert + Hinweistext ("Kein Blitzlicht verfügbar"), falls
    `!isTorchAvailable`
- Darunter: `Picker` (Segmented Style) mit den drei Presets, jederzeit
  bedienbar, auch während `isRunning == true`

## Fehlerbehandlung

- Kein Torch-Hardware (z. B. iPad, Simulator): Button disabled, Hinweistext,
  kein Absturz
- `lockForConfiguration()` wirft: Fehler loggen, `isRunning = false`,
  UI fällt automatisch in den Aus-Zustand zurück (State-getrieben)
- Keine Kamera-Berechtigung nötig: reine Torch-Steuerung ohne aktive
  Session erfordert kein `NSCameraUsageDescription`

## Testing

- **Unit-Tests** (`CandleTests`, XCTest):
  - `PerlinNoise` mit festem Seed: Werte liegen in `[-1, 1]`, sind
    deterministisch reproduzierbar
  - Preset→Level-Mapping: Grenzwerte (`noise = -1` → `minLevel`,
    `noise = 1` → `maxLevel`)
- **Manueller Test auf echtem Gerät** (Torch-Hardware nicht simulierbar):
  Start/Stop, Preset-Wechsel live, Verhalten beim App-Backgrounding/
  Foregrounding
- **Build-Verifikation**: `xcodebuild build -scheme Candle
  -destination 'platform=iOS Simulator,name=iPhone 15'` muss grün sein
  (Torch-Pfade sind über `hasTorch`-Checks abgesichert und kompilieren auch
  ohne Hardware)

## Out of Scope
- Keine Persistenz von Preset-Auswahl zwischen App-Starts (bewusst simpel
  gehalten, YAGNI)
- Keine Custom-Regler für Helligkeit/Geschwindigkeit (per User-Entscheidung:
  nur Presets, kein Slider-UI)
- Kein Hintergrundbetrieb (technisch durch iOS ohnehin verhindert)
