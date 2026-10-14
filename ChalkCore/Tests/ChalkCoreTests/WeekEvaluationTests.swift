import ChalkCore
import Testing

@Suite("Week evaluation")
struct WeekEvaluationTests {
    struct Scenario: Sendable, CustomTestStringConvertible {
        let name: String
        let sessionsPerWeek: Int
        let week: WeekResult
        let expected: WeekOutcome
        var testDescription: String { name }
    }

    static let scenarios: [Scenario] = [
        Scenario(name: "all sets hit", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [8, 8, 8, 8])]), expected: .hit),
        Scenario(name: "extra reps still hit", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [10, 9, 8, 8])]), expected: .hit),
        Scenario(name: "extra set still hits", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [8, 8, 8, 8, 8])]), expected: .hit),
        Scenario(name: "short extra set is ignored", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [8, 8, 8, 8, 5])]), expected: .hit),
        Scenario(name: "a good extra set doesn't rescue a short target set", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [8, 8, 8, 7, 8])]), expected: .miss),
        Scenario(name: "8,8,8,7 on 4x8 is a miss", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [8, 8, 8, 7])]), expected: .miss),
        Scenario(name: "first set short is a miss", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [7, 8, 8, 8])]), expected: .miss),
        Scenario(name: "3 of 4 sets logged is a miss", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [8, 8, 8])]), expected: .miss),
        Scenario(name: "session with no sets is a miss", sessionsPerWeek: 1,
                 week: .logged([SessionResult(reps: [])]), expected: .miss),
        Scenario(name: "nothing logged yet is in progress", sessionsPerWeek: 1,
                 week: .logged([]), expected: .inProgress),
        Scenario(name: "skipped", sessionsPerWeek: 1,
                 week: .skipped, expected: .skipped),
        Scenario(name: "2x/week, both sessions hit", sessionsPerWeek: 2,
                 week: .logged([SessionResult(reps: [8, 8, 8, 8]), SessionResult(reps: [8, 8, 8, 8])]),
                 expected: .hit),
        Scenario(name: "2x/week, second session misses", sessionsPerWeek: 2,
                 week: .logged([SessionResult(reps: [8, 8, 8, 8]), SessionResult(reps: [8, 8, 7, 8])]),
                 expected: .miss),
        Scenario(name: "2x/week, only one session logged", sessionsPerWeek: 2,
                 week: .logged([SessionResult(reps: [8, 8, 8, 8])]), expected: .inProgress),
        Scenario(name: "2x/week, one missed session logged is still in progress", sessionsPerWeek: 2,
                 week: .logged([SessionResult(reps: [8, 8, 8, 7])]), expected: .inProgress),
    ]

    @Test(arguments: scenarios)
    func outcome(_ scenario: Scenario) {
        let target = fourByEight(sessionsPerWeek: scenario.sessionsPerWeek)
        #expect(ThreeWeekBlockRule().outcome(of: scenario.week, target: target) == scenario.expected)
    }
}
