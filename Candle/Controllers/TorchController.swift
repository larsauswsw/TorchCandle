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
