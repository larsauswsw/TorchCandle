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
