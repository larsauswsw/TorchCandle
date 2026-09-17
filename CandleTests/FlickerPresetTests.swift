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
