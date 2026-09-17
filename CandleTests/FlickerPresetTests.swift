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

    func test_scaledLevelAtFullIntensityMatchesPlainLevel() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.9, timeStep: 0.05)
        for noise in [-1.0, -0.5, 0.0, 0.5, 1.0] {
            let plain = preset.level(forNoise: noise)
            let scaled = preset.scaledLevel(forNoise: noise, intensity: 1.0, minimumLevel: 0.0)
            XCTAssertEqual(scaled, plain, accuracy: 0.0001)
        }
    }

    func test_scaledLevelAtZeroIntensityReturnsPresetMean() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.8, timeStep: 0.05)
        let mean: Float = 0.5
        for noise in [-1.0, -0.5, 0.0, 0.5, 1.0] {
            let scaled = preset.scaledLevel(forNoise: noise, intensity: 0.0, minimumLevel: 0.0)
            XCTAssertEqual(scaled, mean, accuracy: 0.0001)
        }
    }

    func test_scaledLevelNeverFallsBelowFloor() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.0, maxLevel: 1.0, timeStep: 0.05)
        let floor: Float = 0.15
        for intensity in [0.0, 0.25, 0.5, 0.75, 1.0] {
            for noise in [-1.0, -0.75, -0.5, 0.0, 0.5, 0.75, 1.0] {
                let scaled = preset.scaledLevel(forNoise: noise, intensity: intensity, minimumLevel: floor)
                XCTAssertGreaterThanOrEqual(scaled, floor)
            }
        }
    }

    func test_scaledLevelNeverFallsBelowFloorForRealPresets() {
        let floor: Float = 0.15
        for preset in FlickerPreset.all {
            for intensity in [0.0, 0.25, 0.5, 0.75, 1.0] {
                for noise in [-1.0, -0.5, 0.0, 0.5, 1.0] {
                    let scaled = preset.scaledLevel(forNoise: noise, intensity: intensity, minimumLevel: floor)
                    XCTAssertGreaterThanOrEqual(scaled, floor)
                }
            }
        }
    }

    func test_scaledLevelClampsOutOfRangeIntensity() {
        let preset = FlickerPreset(name: "Test", minLevel: 0.2, maxLevel: 0.8, timeStep: 0.05)
        let atOne = preset.scaledLevel(forNoise: 1.0, intensity: 1.0, minimumLevel: 0.0)
        let above = preset.scaledLevel(forNoise: 1.0, intensity: 5.0, minimumLevel: 0.0)
        XCTAssertEqual(above, atOne, accuracy: 0.0001)

        let atZero = preset.scaledLevel(forNoise: 1.0, intensity: 0.0, minimumLevel: 0.0)
        let below = preset.scaledLevel(forNoise: 1.0, intensity: -5.0, minimumLevel: 0.0)
        XCTAssertEqual(below, atZero, accuracy: 0.0001)
    }
}
