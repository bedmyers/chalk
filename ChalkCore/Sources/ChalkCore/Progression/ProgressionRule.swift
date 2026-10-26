/// Everything a progression rule needs to decide what to lift next.
public struct ProgressionInput: Sendable, Hashable {
    /// The weight the user entered when they set up the exercise.
    public var startingWeight: Weight
    public var target: ExerciseTarget
    /// Every week since `startingWeight`, oldest first.
    public var history: [WeekResult]
    public var loading: LoadingSettings

    public init(
        startingWeight: Weight,
        target: ExerciseTarget,
        history: [WeekResult],
        loading: LoadingSettings
    ) {
        self.startingWeight = startingWeight
        self.target = target
        self.history = history
        self.loading = loading
    }
}

/// Where a cycle-based rule currently is, e.g. "week 2 of 3".
public struct CycleProgress: Sendable, Hashable {
    public var week: Int
    public var length: Int

    public init(week: Int, length: Int) {
        self.week = week
        self.length = length
    }
}

/// A rule's decision about what to lift next.
public struct ProgressionOutcome: Sendable, Hashable {
    public var nextWeight: Weight
    /// The reps to aim for in each set of the next session.
    public var nextReps: Int
    /// Reps a bodyweight lift has earned on top of its original wave. Zero for
    /// weighted lifts.
    public var extraReps: Int
    /// Every decision so far, oldest first. Diff before and after logging a week
    /// to detect a fresh increase worth celebrating.
    public var events: [ProgressionEvent]
    /// Position in the current cycle, for rules that have one.
    public var cycle: CycleProgress?

    public init(
        nextWeight: Weight,
        nextReps: Int,
        extraReps: Int = 0,
        events: [ProgressionEvent],
        cycle: CycleProgress?
    ) {
        self.nextWeight = nextWeight
        self.nextReps = nextReps
        self.extraReps = extraReps
        self.events = events
        self.cycle = cycle
    }
}

/// A progression scheme, swappable per exercise.
///
/// Implementations must be pure: the outcome depends only on the input, so it
/// can be recomputed from history at any time.
public protocol ProgressionRule: Sendable {
    func evaluate(_ input: ProgressionInput) -> ProgressionOutcome
}
