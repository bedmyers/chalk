import ChalkCore
import Testing

@Suite("Training weeks")
struct TrainingWeeksTests {
    static let good = [SetResult](repeating: SetResult(reps: 8), count: 4)
    static let short = [8, 8, 8, 7].map(SetResult.init(reps:))

    static func done(_ week: Int, _ sets: [SetResult] = good) -> SlotSession {
        SlotSession(week: week, status: .completed(sets: sets))
    }

    static func skipped(_ week: Int) -> SlotSession {
        SlotSession(week: week, status: .skipped)
    }

    struct GroupingScenario: Sendable, CustomTestStringConvertible {
        let name: String
        let sessions: [SlotSession]
        let history: [WeekResult]
        var testDescription: String { name }
    }

    static let groupingScenarios: [GroupingScenario] = [
        GroupingScenario(name: "no sessions", sessions: [], history: []),
        GroupingScenario(name: "one session per week", sessions: [done(1), done(2)],
                         history: [.logged([SessionResult(sets: good)]), .logged([SessionResult(sets: good)])]),
        GroupingScenario(name: "out-of-order input is sorted by week", sessions: [done(2, short), done(1)],
                         history: [.logged([SessionResult(sets: good)]), .logged([SessionResult(sets: short)])]),
        GroupingScenario(name: "two sessions in a week are grouped", sessions: [done(1), done(1, short)],
                         history: [.logged([SessionResult(sets: good), SessionResult(sets: short)])]),
        GroupingScenario(name: "only session skipped pauses the week", sessions: [skipped(1)],
                         history: [.skipped]),
        GroupingScenario(name: "all sessions skipped pauses the week", sessions: [skipped(1), skipped(1)],
                         history: [.skipped]),
        GroupingScenario(name: "skipped alongside completed counts as no sets",
                         sessions: [done(1), skipped(1)],
                         history: [.logged([SessionResult(sets: good), SessionResult(sets: [])])]),
        GroupingScenario(name: "dropped exercise counts as no sets", sessions: [done(1, [])],
                         history: [.logged([SessionResult(sets: [])])]),
    ]

    @Test(arguments: groupingScenarios)
    func grouping(_ scenario: GroupingScenario) {
        #expect(TrainingWeeks.history(from: scenario.sessions) == scenario.history)
    }

    // MARK: Skipping one day mid-week, end to end through the engine

    struct SkipScenario: Sendable, CustomTestStringConvertible {
        let name: String
        let sessionsPerWeek: Int
        let sessions: [SlotSession]
        let weight: Weight
        let weekInBlock: Int
        var testDescription: String { name }
    }

    static let skipScenarios: [SkipScenario] = [
        // Push/Pull/Legs, Pull skipped in week 2: the Pull slot's week is paused.
        SkipScenario(name: "1x/week slot whose day is skipped pauses",
                     sessionsPerWeek: 1,
                     sessions: [done(1), skipped(2), done(3), done(4)],
                     weight: lb(140), weekInBlock: 1),
        SkipScenario(name: "1x/week slot, skipped week 2 leaves block at week 3",
                     sessionsPerWeek: 1,
                     sessions: [done(1), skipped(2), done(3)],
                     weight: lb(135), weekInBlock: 3),
        // Slot on Mon and Fri, Fri skipped in week 2: a miss, so the block holds.
        SkipScenario(name: "2x/week slot with one day skipped is a miss",
                     sessionsPerWeek: 2,
                     sessions: [done(1), done(1), done(2), skipped(2), done(3), done(3)],
                     weight: lb(135), weekInBlock: 1),
        // Mon skipped, Fri not logged yet: the week is still in progress.
        SkipScenario(name: "2x/week slot, skipped first day waits for the second",
                     sessionsPerWeek: 2,
                     sessions: [done(1), done(1), skipped(2)],
                     weight: lb(135), weekInBlock: 2),
        // Both days skipped: same as skipping the whole week.
        SkipScenario(name: "2x/week slot with both days skipped pauses",
                     sessionsPerWeek: 2,
                     sessions: [done(1), done(1), skipped(2), skipped(2), done(3), done(3), done(4), done(4)],
                     weight: lb(140), weekInBlock: 1),
    ]

    @Test(arguments: skipScenarios)
    func skippingOneDayMidWeek(_ scenario: SkipScenario) {
        let outcome = evaluate(
            start: lb(135),
            target: fourByEight(sessionsPerWeek: scenario.sessionsPerWeek),
            history: TrainingWeeks.history(from: scenario.sessions)
        )
        #expect(outcome.nextWeight == scenario.weight)
        #expect(outcome.cycle?.week == scenario.weekInBlock)
    }
}
