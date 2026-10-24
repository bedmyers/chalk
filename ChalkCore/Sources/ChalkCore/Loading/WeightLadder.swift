/// The set of weights that can actually be loaded for one kind of equipment.
public protocol WeightLadder: Sendable {
    var unit: WeightUnit { get }

    /// The lightest loadable weight (an empty bar, the smallest dumbbell).
    var minimum: Weight { get }

    /// The lightest loadable weight that is greater than or equal to `weight`.
    func roundedUp(_ weight: Weight) -> Weight

    /// The heaviest loadable weight that is less than or equal to `weight`,
    /// or nil if `weight` is below `minimum`.
    func roundedDown(_ weight: Weight) -> Weight?

    /// The smallest increase allowed from `weight`, whatever the exercise's increment.
    func minimumIncrease(from weight: Weight) -> Weight
}

extension WeightLadder {
    /// The nearest loadable weight (ties go up). Never below `minimum`.
    public func nearest(_ weight: Weight) -> Weight {
        let above = roundedUp(weight)
        guard let below = roundedDown(weight) else { return above }
        return weight - below < above - weight ? below : above
    }

    /// `weight` plus the larger of `increment` and the minimum increase, rounded up
    /// to the next loadable weight. Always at least the minimum increase heavier.
    public func increased(_ weight: Weight, by increment: Weight) -> Weight {
        let step = max(increment, minimumIncrease(from: weight), .epsilon(weight.unit))
        return roundedUp(weight + step)
    }

    /// `weight` reduced by `fraction`, rounded to the nearest loadable weight
    /// (ties go down). Always strictly lighter than `weight` unless `weight`
    /// is already at or below the minimum, in which case it is returned unchanged.
    public func deloaded(_ weight: Weight, by fraction: Double) -> Weight {
        let target = weight.scaled(by: 1 - fraction)
        let above = roundedUp(target)
        var result = above
        if let below = roundedDown(target), target - below <= above - target {
            result = below
        }
        if result >= weight {
            result = roundedDown(weight - .epsilon(weight.unit)) ?? weight
        }
        return result
    }
}

// MARK: - Integer helpers

/// Ceiling division for non-negative dividends and positive divisors.
func ceilDiv(_ a: Int, _ b: Int) -> Int { (a + b - 1) / b }

func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
