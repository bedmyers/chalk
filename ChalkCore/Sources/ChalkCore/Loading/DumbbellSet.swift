/// The dumbbells available, described as tiers of evenly spaced weights.
///
/// Each tier runs from its `start` in `step` increments until the next tier's
/// `start`; the last tier is unbounded. Weights are per dumbbell.
public struct DumbbellSet: WeightLadder, Hashable {
    public struct Tier: Sendable, Hashable {
        public let start: Weight
        public let step: Weight

        public init(start: Weight, step: Weight) {
            self.start = start
            self.step = step
        }
    }

    /// Tiers sorted by `start`, lightest first.
    public let tiers: [Tier]

    public init(tiers: [Tier]) {
        precondition(!tiers.isEmpty, "A dumbbell set needs at least one tier")
        precondition(tiers.allSatisfy { $0.step.thousandths > 0 }, "Tier steps must be positive")
        let unit = tiers[0].start.unit
        precondition(
            tiers.allSatisfy { $0.start.unit == unit && $0.step.unit == unit },
            "All tiers must share one unit"
        )
        self.tiers = tiers.sorted { $0.start < $1.start }
    }

    /// 2.5 lb steps up to 20 lb, then 5 lb steps: 2.5, 5, … 17.5, 20, 25, 30, …
    public static let standardPounds = DumbbellSet(tiers: [
        Tier(start: .pounds(2.5), step: .pounds(2.5)),
        Tier(start: .pounds(20), step: .pounds(5)),
    ])

    /// 1 kg steps up to 10 kg, then 2.5 kg steps: 1, 2, … 9, 10, 12.5, 15, …
    public static let standardKilograms = DumbbellSet(tiers: [
        Tier(start: .kilograms(1), step: .kilograms(1)),
        Tier(start: .kilograms(10), step: .kilograms(2.5)),
    ])

    public static func standard(for unit: WeightUnit) -> DumbbellSet {
        switch unit {
        case .pounds: standardPounds
        case .kilograms: standardKilograms
        }
    }

    public var unit: WeightUnit { tiers[0].start.unit }
    public var minimum: Weight { tiers[0].start }

    public func roundedUp(_ weight: Weight) -> Weight {
        guard weight > minimum else { return minimum }
        let index = tierIndex(containing: weight)
        let tier = tiers[index]
        let steps = ceilDiv(weight.thousandths - tier.start.thousandths, tier.step.thousandths)
        let candidate = Weight(
            thousandths: tier.start.thousandths + steps * tier.step.thousandths,
            unit: unit
        )
        // Rounding up past the end of a tier lands on the next tier's first weight.
        if index + 1 < tiers.count {
            return min(candidate, tiers[index + 1].start)
        }
        return candidate
    }

    public func roundedDown(_ weight: Weight) -> Weight? {
        guard weight >= minimum else { return nil }
        let tier = tiers[tierIndex(containing: weight)]
        let steps = (weight.thousandths - tier.start.thousandths) / tier.step.thousandths
        return Weight(thousandths: tier.start.thousandths + steps * tier.step.thousandths, unit: unit)
    }

    /// The last tier starting at or below `weight`. Requires `weight >= minimum`.
    private func tierIndex(containing weight: Weight) -> Int {
        tiers.lastIndex { $0.start <= weight } ?? 0
    }
}
