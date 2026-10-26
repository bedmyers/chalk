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

/// What happened when a block closed.
public enum ProgressionEvent: Sendable, Hashable {
    case held(Weight)
    case increased(from: Weight, to: Weight)
    case deloaded(from: Weight, to: Weight)
    /// A bodyweight lift passed a block: every week of its wave gains a rep.
    /// `from` and `to` are the reps added on top of the original wave.
    case repsRaised(from: Int, to: Int)
    /// A bodyweight lift failed enough blocks to deload: its wave loses a rep.
    case repsLowered(from: Int, to: Int)

    /// The weight to lift after this event, or nil when the weight didn't change
    /// because the event was about reps.
    public var resultingWeight: Weight? {
        switch self {
        case .held(let weight): weight
        case .increased(_, let to), .deloaded(_, let to): to
        case .repsRaised, .repsLowered: nil
        }
    }
}

/// A closed block: the completed weeks lifted at one weight, and what happened next.
public struct BlockResult: Sendable, Hashable {
    public let weight: Weight
    /// Reps a bodyweight lift had earned on top of its wave during this block.
    public let extraReps: Int
    /// The completed weeks of the block, each `.hit` or `.miss`.
    public let weeks: [WeekOutcome]
    public let event: ProgressionEvent

    public init(weight: Weight, extraReps: Int = 0, weeks: [WeekOutcome], event: ProgressionEvent) {
        self.weight = weight
        self.extraReps = extraReps
        self.weeks = weeks
        self.event = event
    }

    public var passed: Bool { weeks.allSatisfy { $0 == .hit } }
}
