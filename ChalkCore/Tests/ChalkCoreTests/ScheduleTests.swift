import ChalkCore
import Testing

@Suite("Schedule")
struct ScheduleTests {
    struct Scenario: Sendable, CustomTestStringConvertible {
        let name: String
        let dayCount: Int
        let finished: [ScheduledWorkout]
        let next: ScheduledWorkout?
        var testDescription: String { name }
    }

    static func w(_ week: Int, _ day: Int) -> ScheduledWorkout { ScheduledWorkout(week: week, day: day) }

    // 3-day program unless noted. Finished = completed or skipped.
    static let scenarios: [Scenario] = [
        Scenario(name: "fresh program starts at week 1, day 1", dayCount: 3,
                 finished: [], next: w(1, 0)),
        Scenario(name: "after day 1", dayCount: 3,
                 finished: [w(1, 0)], next: w(1, 1)),
        Scenario(name: "after days 1 and 2", dayCount: 3,
                 finished: [w(1, 0), w(1, 1)], next: w(1, 2)),
        Scenario(name: "finishing the last day starts the next week", dayCount: 3,
                 finished: [w(1, 0), w(1, 1), w(1, 2)], next: w(2, 0)),
        Scenario(name: "skipped day mid-week counts as finished", dayCount: 3,
                 finished: [w(1, 0), w(1, 1)], next: w(1, 2)),
        Scenario(name: "a missed day stays next", dayCount: 3,
                 finished: [w(1, 1), w(1, 2)], next: w(1, 0)),
        Scenario(name: "a gap in an earlier week comes first", dayCount: 3,
                 finished: [w(1, 0), w(1, 2), w(2, 0)], next: w(1, 1)),
        Scenario(name: "skipped week moves on", dayCount: 2,
                 finished: [w(1, 0), w(1, 1), w(2, 0), w(2, 1)], next: w(3, 0)),
        Scenario(name: "no days", dayCount: 0,
                 finished: [], next: nil),
    ]

    @Test(arguments: scenarios)
    func nextWorkout(_ scenario: Scenario) {
        let next = Schedule.nextWorkout(dayCount: scenario.dayCount, finished: Set(scenario.finished))
        #expect(next == scenario.next)
    }

    static let remainingCases: [([ScheduledWorkout], [ScheduledWorkout])] = [
        ([], [w(1, 0), w(1, 1), w(1, 2)]),
        ([w(1, 0)], [w(1, 1), w(1, 2)]),
        ([w(1, 0), w(1, 2)], [w(1, 1)]),
        ([w(1, 0), w(1, 1), w(1, 2)], []),
        ([w(2, 0)], [w(1, 0), w(1, 1), w(1, 2)]),
    ]

    @Test(arguments: remainingCases)
    func remainingDaysOfWeek1(finished: [ScheduledWorkout], expected: [ScheduledWorkout]) {
        #expect(Schedule.remainingDays(inWeek: 1, dayCount: 3, finished: Set(finished)) == expected)
    }
}
