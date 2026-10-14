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
}

extension WeightLadder {
    /// `weight + increment`, rounded up to the next loadable weight.
    /// Always strictly heavier than `weight`, even for a zero or negative increment.
    public func increased(_ weight: Weight, by increment: Weight) -> Weight {
        let step = max(increment, .epsilon(weight.unit))
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
