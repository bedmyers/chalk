import ChalkCore
import Testing

@Suite("Auto-deload")
struct DeloadTests {
    struct Scenario: Sendable, CustomTestStringConvertible {
        let name: String
        let start: Weight
        let equipment: Equipment
        let history: [WeekResult]
        let weight: Weight
        let events: [ProgressionEvent]
        var testDescription: String { name }
    }

    static let scenarios: [Scenario] = [
        Scenario(name: "one failed block holds", start: lb(200), equipment: .barbell,
                 history: failedBlock,
                 weight: lb(200), events: [.held(lb(200))]),
        Scenario(name: "two failed blocks deload 10%", start: lb(200), equipment: .barbell,
                 history: failedBlock + failedBlock,
                 weight: lb(180), events: [.held(lb(200)), .deloaded(from: lb(200), to: lb(180))]),
        Scenario(name: "skips between failed blocks are still consecutive", start: lb(200),
                 equipment: .barbell,
                 history: failedBlock + [skip, skip] + failedBlock,
                 weight: lb(180), events: [.held(lb(200)), .deloaded(from: lb(200), to: lb(180))]),
        Scenario(name: "a passed block resets the failure count", start: lb(200), equipment: .barbell,
                 history: failedBlock + passedBlock + failedBlock,
                 weight: lb(205), events: [
                     .held(lb(200)),
                     .increased(from: lb(200), to: lb(205)),
                     .held(lb(205)),
                 ]),
        Scenario(name: "third failed block after a deload only holds", start: lb(200),
                 equipment: .barbell,
                 history: failedBlock + failedBlock + failedBlock,
                 weight: lb(180), events: [
                     .held(lb(200)),
                     .deloaded(from: lb(200), to: lb(180)),
                     .held(lb(180)),
                 ]),
        Scenario(name: "four failed blocks deload twice", start: lb(200), equipment: .barbell,
                 history: failedBlock + failedBlock + failedBlock + failedBlock,
                 // 180 × 0.9 = 162 → nearest loadable is 162.5.
                 weight: lb(162.5), events: [
                     .held(lb(200)),
                     .deloaded(from: lb(200), to: lb(180)),
                     .held(lb(180)),
                     .deloaded(from: lb(180), to: lb(162.5)),
                 ]),
        Scenario(name: "progression resumes from the deloaded weight", start: lb(200),
                 equipment: .barbell,
                 history: failedBlock + failedBlock + passedBlock,
                 weight: lb(185), events: [
                     .held(lb(200)),
                     .deloaded(from: lb(200), to: lb(180)),
                     .increased(from: lb(180), to: lb(185)),
                 ]),
        Scenario(name: "kg barbell deload", start: kg(100), equipment: .barbell,
                 history: failedBlock + failedBlock,
                 weight: kg(90), events: [.held(kg(100)), .deloaded(from: kg(100), to: kg(90))]),
        Scenario(name: "empty bar can't deload", start: lb(45), equipment: .barbell,
                 history: failedBlock + failedBlock,
                 weight: lb(45), events: [.held(lb(45)), .held(lb(45))]),
        Scenario(name: "small deload still drops at least one plate step", start: lb(50),
                 equipment: .barbell,
                 history: failedBlock + failedBlock,
                 // 50 × 0.9 = 45 → the bar.
                 weight: lb(45), events: [.held(lb(50)), .deloaded(from: lb(50), to: lb(45))]),
        Scenario(name: "dumbbell deload rounds to the nearest dumbbell", start: lb(30),
                 equipment: .dumbbell,
                 history: failedBlock + failedBlock,
                 // 30 × 0.9 = 27 → 25 is nearer than 30.
                 weight: lb(25), events: [.held(lb(30)), .deloaded(from: lb(30), to: lb(25))]),
        Scenario(name: "light dumbbell deload drops one step", start: lb(10), equipment: .dumbbell,
                 history: failedBlock + failedBlock,
                 // 10 × 0.9 = 9 → nearest is 10, which isn't lighter, so drop to 7.5.
                 weight: lb(7.5), events: [.held(lb(10)), .deloaded(from: lb(10), to: lb(7.5))]),
        Scenario(name: "machine deload is an unrounded 10%", start: lb(47.5), equipment: .machine,
                 history: failedBlock + failedBlock,
                 weight: lb(42.75), events: [.held(lb(47.5)), .deloaded(from: lb(47.5), to: lb(42.75))]),
        Scenario(name: "kg machine deload", start: kg(100), equipment: .machine,
                 history: failedBlock + failedBlock,
                 weight: kg(90), events: [.held(kg(100)), .deloaded(from: kg(100), to: kg(90))]),
        Scenario(name: "lightest dumbbell can't deload", start: lb(2.5), equipment: .dumbbell,
                 history: failedBlock + failedBlock,
                 weight: lb(2.5), events: [.held(lb(2.5)), .held(lb(2.5))]),
    ]

    @Test(arguments: scenarios)
    func deload(_ scenario: Scenario) {
        let increment = scenario.start.unit == .pounds ? lb(5) : kg(2.5)
        let outcome = evaluate(
            start: scenario.start,
            target: fourByEight(increment: increment, equipment: scenario.equipment),
            history: scenario.history
        )
        #expect(outcome.nextWeight == scenario.weight)
        #expect(outcome.events == scenario.events)
    }

    @Test func deloadThresholdIsConfigurable() {
        let rule = ThreeWeekBlockRule(failedBlocksBeforeDeload: 3)
        let replay = rule.replay(ProgressionInput(
            startingWeight: lb(200),
            target: fourByEight(),
            history: failedBlock + failedBlock,
            loading: .standard(for: .pounds)
        ))
        #expect(replay.weight == lb(200))
        #expect(replay.consecutiveFailedBlocks == 2)
    }
}
