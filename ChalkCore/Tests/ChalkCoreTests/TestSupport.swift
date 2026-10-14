import ChalkCore

// Shorthand for building histories against a 4×8 target, one session per week.

/// Every set hits 8 reps.
let hit: WeekResult = .logged([SessionResult(reps: [8, 8, 8, 8])])
/// One rep short on the last set.
let miss: WeekResult = .logged([SessionResult(reps: [8, 8, 8, 7])])
let skip: WeekResult = .skipped

let passedBlock: [WeekResult] = [hit, hit, hit]
let failedBlock: [WeekResult] = [hit, hit, miss]

func lb(_ value: Double) -> Weight { .pounds(value) }
func kg(_ value: Double) -> Weight { .kilograms(value) }

func fourByEight(
    increment: Weight = lb(5),
    equipment: Equipment = .barbell,
    sessionsPerWeek: Int = 1
) -> ExerciseTarget {
    ExerciseTarget(
        sets: 4,
        reps: 8,
        increment: increment,
        equipment: equipment,
        sessionsPerWeek: sessionsPerWeek
    )
}

func evaluate(
    start: Weight,
    target: ExerciseTarget = fourByEight(),
    history: [WeekResult]
) -> ProgressionOutcome {
    ThreeWeekBlockRule().evaluate(ProgressionInput(
        startingWeight: start,
        target: target,
        history: history,
        loading: .standard(for: start.unit)
    ))
}
