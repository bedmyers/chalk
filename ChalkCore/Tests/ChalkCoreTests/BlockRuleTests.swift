import ChalkCore
import Testing

@Suite("Three-week block rule")
struct BlockRuleTests {
    struct Scenario: Sendable, CustomTestStringConvertible {
        let name: String
        let history: [WeekResult]
        let weight: Weight
        let weekInBlock: Int
        let events: [ProgressionEvent]
        var testDescription: String { name }
    }

    // 135 lb barbell, +5 lb increment, 4×8.
    static let scenarios: [Scenario] = [
        Scenario(name: "no history", history: [],
                 weight: lb(135), weekInBlock: 1, events: []),
        Scenario(name: "one hit", history: [hit],
                 weight: lb(135), weekInBlock: 2, events: []),
        Scenario(name: "two hits", history: [hit, hit],
                 weight: lb(135), weekInBlock: 3, events: []),
        Scenario(name: "all three weeks hit", history: passedBlock,
                 weight: lb(140), weekInBlock: 1, events: [.increased(from: lb(135), to: lb(140))]),
        Scenario(name: "miss in week 1", history: [miss, hit, hit],
                 weight: lb(135), weekInBlock: 1, events: [.held(lb(135))]),
        Scenario(name: "miss in week 2", history: [hit, miss, hit],
                 weight: lb(135), weekInBlock: 1, events: [.held(lb(135))]),
        Scenario(name: "miss in week 3", history: [hit, hit, miss],
                 weight: lb(135), weekInBlock: 1, events: [.held(lb(135))]),
        Scenario(name: "all three weeks missed", history: [miss, miss, miss],
                 weight: lb(135), weekInBlock: 1, events: [.held(lb(135))]),
        Scenario(name: "skipped weeks pause the block", history: [hit, skip, hit, skip, hit],
                 weight: lb(140), weekInBlock: 1, events: [.increased(from: lb(135), to: lb(140))]),
        Scenario(name: "skip before the block starts", history: [skip, skip, hit, hit, hit],
                 weight: lb(140), weekInBlock: 1, events: [.increased(from: lb(135), to: lb(140))]),
        Scenario(name: "skip before week 3 doesn't close the block", history: [hit, hit, skip],
                 weight: lb(135), weekInBlock: 3, events: []),
        Scenario(name: "skip after a passed block", history: passedBlock + [skip],
                 weight: lb(140), weekInBlock: 1, events: [.increased(from: lb(135), to: lb(140))]),
        Scenario(name: "only skips", history: [skip, skip, skip],
                 weight: lb(135), weekInBlock: 1, events: []),
        Scenario(name: "first week of second block", history: passedBlock + [hit],
                 weight: lb(140), weekInBlock: 2, events: [.increased(from: lb(135), to: lb(140))]),
        Scenario(name: "three passed blocks in a row", history: passedBlock + passedBlock + passedBlock,
                 weight: lb(150), weekInBlock: 1, events: [
                     .increased(from: lb(135), to: lb(140)),
                     .increased(from: lb(140), to: lb(145)),
                     .increased(from: lb(145), to: lb(150)),
                 ]),
        Scenario(name: "passed then failed", history: passedBlock + failedBlock,
                 weight: lb(140), weekInBlock: 1, events: [
                     .increased(from: lb(135), to: lb(140)),
                     .held(lb(140)),
                 ]),
        Scenario(name: "failed then passed", history: failedBlock + passedBlock,
                 weight: lb(140), weekInBlock: 1, events: [
                     .held(lb(135)),
                     .increased(from: lb(135), to: lb(140)),
                 ]),
    ]

    @Test(arguments: scenarios)
    func progression(_ scenario: Scenario) {
        let outcome = evaluate(start: lb(135), history: scenario.history)
        #expect(outcome.nextWeight == scenario.weight)
        #expect(outcome.cycle == CycleProgress(week: scenario.weekInBlock, length: 3))
        #expect(outcome.events == scenario.events)
    }

    // MARK: Incomplete weeks don't advance

    struct IncompleteScenario: Sendable, CustomTestStringConvertible {
        let name: String
        let history: [WeekResult]
        let weight: Weight
        let weekInBlock: Int
        var testDescription: String { name }
    }

    static let fullWeek: WeekResult = .logged([
        SessionResult(reps: [8, 8, 8, 8]), SessionResult(reps: [8, 8, 8, 8]),
    ])
    static let halfWeek: WeekResult = .logged([SessionResult(reps: [8, 8, 8, 8])])

    // 2 sessions per week.
    static let incompleteScenarios: [IncompleteScenario] = [
        IncompleteScenario(name: "half a week doesn't count", history: [halfWeek],
                           weight: lb(135), weekInBlock: 1),
        IncompleteScenario(name: "half-done week 3 doesn't close the block",
                           history: [fullWeek, fullWeek, halfWeek],
                           weight: lb(135), weekInBlock: 3),
        IncompleteScenario(name: "finishing week 3 closes the block",
                           history: [fullWeek, fullWeek, fullWeek],
                           weight: lb(140), weekInBlock: 1),
    ]

    @Test(arguments: incompleteScenarios)
    func incompleteWeeks(_ scenario: IncompleteScenario) {
        let outcome = evaluate(
            start: lb(135),
            target: fourByEight(sessionsPerWeek: 2),
            history: scenario.history
        )
        #expect(outcome.nextWeight == scenario.weight)
        #expect(outcome.cycle?.week == scenario.weekInBlock)
    }

