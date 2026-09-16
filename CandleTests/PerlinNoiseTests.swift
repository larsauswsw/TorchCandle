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

    func test_valueUtilizesFullRange() {
        let noise = PerlinNoise(seed: 7)
        var maxValue = -1.0
        var minValue = 1.0
        var t = 0.0
        while t < 100 {
            let value = noise.value(at: t)
            maxValue = max(maxValue, value)
            minValue = min(minValue, value)
            t += 0.013
        }
        XCTAssertGreaterThan(maxValue, 0.9, "noise should approach its upper bound of 1.0")
        XCTAssertLessThan(minValue, -0.9, "noise should approach its lower bound of -1.0")
    }

    func test_differentSeedsProduceDifferentSequences() {
        let noiseA = PerlinNoise(seed: 1)
        let noiseB = PerlinNoise(seed: 2)

        var foundDifference = false
        for i in stride(from: 0.0, to: 10.0, by: 0.5) {
            if abs(noiseA.value(at: i) - noiseB.value(at: i)) > 0.0001 {
                foundDifference = true
                break
            }
        }
        XCTAssertTrue(foundDifference, "different seeds should produce different sequences")
    }
}
