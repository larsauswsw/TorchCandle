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

            VStack(spacing: 4) {
                Text("Intensität: \(Int((controller.intensity * 100).rounded()))%")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Slider(
                    value: $controller.intensity,
                    in: 0...1,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            controller.persistIntensity()
                        }
                    }
                )
                .accessibilityLabel("Intensität")
                .padding(.horizontal)
            }

            VStack(spacing: 4) {
                Text("Helligkeit: \(Int((controller.brightness * 100).rounded()))%")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Slider(
                    value: $controller.brightness,
                    in: 0...1,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            controller.persistBrightness()
                        }
                    }
                )
                .accessibilityLabel("Helligkeit")
                .padding(.horizontal)
            }

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
