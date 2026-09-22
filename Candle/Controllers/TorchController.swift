import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class TorchController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var preset: FlickerPreset = .normal
    @Published var intensity: Double = 1.0
    @Published var brightness: Double = 1.0
    @Published private(set) var isTorchAvailable: Bool

    private let device: AVCaptureDevice?
    private var timer: Timer?
    private var noise = PerlinNoise()
    private var t: Double = 0
    private var wasRunningBeforeBackground = false

    private static let intensityDefaultsKey = "flickerIntensity"
    private static let brightnessDefaultsKey = "flickerBrightness"
    private let tickInterval: TimeInterval = 0.05
    private let floorLevel: Float = 0.15

    init() {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        self.device = device
        self.isTorchAvailable = device?.hasTorch ?? false
        if UserDefaults.standard.object(forKey: TorchController.intensityDefaultsKey) != nil {
            let storedIntensity = UserDefaults.standard.double(forKey: TorchController.intensityDefaultsKey)
            self.intensity = min(1.0, max(0.0, storedIntensity))
        }
        if UserDefaults.standard.object(forKey: TorchController.brightnessDefaultsKey) != nil {
            let storedBrightness = UserDefaults.standard.double(forKey: TorchController.brightnessDefaultsKey)
            self.brightness = min(1.0, max(0.0, storedBrightness))
        }
    }

    func persistIntensity() {
        UserDefaults.standard.set(intensity, forKey: TorchController.intensityDefaultsKey)
    }

    func persistBrightness() {
        UserDefaults.standard.set(brightness, forKey: TorchController.brightnessDefaultsKey)
    }

    func start() {
        guard isTorchAvailable, !isRunning else { return }
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        wasRunningBeforeBackground = false
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
                stop()
                wasRunningBeforeBackground = true
            }
        @unknown default:
            break
        }
    }

    private func tick() {
        t += preset.timeStep
        let noiseValue = noise.value(at: t)
        let level = preset.scaledLevel(forNoise: noiseValue, intensity: intensity, brightness: brightness, minimumLevel: floorLevel)
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
