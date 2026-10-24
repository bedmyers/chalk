/// A barbell plus the plate sizes available to load it.
///
/// Plates are loaded in pairs (one per side) and every size is assumed to be
/// available in unlimited pairs. Plate sizes don't need to divide each other;
/// reachability is computed exactly.
public struct PlateSet: WeightLadder, Hashable {
    public let bar: Weight
    /// Distinct plate sizes, heaviest first.
    public let plates: [Weight]
    /// The smallest allowed increase. Small plates still serve deloads and
    /// off-ladder starting weights, but a bump is never smaller than this.
    public let minimumIncrease: Weight

    /// `minimumIncrease` defaults to one pair of the smallest plate.
    public init(bar: Weight, plates: [Weight], minimumIncrease: Weight? = nil) {
        let sizes = Set(plates.filter { $0.thousandths > 0 })
        precondition(!sizes.isEmpty, "A plate set needs at least one plate size")
        precondition(sizes.allSatisfy { $0.unit == bar.unit }, "Plates must use the bar's unit")
        let smallestPair = Weight(thousandths: 2 * (sizes.min()?.thousandths ?? 0), unit: bar.unit)
        precondition(minimumIncrease.map { $0.unit == bar.unit } ?? true, "Minimum increase must use the bar's unit")
        self.bar = bar
        self.plates = sizes.sorted(by: >)
        self.minimumIncrease = minimumIncrease ?? smallestPair
    }

    /// Increases are at least 5 lb (2.5 lb per side).
    public static let standardPounds = PlateSet(
        bar: .pounds(45),
        plates: [45, 35, 25, 10, 5, 2.5, 1.25].map { .pounds($0) },
        minimumIncrease: .pounds(5)
    )

    /// Increases are at least 2.5 kg (1.25 kg per side).
    public static let standardKilograms = PlateSet(
        bar: .kilograms(20),
        plates: [25, 20, 15, 10, 5, 2.5, 1.25, 0.5, 0.25].map { .kilograms($0) },
        minimumIncrease: .kilograms(2.5)
    )

    public static func standard(for unit: WeightUnit) -> PlateSet {
        switch unit {
        case .pounds: standardPounds
        case .kilograms: standardKilograms
        }
    }

    public var unit: WeightUnit { bar.unit }
    public var minimum: Weight { bar }

    public func minimumIncrease(from weight: Weight) -> Weight { minimumIncrease }

    public func roundedUp(_ weight: Weight) -> Weight {
        guard weight > bar else { return bar }
        let neededPerSide = ceilDiv(weight.thousandths - bar.thousandths, 2)
        let first = ceilDiv(neededPerSide, granularity)
        // Some reachable per-side load always exists within one heaviest plate
        // of `first` (a multiple of the heaviest plate), so this bound is safe.
        let reachable = reachablePerSide(upTo: first + plateSteps[0])
        let steps = (first..<reachable.count).first { reachable[$0] } ?? first
        return total(perSideSteps: steps)
    }

    public func roundedDown(_ weight: Weight) -> Weight? {
        guard weight >= bar else { return nil }
        let availablePerSide = (weight.thousandths - bar.thousandths) / 2
        let last = availablePerSide / granularity
        let reachable = reachablePerSide(upTo: last)
        // Zero steps (empty bar) is always reachable.
        let steps = (0...last).last { reachable[$0] } ?? 0
        return total(perSideSteps: steps)
    }

    // MARK: - Private

    /// The largest unit every plate is a multiple of; all per-side loads are multiples of it.
    private var granularity: Int {
        plates.map(\.thousandths).reduce(0, gcd)
    }

    /// Plate sizes expressed in multiples of `granularity`, heaviest first.
    private var plateSteps: [Int] {
        plates.map { $0.thousandths / granularity }
    }

    /// `result[n]` is true if `n * granularity` per side can be built from the plates.
    private func reachablePerSide(upTo limit: Int) -> [Bool] {
        let steps = plateSteps
        var reachable = [Bool](repeating: false, count: limit + 1)
        reachable[0] = true
        if limit > 0 {
            for n in 1...limit {
                reachable[n] = steps.contains { $0 <= n && reachable[n - $0] }
            }
        }
        return reachable
    }

    private func total(perSideSteps steps: Int) -> Weight {
        Weight(thousandths: bar.thousandths + 2 * steps * granularity, unit: unit)
    }
}
