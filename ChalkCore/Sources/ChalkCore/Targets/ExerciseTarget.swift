/// Which half of the body an exercise mainly trains. Drives default increments.
public enum BodyRegion: String, Sendable, Hashable, Codable, CaseIterable {
    case upper
    case lower

    /// +2.5 lb / +1.25 kg for upper body, +5 lb / +2.5 kg for lower body.
    public func defaultIncrement(in unit: WeightUnit) -> Weight {
        switch (self, unit) {
        case (.upper, .pounds): .pounds(2.5)
        case (.lower, .pounds): .pounds(5)
        case (.upper, .kilograms): .kilograms(1.25)
        case (.lower, .kilograms): .kilograms(2.5)
        }
    }
}

/// What an exercise slot asks for each session, and how it progresses.
public struct ExerciseTarget: Sendable, Hashable {
    public var sets: Int
    public var reps: Int
    /// Added to the weight after a passed block, then rounded up to a loadable weight.
    public var increment: Weight
    public var equipment: Equipment
    /// How many times per week this exercise is scheduled. A week only counts
    /// once every scheduled session has been logged.
    public var sessionsPerWeek: Int

    public init(
        sets: Int,
        reps: Int,
        increment: Weight,
        equipment: Equipment,
        sessionsPerWeek: Int = 1
    ) {
        self.sets = sets
        self.reps = reps
        self.increment = increment
        self.equipment = equipment
        self.sessionsPerWeek = sessionsPerWeek
    }
}
