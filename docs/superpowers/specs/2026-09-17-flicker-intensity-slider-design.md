# Candle – Intensitäts-Regler & Dip-Entfernung (Design)

## Problem
Feedback nach dem ersten Build:
- **Sanft** hat einen zu schmalen Helligkeitsbereich (0.65–0.85) – man merkt das
  Flackern kaum.
- **Wild** wirkt teils zu extrem (0.15–0.90, schnelle Ticks).
- Bei **Normal** und **Wild** springt die LED durch den Dip-Mechanismus
  gelegentlich auf einen sehr niedrigen Wert (`dipLevel = 0.05`), was auf der
  Hardware wie "komplett aus" aussieht – unerwünscht.

## Entscheidung
- Der Dip-Mechanismus (`dipChance`, `dipTicksRemaining`, `dipLevel`) wird
  **komplett entfernt**. Kein Preset erzeugt mehr absichtliche Beinah-Aus-Momente.
- Zusätzlich zu den drei Presets (Sanft/Normal/Wild, weiterhin bestimmen sie
  Bereich/Geschwindigkeit des Flackerns) gibt es einen neuen globalen
  **Intensitäts-Regler** (Slider, 0–100 %) unter dem Preset-Picker.
- Der Regler skaliert die **Flacker-Amplitude um den Mittelwert** des aktuell
  gewählten Presets, nicht die Grundhelligkeit. Bei 100 % entspricht das dem
  bisherigen Preset-Verhalten (ohne Dips), bei 0 % leuchtet die LED konstant
  auf Preset-Mittelwert (kein Flackern, aber nie "aus").
- Ein **fester globaler Minimalwert** (`floorLevel`) verhindert, dass die
  Helligkeit – unabhängig von Preset und Reglerstellung – jemals so niedrig
  wird, dass es wie "aus" wirkt.
- Die Reglerposition wird in `UserDefaults` gespeichert und beim nächsten
  App-Start wiederhergestellt.
- Die konkreten Preset-Bereiche (insbesondere ob "Sanft" bei 100 % Intensität
  noch spürbar genug flackert) werden nach dem Bauen am echten Gerät
  nachjustiert – nicht Teil dieses Specs, sondern ein Folgeschritt.

## Betroffene Komponenten

### `FlickerPreset` (Model)
- `dipChance: Double` Feld entfernt.
- `minLevel`/`maxLevel`/`timeStep` bleiben unverändert in Bedeutung
  (Bereich/Geschwindigkeit pro Preset).
- `level(forNoise:)` unverändert (reines Noise→Level-Mapping innerhalb
  `[minLevel, maxLevel]`).

### `TorchController`
- Neues `@Published var intensity: Double` (Bereich `0...1`).
  - Initialwert aus `UserDefaults.standard.double(forKey: "flickerIntensity")`,
    Default `1.0` falls kein gespeicherter Wert vorhanden.
  - `didSet` (oder äquivalent) speichert den neuen Wert sofort in
    `UserDefaults`.
- Entfernt: `dipTicksRemaining`, `dipLevel`, die Dip-Verzweigung in `tick()`.
- Neue Berechnung in `tick()`:
  ```swift
  let noiseValue = noise.value(at: t)
  let baseLevel = preset.level(forNoise: noiseValue)
  let mean = (preset.minLevel + preset.maxLevel) / 2
  let scaled = mean + (baseLevel - mean) * Float(intensity)
  let level = max(floorLevel, scaled)
  setTorch(level: level)
  ```
- Neue Konstante `private let floorLevel: Float = 0.15` (fester globaler
  Boden, unabhängig von Preset/Intensität).

### `ContentView`
- Neuer `Slider(value: $controller.intensity, in: 0...1)` unter dem
  bestehenden Preset-Picker, mit Prozent-Label (z. B.
  `Text("Intensität: \(Int(controller.intensity * 100))%")`).
- Slider jederzeit bedienbar, auch während `isRunning == true` (wie der
  Preset-Picker bereits heute).

## Datenfluss
1. Preset-Wahl bestimmt `minLevel`/`maxLevel`/`timeStep` (Flacker-Stil).
2. Pro Tick: Noise → `baseLevel` innerhalb des Preset-Bereichs.
3. `intensity` skaliert die Abweichung von `baseLevel` zum Preset-Mittelwert.
4. `floorLevel` garantiert, dass der finale Wert nie "aus" wirkt – unabhängig
   von Schritt 1–3.

## Persistenz
- `flickerIntensity` (Double) in `UserDefaults.standard`.
- Preset-Auswahl bleibt wie bisher **nicht** persistiert (unverändert,
  außerhalb des Scopes dieser Änderung).

## Testing
- `FlickerPresetTests.swift`: bestehende Tests anpassen (kein `dipChance`
  mehr referenziert).
- Neue Unit-Tests für die Intensitäts-Skalierung (z. B. als Testfunktion auf
  der reinen Rechenlogik, losgelöst von `AVCaptureDevice`):
  - `intensity == 0` → Ergebnis-Level == Preset-Mittelwert (für jeden Noise-Wert).
  - `intensity == 1` → Ergebnis-Level == `preset.level(forNoise:)` (unverändert).
  - Für jede Kombination aus Preset, Noise-Wert (inkl. Extremwerten `-1`/`1`)
    und `intensity` in `[0, 1]`: Ergebnis-Level `>= floorLevel`.
- Manueller Test am echten Gerät: Regler bei 0 %, 50 %, 100 % für alle drei
  Presets, insbesondere prüfen, dass die LED nie wie "aus" wirkt.

## Out of Scope
- Anpassung der konkreten Preset-Werte (z. B. breiterer Bereich für "Sanft")
  – wird nach dem Bauen separat begutachtet.
- Persistenz der Preset-Auswahl.
- Separater Regler pro Preset (ein globaler Wert für alle drei Presets).
