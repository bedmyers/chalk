/// How an exercise is loaded, which decides which weights are achievable.
public enum Equipment: String, Sendable, Hashable, Codable, CaseIterable {
    case barbell
    case dumbbell
    /// Machines and cables: the raw increment is applied with no rounding.
    case machine
}

/// The user's equipment, stored as settings so it can be made editable later.
public struct LoadingSettings: Sendable, Hashable {
    public var plates: PlateSet
    public var dumbbells: DumbbellSet

    public init(plates: PlateSet, dumbbells: DumbbellSet) {
        precondition(plates.unit == dumbbells.unit, "Plates and dumbbells must share a unit")
        self.plates = plates
        self.dumbbells = dumbbells
    }

    public static func standard(for unit: WeightUnit) -> LoadingSettings {
        LoadingSettings(plates: .standard(for: unit), dumbbells: .standard(for: unit))
    }

    public var unit: WeightUnit { plates.unit }

    public func ladder(for equipment: Equipment) -> any WeightLadder {
        switch equipment {
        case .barbell: plates
        case .dumbbell: dumbbells
        case .machine: UnroundedLadder(unit: unit)
        }
    }
}

/// Every non-negative weight is loadable, so increments and deloads apply as-is.
/// Used for machines and cables, whose stacks vary too much to model.
public struct UnroundedLadder: WeightLadder, Hashable {
    public let unit: WeightUnit

    public init(unit: WeightUnit) {
        self.unit = unit
    }

    public var minimum: Weight { Weight(thousandths: 0, unit: unit) }

    public func roundedUp(_ weight: Weight) -> Weight { max(weight, minimum) }

    public func roundedDown(_ weight: Weight) -> Weight? { weight >= minimum ? weight : nil }
}
