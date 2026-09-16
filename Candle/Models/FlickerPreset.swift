struct FlickerPreset: Hashable {
    let name: String
    let minLevel: Float
    let maxLevel: Float
    let timeStep: Double
    let dipChance: Double

    func level(forNoise noise: Double) -> Float {
        let clampedNoise = max(-1.0, min(1.0, noise))
        let t = Float((clampedNoise + 1.0) / 2.0)
        return minLevel + t * (maxLevel - minLevel)
    }

    static let soft = FlickerPreset(name: "Sanft", minLevel: 0.65, maxLevel: 0.85, timeStep: 0.02, dipChance: 0.0)
    static let normal = FlickerPreset(name: "Normal", minLevel: 0.45, maxLevel: 0.85, timeStep: 0.05, dipChance: 0.01)
    static let wild = FlickerPreset(name: "Wild", minLevel: 0.15, maxLevel: 0.90, timeStep: 0.10, dipChance: 0.04)

    static let all: [FlickerPreset] = [.soft, .normal, .wild]
}
