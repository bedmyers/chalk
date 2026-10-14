/// One logged set.
public struct SetResult: Sendable, Hashable {
    public var reps: Int

    public init(reps: Int) {
        self.reps = reps
    }
}

/// The sets logged for one exercise in one workout.
public struct SessionResult: Sendable, Hashable {
    public var sets: [SetResult]

    public init(sets: [SetResult]) {
        self.sets = sets
    }

    public init(reps: [Int]) {
        self.init(sets: reps.map(SetResult.init(reps:)))
    }
}

/// One program week for one exercise, in the order the user trained them.
public enum WeekResult: Sendable, Hashable {
    /// The user chose to skip the week (travel, illness). Skipped weeks pause the block.
    case skipped
    /// The sessions logged so far for this exercise during the week.
    case logged([SessionResult])
}

/// How a week counts toward a block.
public enum WeekOutcome: Sendable, Hashable {
    /// Every set of every scheduled session reached the target reps.
    case hit
    /// All scheduled sessions were logged but at least one set fell short.
    case miss
    /// Not every scheduled session has been logged yet. Doesn't advance the block.
    case inProgress
    /// Explicitly skipped. Doesn't advance the block.
    case skipped
}

/// What happened to the weight when a block closed.
public enum ProgressionEvent: Sendable, Hashable {
    case held(Weight)
    case increased(from: Weight, to: Weight)
    case deloaded(from: Weight, to: Weight)

    /// The weight to lift after this event.
    public var resultingWeight: Weight {
        switch self {
        case .held(let weight): weight
        case .increased(_, let to), .deloaded(_, let to): to
        }
    }
}

/// A closed block: the completed weeks lifted at one weight, and what happened next.
public struct BlockResult: Sendable, Hashable {
    public let weight: Weight
    /// The completed weeks of the block, each `.hit` or `.miss`.
    public let weeks: [WeekOutcome]
    public let event: ProgressionEvent

    public init(weight: Weight, weeks: [WeekOutcome], event: ProgressionEvent) {
        self.weight = weight
        self.weeks = weeks
        self.event = event
    }

    public var passed: Bool { weeks.allSatisfy { $0 == .hit } }
}
