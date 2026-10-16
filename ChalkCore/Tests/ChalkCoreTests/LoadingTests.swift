import ChalkCore
import Testing

@Suite("Plate and dumbbell rounding")
struct LoadingTests {
    struct RoundingCase: Sendable, CustomTestStringConvertible {
        let input: Weight
        let up: Weight
        let down: Weight?
        var testDescription: String { "\(input)" }
    }

    // MARK: Barbell

    @Test(arguments: [
        RoundingCase(input: lb(135), up: lb(135), down: lb(135)),
        RoundingCase(input: lb(136), up: lb(137.5), down: lb(135)),
        RoundingCase(input: lb(137.5), up: lb(137.5), down: lb(137.5)),
        RoundingCase(input: lb(46), up: lb(47.5), down: lb(45)),
        RoundingCase(input: lb(45), up: lb(45), down: lb(45)),
        RoundingCase(input: lb(44), up: lb(45), down: nil),
        RoundingCase(input: lb(0), up: lb(45), down: nil),
        RoundingCase(input: lb(405), up: lb(405), down: lb(405)),
        RoundingCase(input: lb(406), up: lb(407.5), down: lb(405)),
    ])
    func poundPlates(_ c: RoundingCase) {
        #expect(PlateSet.standardPounds.roundedUp(c.input) == c.up)
        #expect(PlateSet.standardPounds.roundedDown(c.input) == c.down)
    }

    @Test(arguments: [
        RoundingCase(input: kg(60), up: kg(60), down: kg(60)),
        RoundingCase(input: kg(61.25), up: kg(61.5), down: kg(61)),
        RoundingCase(input: kg(20.1), up: kg(20.5), down: kg(20)),
        RoundingCase(input: kg(20), up: kg(20), down: kg(20)),
        RoundingCase(input: kg(10), up: kg(20), down: nil),
        RoundingCase(input: kg(142.75), up: kg(143), down: kg(142.5)),
    ])
    func kilogramPlates(_ c: RoundingCase) {
        #expect(PlateSet.standardKilograms.roundedUp(c.input) == c.up)
        #expect(PlateSet.standardKilograms.roundedDown(c.input) == c.down)
    }

    /// Plates that don't divide each other: per-side loads of 0, 3, 5, 6, 8, 9, 10, …
    /// are reachable, but 1, 2, 4, and 7 aren't.
    @Test(arguments: [
        RoundingCase(input: kg(22), up: kg(26), down: kg(20)),
        RoundingCase(input: kg(26), up: kg(26), down: kg(26)),
        RoundingCase(input: kg(28), up: kg(30), down: kg(26)),
        RoundingCase(input: kg(34), up: kg(36), down: kg(32)),
        RoundingCase(input: kg(40), up: kg(40), down: kg(40)),
    ])
    func oddPlateSizes(_ c: RoundingCase) {
        let plates = PlateSet(bar: kg(20), plates: [kg(5), kg(3)])
        #expect(plates.roundedUp(c.input) == c.up)
        #expect(plates.roundedDown(c.input) == c.down)
    }

    // MARK: Dumbbells

    @Test(arguments: [
        RoundingCase(input: lb(17), up: lb(17.5), down: lb(15)),
        RoundingCase(input: lb(17.5), up: lb(17.5), down: lb(17.5)),
        RoundingCase(input: lb(19), up: lb(20), down: lb(17.5)),
        RoundingCase(input: lb(20), up: lb(20), down: lb(20)),
        RoundingCase(input: lb(21), up: lb(25), down: lb(20)),
        RoundingCase(input: lb(22.5), up: lb(25), down: lb(20)),
        RoundingCase(input: lb(52), up: lb(55), down: lb(50)),
        RoundingCase(input: lb(2), up: lb(2.5), down: nil),
    ])
    func poundDumbbells(_ c: RoundingCase) {
        #expect(DumbbellSet.standardPounds.roundedUp(c.input) == c.up)
        #expect(DumbbellSet.standardPounds.roundedDown(c.input) == c.down)
    }

