import ChalkCore
import Testing

/// A session where every set hits `reps`.
func sets(_ reps: Int, count: Int = 4) -> WeekResult {
    .logged([SessionResult(reps: Array(repeating: reps, count: count))])
}

func logged(_ reps: [Int]) -> WeekResult {
    .logged([SessionResult(reps: reps)])
}

/// 4 × 6/8/10, like a heavy bench wave.
func wave(
    _ repsByWeek: [Int] = [6, 8, 10],
    equipment: Equipment = .barbell,
    sessionsPerWeek: Int = 1
) -> ExerciseTarget {
    ExerciseTarget(
        sets: 4,
        reps: repsByWeek.first ?? 8,
        repsByWeek: repsByWeek,
        increment: lb(5),
        equipment: equipment,
        sessionsPerWeek: sessionsPerWeek
    )
}

@Suite("Rep waves")
struct RepWaveTests {
    struct Scenario: Sendable, CustomTestStringConvertible {
        let name: String
        let history: [WeekResult]
        let weight: Weight
        let reps: Int
        let weekInBlock: Int
        let events: [ProgressionEvent]
        var testDescription: String { name }
    }

    // 185 lb barbell, +5 lb, 4 × 6/8/10.
    static let scenarios: [Scenario] = [
        Scenario(name: "no history starts at week 1's reps", history: [],
                 weight: lb(185), reps: 6, weekInBlock: 1, events: []),
        Scenario(name: "week 1 hit moves to week 2's reps", history: [sets(6)],
                 weight: lb(185), reps: 8, weekInBlock: 2, events: []),
        Scenario(name: "weeks 1 and 2 hit move to week 3's reps", history: [sets(6), sets(8)],
                 weight: lb(185), reps: 10, weekInBlock: 3, events: []),
        Scenario(name: "all three weeks hit: weight up, back to week 1's reps",
                 history: [sets(6), sets(8), sets(10)],
                 weight: lb(190), reps: 6, weekInBlock: 1,
                 events: [.increased(from: lb(185), to: lb(190))]),
        Scenario(name: "beating the target still hits", history: [sets(9), sets(9), sets(12)],
                 weight: lb(190), reps: 6, weekInBlock: 1,
                 events: [.increased(from: lb(185), to: lb(190))]),
        Scenario(name: "miss in week 1", history: [logged([6, 6, 6, 5]), sets(8), sets(10)],
                 weight: lb(185), reps: 6, weekInBlock: 1, events: [.held(lb(185))]),
        Scenario(name: "miss in week 2 is judged against 8", history: [sets(6), logged([8, 8, 7, 7]), sets(10)],
                 weight: lb(185), reps: 6, weekInBlock: 1, events: [.held(lb(185))]),
        Scenario(name: "miss in week 3 is judged against 10", history: [sets(6), sets(8), logged([10, 10, 10, 9])],
                 weight: lb(185), reps: 6, weekInBlock: 1, events: [.held(lb(185))]),
        Scenario(name: "repeating week 1's reps in week 2 is a miss", history: [sets(6), sets(6), sets(10)],
                 weight: lb(185), reps: 6, weekInBlock: 1, events: [.held(lb(185))]),
        Scenario(name: "a missed week still moves on to the next week's reps",
                 history: [sets(6), logged([8, 8, 7, 7])],
                 weight: lb(185), reps: 10, weekInBlock: 3, events: []),
        Scenario(name: "a skipped week pauses on the same reps", history: [sets(6), skip],
                 weight: lb(185), reps: 8, weekInBlock: 2, events: []),
        Scenario(name: "skips don't count as weeks", history: [sets(6), skip, sets(8), skip, sets(10)],
                 weight: lb(190), reps: 6, weekInBlock: 1,
                 events: [.increased(from: lb(185), to: lb(190))]),
        Scenario(name: "extra sets are ignored", history: [sets(6), sets(8), logged([10, 10, 10, 10, 4])],
                 weight: lb(190), reps: 6, weekInBlock: 1,
                 events: [.increased(from: lb(185), to: lb(190))]),
        Scenario(name: "fewer sets than the target is a miss", history: [sets(6, count: 3), sets(8), sets(10)],
                 weight: lb(185), reps: 6, weekInBlock: 1, events: [.held(lb(185))]),
        Scenario(name: "second block starts the wave over at the new weight",
                 history: [sets(6), sets(8), sets(10), sets(6)],
                 weight: lb(190), reps: 8, weekInBlock: 2,
                 events: [.increased(from: lb(185), to: lb(190))]),
        Scenario(name: "two passed blocks in a row",
                 history: [sets(6), sets(8), sets(10), sets(6), sets(8), sets(10)],
                 weight: lb(195), reps: 6, weekInBlock: 1,
                 events: [.increased(from: lb(185), to: lb(190)), .increased(from: lb(190), to: lb(195))]),
        Scenario(name: "two failed blocks deload",
                 history: [sets(6), sets(8), sets(9), sets(6), sets(8), sets(9)],
                 weight: lb(167.5), reps: 6, weekInBlock: 1,
                 events: [.held(lb(185)), .deloaded(from: lb(185), to: lb(167.5))]),
    ]

