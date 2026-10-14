/// A weight in a specific unit.
///
/// Stored as an integer count of thousandths of the unit so equality is exact
/// (137.5 lb is always exactly 137.5 lb) and plate math never drifts.
/// Arithmetic and comparison require both operands to share a unit.
public struct Weight: Sendable, Hashable, Codable {
    public let thousandths: Int
    public let unit: WeightUnit

    public init(thousandths: Int, unit: WeightUnit) {
        self.thousandths = thousandths
        self.unit = unit
    }

    public init(_ value: Double, _ unit: WeightUnit) {
        self.init(thousandths: Int((value * 1000).rounded()), unit: unit)
    }

    public static func pounds(_ value: Double) -> Weight { Weight(value, .pounds) }
    public static func kilograms(_ value: Double) -> Weight { Weight(value, .kilograms) }

    public var value: Double { Double(thousandths) / 1000 }

    /// The smallest representable step, used to nudge strictly above or below a weight.
    static func epsilon(_ unit: WeightUnit) -> Weight { Weight(thousandths: 1, unit: unit) }

    /// This weight multiplied by `factor`, rounded to the nearest thousandth.
    func scaled(by factor: Double) -> Weight {
        Weight(thousandths: Int((Double(thousandths) * factor).rounded()), unit: unit)
    }

    public static func + (lhs: Weight, rhs: Weight) -> Weight {
        precondition(lhs.unit == rhs.unit, "Cannot add \(lhs.unit) and \(rhs.unit)")
        return Weight(thousandths: lhs.thousandths + rhs.thousandths, unit: lhs.unit)
    }

    public static func - (lhs: Weight, rhs: Weight) -> Weight {
        precondition(lhs.unit == rhs.unit, "Cannot subtract \(rhs.unit) from \(lhs.unit)")
        return Weight(thousandths: lhs.thousandths - rhs.thousandths, unit: lhs.unit)
    }
}

extension Weight: Comparable {
    public static func < (lhs: Weight, rhs: Weight) -> Bool {
        precondition(lhs.unit == rhs.unit, "Cannot compare \(lhs.unit) and \(rhs.unit)")
        return lhs.thousandths < rhs.thousandths
    }
}

extension Weight: CustomStringConvertible {
    /// The number alone, without trailing zeros: "185", "137.5", "61.25".
    public var formattedValue: String {
        thousandths % 1000 == 0 ? String(thousandths / 1000) : String(value)
    }

    public var description: String {
        "\(formattedValue) \(unit.symbol)"
    }
}
