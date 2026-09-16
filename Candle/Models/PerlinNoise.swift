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

        return lerp(d0, d1, fade) * 2.0
    }

    private func gradient(_ hash: Int) -> Double {
        (hash & 1) == 0 ? 1.0 : -1.0
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + t * (b - a)
    }
}