    @Test(arguments: [
        RoundingCase(input: kg(7.5), up: kg(8), down: kg(7)),
        RoundingCase(input: kg(9.5), up: kg(10), down: kg(9)),
        RoundingCase(input: kg(10.5), up: kg(12.5), down: kg(10)),
        RoundingCase(input: kg(14), up: kg(15), down: kg(12.5)),
        RoundingCase(input: kg(0.5), up: kg(1), down: nil),
    ])
    func kilogramDumbbells(_ c: RoundingCase) {
        #expect(DumbbellSet.standardKilograms.roundedUp(c.input) == c.up)
        #expect(DumbbellSet.standardKilograms.roundedDown(c.input) == c.down)
    }

    // MARK: Formatting

    @Test(arguments: [
        (lb(185), "185", "185 lb"),
        (lb(137.5), "137.5", "137.5 lb"),
        (kg(61.25), "61.25", "61.25 kg"),
        (kg(0), "0", "0 kg"),
    ])
    func formatting(weight: Weight, value: String, description: String) {
        #expect(weight.formattedValue == value)
        #expect(weight.description == description)
    }

    // MARK: Increase and deload guarantees

    struct StepCase: Sendable, CustomTestStringConvertible {
        let equipment: Equipment
        let start: Weight
        var testDescription: String { "\(equipment) \(start)" }
    }

    static let stepCases: [StepCase] = [
        StepCase(equipment: .barbell, start: lb(45)),
        StepCase(equipment: .barbell, start: lb(135)),
        StepCase(equipment: .barbell, start: kg(20)),
        StepCase(equipment: .barbell, start: kg(60)),
        StepCase(equipment: .dumbbell, start: lb(2.5)),
        StepCase(equipment: .dumbbell, start: lb(20)),
        StepCase(equipment: .dumbbell, start: kg(1)),
        StepCase(equipment: .dumbbell, start: kg(10)),
        StepCase(equipment: .machine, start: lb(47.5)),
        StepCase(equipment: .machine, start: kg(31.25)),
    ]

    @Test(arguments: stepCases)
    func zeroIncrementStillMovesUp(_ c: StepCase) {
        let ladder = LoadingSettings.standard(for: c.start.unit).ladder(for: c.equipment)
        let next = ladder.increased(c.start, by: Weight(0, c.start.unit))
        #expect(next - c.start >= ladder.minimumIncrease(from: c.start))
        #expect(ladder.roundedUp(next) == next)
    }

    struct MinimumCase: Sendable, CustomTestStringConvertible {
        let equipment: Equipment
        let from: Weight
        let minimum: Weight
        var testDescription: String { "\(equipment) from \(from)" }
    }

    // 5 lb / 2.5 kg everywhere, except dumbbells below 20 lb (and below 10 kg).
    @Test(arguments: [
        MinimumCase(equipment: .barbell, from: lb(45), minimum: lb(5)),
        MinimumCase(equipment: .barbell, from: lb(315), minimum: lb(5)),
        MinimumCase(equipment: .barbell, from: kg(60), minimum: kg(2.5)),
        MinimumCase(equipment: .machine, from: lb(120), minimum: lb(5)),
        MinimumCase(equipment: .machine, from: kg(30), minimum: kg(2.5)),
        MinimumCase(equipment: .dumbbell, from: lb(2.5), minimum: lb(2.5)),
        MinimumCase(equipment: .dumbbell, from: lb(17.5), minimum: lb(2.5)),
        MinimumCase(equipment: .dumbbell, from: lb(20), minimum: lb(5)),
        MinimumCase(equipment: .dumbbell, from: lb(60), minimum: lb(5)),
        MinimumCase(equipment: .dumbbell, from: kg(8), minimum: kg(1)),
        MinimumCase(equipment: .dumbbell, from: kg(12.5), minimum: kg(2.5)),
    ])
    func minimumIncrease(_ c: MinimumCase) {
        let ladder = LoadingSettings.standard(for: c.from.unit).ladder(for: c.equipment)
        #expect(ladder.minimumIncrease(from: c.from) == c.minimum)
    }

    @Test(arguments: stepCases)
    func deloadNeverIncreases(_ c: StepCase) {
        let ladder = LoadingSettings.standard(for: c.start.unit).ladder(for: c.equipment)
        let lighter = ladder.deloaded(c.start, by: 0.10)
        #expect(lighter <= c.start)
        #expect(lighter >= ladder.minimum)
        #expect(ladder.roundedUp(lighter) == lighter)
    }
}
