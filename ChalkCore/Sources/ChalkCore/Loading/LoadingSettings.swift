/// How an exercise is loaded, which decides which weights are achievable.
public enum Equipment: String, Sendable, Hashable, Codable, CaseIterable {
    case barbell
    case dumbbell
    /// Machines and cables: the raw increment is applied with no rounding.
    case machine
    /// Pull-ups, dips: no load. Progress by adding reps to the wave instead of weight.
    case bodyweight

    /// Whether the exercise has a weight to load and increase.
    public var isWeighted: Bool { self != .bodyweight }
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

    /// A weight the user entered, adjusted to what can actually be set up.
    /// Barbells and dumbbells snap to the nearest loadable weight (ties go up) and
    /// never go below the bar or the lightest dumbbell. Machines are only kept
    /// from going negative, since stacks vary too much to model.
    public func snapped(_ weight: Weight, for equipment: Equipment) -> Weight {
        switch equipment {
        case .barbell: plates.nearest(weight)
        case .dumbbell: dumbbells.nearest(weight)
        case .machine: max(weight, Weight(thousandths: 0, unit: weight.unit))
        case .bodyweight: Weight(thousandths: 0, unit: weight.unit)
        }
    }

    /// One step heavier or lighter, for ± buttons on weight entry. Steps by the
    /// lift's smallest jump (so 20 lb dumbbells step down to 17.5, not 15), snaps
    /// barbells to loadable weights, and never goes below the lightest weight.
    public func stepped(_ weight: Weight, for equipment: Equipment, up: Bool) -> Weight {
        let ladder = ladder(for: equipment)
        if up {
            return ladder.increased(weight, by: Weight(thousandths: 0, unit: weight.unit))
        }
        let step = ladder.minimumIncrease(from: weight - .epsilon(weight.unit))
        return max(snapped(weight - step, for: equipment), ladder.minimum)
    }

    public func ladder(for equipment: Equipment) -> any WeightLadder {
        switch equipment {
        case .barbell: plates
        case .dumbbell: dumbbells
        case .machine: UnroundedLadder(minimumIncrease: machineMinimumIncrease)
        case .bodyweight: BodyweightLadder(unit: unit)
        }
    }
}

/// No load: the only weight is zero. Bodyweight lifts progress by reps, so the
/// block rule never increases or deloads along this ladder.
public struct BodyweightLadder: WeightLadder, Hashable {
    public let unit: WeightUnit

    public init(unit: WeightUnit) {
        self.unit = unit
    }

    public var minimum: Weight { Weight(thousandths: 0, unit: unit) }

    public func roundedUp(_ weight: Weight) -> Weight { minimum }

    public func roundedDown(_ weight: Weight) -> Weight? { minimum }

    public func minimumIncrease(from weight: Weight) -> Weight { minimum }
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