    @Test(arguments: scenarios)
    func progression(_ scenario: Scenario) {
        let outcome = evaluate(start: lb(185), target: wave(), history: scenario.history)
        #expect(outcome.nextWeight == scenario.weight)
        #expect(outcome.nextReps == scenario.reps)
        #expect(outcome.cycle == CycleProgress(week: scenario.weekInBlock, length: 3))
        #expect(outcome.events == scenario.events)
        #expect(outcome.extraReps == 0)
    }

    @Test func everySessionOfTheWeekIsJudgedAgainstThatWeeksReps() {
        let twiceAWeek = wave(sessionsPerWeek: 2)
        let bothHit: WeekResult = .logged([SessionResult(reps: [8, 8, 8, 8]), SessionResult(reps: [8, 8, 8, 8])])
        let oneShort: WeekResult = .logged([SessionResult(reps: [8, 8, 8, 8]), SessionResult(reps: [6, 6, 6, 6])])
        let week1: WeekResult = .logged([SessionResult(reps: [6, 6, 6, 6]), SessionResult(reps: [6, 6, 6, 6])])
        let week3: WeekResult = .logged([SessionResult(reps: [10, 10, 10, 10]), SessionResult(reps: [10, 10, 10, 10])])

        #expect(evaluate(start: lb(185), target: twiceAWeek, history: [week1, bothHit, week3]).nextWeight == lb(190))
        #expect(evaluate(start: lb(185), target: twiceAWeek, history: [week1, oneShort, week3]).nextWeight == lb(185))
    }

    @Test func oneSessionInDoesntAdvanceTheWave() {
        let partial: WeekResult = .logged([SessionResult(reps: [6, 6, 6, 6])])
        let outcome = evaluate(start: lb(185), target: wave(sessionsPerWeek: 2), history: [partial])
        #expect(outcome.nextReps == 6)
        #expect(outcome.cycle?.week == 1)
    }

    @Test func sameRepsEveryWeekWhenThereIsNoWave() {
        let flat = fourByEight()
        #expect(evaluate(start: lb(135), target: flat, history: []).nextReps == 8)
        #expect(evaluate(start: lb(135), target: flat, history: [hit, hit]).nextReps == 8)
        #expect(evaluate(start: lb(135), target: flat, history: passedBlock).nextReps == 8)
    }

    @Test(arguments: [
        ([Int](), 0, 8), ([Int](), 2, 8),
        ([6, 8, 10], 0, 6), ([6, 8, 10], 1, 8), ([6, 8, 10], 2, 10),
        // A short wave repeats its last week.
        ([6, 8], 2, 8),
    ])
    func repsForEachWeek(repsByWeek: [Int], week: Int, expected: Int) {
        let target = ExerciseTarget(sets: 4, reps: 8, repsByWeek: repsByWeek, increment: lb(5), equipment: .barbell)
        #expect(target.reps(inBlockWeek: week) == expected)
        #expect(target.reps(inBlockWeek: week, extraReps: 2) == expected + 2)
    }
}

@Suite("Bodyweight lifts")
struct BodyweightTests {
    static let zero = lb(0)