    // MARK: Training weeks finish on the session that completes them, not on the calendar

    struct SessionLogScenario: Sendable, CustomTestStringConvertible {
        let sessionsLogged: Int
        let weight: Weight
        let weekInBlock: Int
        var testDescription: String { "after \(sessionsLogged) sessions" }
    }

    // 2 sessions per week, every session hits. Sessions are grouped into training
    // weeks in the order they're logged, exactly as the app will build history.
    static let sessionLogScenarios: [SessionLogScenario] = [
        SessionLogScenario(sessionsLogged: 1, weight: lb(135), weekInBlock: 1),
        SessionLogScenario(sessionsLogged: 2, weight: lb(135), weekInBlock: 2),
        SessionLogScenario(sessionsLogged: 3, weight: lb(135), weekInBlock: 2),
        SessionLogScenario(sessionsLogged: 4, weight: lb(135), weekInBlock: 3),
        SessionLogScenario(sessionsLogged: 5, weight: lb(135), weekInBlock: 3),
        // The 6th session completes week 3: the block closes immediately.
        SessionLogScenario(sessionsLogged: 6, weight: lb(140), weekInBlock: 1),
        // The 7th session starts week 1 of the next block.
        SessionLogScenario(sessionsLogged: 7, weight: lb(140), weekInBlock: 1),
        SessionLogScenario(sessionsLogged: 8, weight: lb(140), weekInBlock: 2),
    ]

    @Test(arguments: sessionLogScenarios)
    func weekFinishesWhenItsLastSessionIsLogged(_ scenario: SessionLogScenario) {
        let sessions = Array(repeating: SessionResult(reps: [8, 8, 8, 8]), count: scenario.sessionsLogged)
        let history: [WeekResult] = stride(from: 0, to: sessions.count, by: 2).map {
            .logged(Array(sessions[$0..<min($0 + 2, sessions.count)]))
        }
        let outcome = evaluate(
            start: lb(135),
            target: fourByEight(sessionsPerWeek: 2),
            history: history
        )
        #expect(outcome.nextWeight == scenario.weight)
        #expect(outcome.cycle?.week == scenario.weekInBlock)
    }

    // MARK: Increments round up to loadable weights

    struct IncrementScenario: Sendable, CustomTestStringConvertible {
        let name: String
        let start: Weight
        let increment: Weight
        let equipment: Equipment
        let expected: Weight
        var testDescription: String { name }
    }

    static let incrementScenarios: [IncrementScenario] = [
        IncrementScenario(name: "lb barbell lower +5", start: lb(225), increment: lb(5),
                          equipment: .barbell, expected: lb(230)),
        IncrementScenario(name: "lb barbell upper +2.5", start: lb(135), increment: lb(2.5),
                          equipment: .barbell, expected: lb(137.5)),
        IncrementScenario(name: "kg barbell lower +2.5", start: kg(100), increment: kg(2.5),
                          equipment: .barbell, expected: kg(102.5)),
        IncrementScenario(name: "kg barbell upper +1.25 rounds up to +1.5", start: kg(60),
                          increment: kg(1.25), equipment: .barbell, expected: kg(61.5)),
        IncrementScenario(name: "lb dumbbell +2.5 under 20", start: lb(15), increment: lb(2.5),
                          equipment: .dumbbell, expected: lb(17.5)),
        IncrementScenario(name: "lb dumbbell +2.5 at 20 rounds up to 25", start: lb(20),
                          increment: lb(2.5), equipment: .dumbbell, expected: lb(25)),
        IncrementScenario(name: "lb dumbbell +5 crossing 20", start: lb(17.5), increment: lb(5),
                          equipment: .dumbbell, expected: lb(25)),
        IncrementScenario(name: "kg dumbbell +1.25 above 10 rounds up to 12.5", start: kg(10),
                          increment: kg(1.25), equipment: .dumbbell, expected: kg(12.5)),
        IncrementScenario(name: "lb machine +2.5 unrounded", start: lb(100), increment: lb(2.5),
                          equipment: .machine, expected: lb(102.5)),
        IncrementScenario(name: "lb machine odd +3 unrounded", start: lb(50), increment: lb(3),
                          equipment: .machine, expected: lb(53)),
        IncrementScenario(name: "kg machine +1.25 unrounded", start: kg(30), increment: kg(1.25),
                          equipment: .machine, expected: kg(31.25)),
    ]

    @Test(arguments: incrementScenarios)
    func increments(_ scenario: IncrementScenario) {
        let outcome = evaluate(
            start: scenario.start,
            target: fourByEight(increment: scenario.increment, equipment: scenario.equipment),
            history: passedBlock
        )
        #expect(outcome.nextWeight == scenario.expected)
    }

    @Test(arguments: [
        (BodyRegion.upper, WeightUnit.pounds, lb(2.5)),
        (.lower, .pounds, lb(5)),
        (.upper, .kilograms, kg(1.25)),
        (.lower, .kilograms, kg(2.5)),
    ])
    func defaultIncrements(region: BodyRegion, unit: WeightUnit, expected: Weight) {
        #expect(region.defaultIncrement(in: unit) == expected)
    }
}
