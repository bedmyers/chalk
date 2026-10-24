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
    /// The smallest increase on a machine or cable stack.
    public var machineMinimumIncrease: Weight

    public init(plates: PlateSet, dumbbells: DumbbellSet, machineMinimumIncrease: Weight) {
        precondition(plates.unit == dumbbells.unit, "Plates and dumbbells must share a unit")
        precondition(plates.unit == machineMinimumIncrease.unit, "Machine minimum must share the plates' unit")
        self.plates = plates
        self.dumbbells = dumbbells
        self.machineMinimumIncrease = machineMinimumIncrease
    }

    /// Standard equipment. Increases are at least 5 lb / 2.5 kg, except dumbbells,
    /// which step by their own tiers (2.5 lb under 20 lb).
    public static func standard(for unit: WeightUnit) -> LoadingSettings {
        LoadingSettings(
            plates: .standard(for: unit),
            dumbbells: .standard(for: unit),
            machineMinimumIncrease: unit == .pounds ? .pounds(5) : .kilograms(2.5)
        )
    }

    public var unit: WeightUnit { plates.unit }

    public func ladder(for equipment: Equipment) -> any WeightLadder {
        switch equipment {
        case .barbell: plates
        case .dumbbell: dumbbells
        case .machine: UnroundedLadder(minimumIncrease: machineMinimumIncrease)
        }
    }
}

/// Every non-negative weight is loadable, so increments and deloads apply as-is
/// (increments still respect the minimum). Used for machines and cables, whose
/// stacks vary too much to model.
public struct UnroundedLadder: WeightLadder, Hashable {
    public let minimumIncrease: Weight

    public init(minimumIncrease: Weight) {
        self.minimumIncrease = minimumIncrease
    }

    public var unit: WeightUnit { minimumIncrease.unit }

    public var minimum: Weight { Weight(thousandths: 0, unit: unit) }

    public func roundedUp(_ weight: Weight) -> Weight { max(weight, minimum) }

    public func roundedDown(_ weight: Weight) -> Weight? { weight >= minimum ? weight : nil }

    public func minimumIncrease(from weight: Weight) -> Weight { minimumIncrease }
}