    struct Scenario: Sendable, CustomTestStringConvertible {
        let name: String
        let history: [WeekResult]
        let reps: Int
        let extraReps: Int
        let events: [ProgressionEvent]
        var testDescription: String { name }
    }

    // Pull-ups, 4 × 6/8/10.
    static let scenarios: [Scenario] = [
        Scenario(name: "no history", history: [],
                 reps: 6, extraReps: 0, events: []),
        Scenario(name: "mid-block follows the wave", history: [sets(6), sets(8)],
                 reps: 10, extraReps: 0, events: []),
        Scenario(name: "a passed block adds a rep to every week",
                 history: [sets(6), sets(8), sets(10)],
                 reps: 7, extraReps: 1, events: [.repsRaised(from: 0, to: 1)]),
        Scenario(name: "the raised wave is what's judged next",
                 history: [sets(6), sets(8), sets(10), sets(7), sets(9)],
                 reps: 11, extraReps: 1, events: [.repsRaised(from: 0, to: 1)]),
        Scenario(name: "the old wave misses after a raise",
                 history: [sets(6), sets(8), sets(10), sets(6), sets(8), sets(10)],
                 reps: 7, extraReps: 1, events: [.repsRaised(from: 0, to: 1), .held(zero)]),
        Scenario(name: "two passed blocks add two reps",
                 history: [sets(6), sets(8), sets(10), sets(7), sets(9), sets(11)],
                 reps: 8, extraReps: 2, events: [.repsRaised(from: 0, to: 1), .repsRaised(from: 1, to: 2)]),
        Scenario(name: "a failed block holds",
                 history: [sets(6), sets(8), sets(9)],
                 reps: 6, extraReps: 0, events: [.held(zero)]),
        Scenario(name: "deload never goes below the original wave",
                 history: [sets(6), sets(8), sets(9), sets(6), sets(8), sets(9)],
                 reps: 6, extraReps: 0, events: [.held(zero), .held(zero)]),
        Scenario(name: "deload takes a rep back off",
                 history: [sets(6), sets(8), sets(10), sets(7), sets(9), sets(10), sets(7), sets(9), sets(10)],
                 reps: 6, extraReps: 0,
                 events: [.repsRaised(from: 0, to: 1), .held(zero), .repsLowered(from: 1, to: 0)]),
    ]

    @Test(arguments: scenarios)
    func progression(_ scenario: Scenario) {
        let outcome = evaluate(start: Self.zero, target: wave(equipment: .bodyweight), history: scenario.history)
        #expect(outcome.nextWeight == Self.zero)
        #expect(outcome.nextReps == scenario.reps)
        #expect(outcome.extraReps == scenario.extraReps)
        #expect(outcome.events == scenario.events)
    }

    @Test func sameRepsEveryWeekAlsoRises() {
        let dips = ExerciseTarget(sets: 3, reps: 10, increment: lb(5), equipment: .bodyweight)
        let outcome = evaluate(start: Self.zero, target: dips, history: [sets(10, count: 3), sets(10, count: 3), sets(10, count: 3)])
        #expect(outcome.nextReps == 11)
    }

    @Test func blocksRecordTheRepsTheyWereJudgedAt() {
        let replay = ThreeWeekBlockRule().replay(ProgressionInput(
            startingWeight: Self.zero,
            target: wave(equipment: .bodyweight),
            history: [sets(6), sets(8), sets(10), sets(7), sets(9), sets(11)],
            loading: .standard(for: .pounds)
        ))
        #expect(replay.blocks.map(\.extraReps) == [0, 1])
    }

    @Test(arguments: [WeightUnit.pounds, .kilograms])
    func thereIsNoWeightToLoad(unit: WeightUnit) {
        let loading = LoadingSettings.standard(for: unit)
        let zero = Weight(thousandths: 0, unit: unit)
        let some = Weight(thousandths: 25_000, unit: unit)
        #expect(!Equipment.bodyweight.isWeighted)
        #expect(loading.snapped(some, for: .bodyweight) == zero)
        #expect(loading.stepped(zero, for: .bodyweight, up: true) == zero)
        #expect(loading.stepped(zero, for: .bodyweight, up: false) == zero)
    }
}
