//
//  OnboardingTests.swift
//  ChalkTests
//

import ChalkCore
import Foundation
import SwiftData
import Testing
@testable import Chalk

@Suite("Program templates")
struct ProgramTemplateTests {
    @Test(arguments: ProgramTemplate.all)
    func everyLiftIsInTheCatalog(_ template: ProgramTemplate) {
        for lift in template.lifts {
            #expect(lift.catalogEntry != nil, "\(lift.name) in \(template.name) isn't in the catalog")
        }
    }

    @Test(arguments: ProgramTemplate.all)
    func liftNamesAreUniqueWithinATemplate(_ template: ProgramTemplate) {
        let names = template.lifts.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func templatesMatchTheAgreedPrograms() {
        #expect(ProgramTemplate.pushPullLegs.days.map(\.name) == ["Push", "Pull", "Legs"])
        #expect(ProgramTemplate.pushPullLegs.days[0].lifts.map(\.name).contains("DB Lateral Raise"))
        #expect(ProgramTemplate.pushPullLegs.days[1].lifts.map(\.name) == ["Barbell Row", "Lat Pulldown", "Face Pull", "DB Curl"])
        #expect(ProgramTemplate.upperLower.days.map(\.name) == ["Upper A", "Lower A", "Upper B", "Lower B"])
        #expect(ProgramTemplate.fullBody.days[2].lifts.first == TemplateLift("Goblet Squat", 3, 10))
    }

    @Test func faceAndLateralRaiseHaveTheRightEquipment() {
        #expect(ExerciseCatalog.named("Face Pull")?.equipment == .machine)
        #expect(ExerciseCatalog.named("Face Pull")?.bodyRegion == .upper)
        #expect(ExerciseCatalog.named("DB Lateral Raise")?.equipment == .dumbbell)
    }

    @Test(arguments: [
        (Equipment.barbell, WeightUnit.pounds, Weight.pounds(45)),
        (.dumbbell, .pounds, .pounds(2.5)),
        (.machine, .pounds, .pounds(20)),
        (.barbell, .kilograms, .kilograms(20)),
        (.dumbbell, .kilograms, .kilograms(1)),
        (.machine, .kilograms, .kilograms(10)),
    ])
    func startLightFillsTheLightestValidWeight(equipment: Equipment, unit: WeightUnit, expected: Weight) {
        #expect(StartingWeights.lightest(for: equipment, unit: unit) == expected)
    }

    @Test func resolvingSkipsBlanksAndSnaps() {
        let lifts = ProgramTemplate.fullBody.days[0].lifts  // Back Squat, Bench Press, Barbell Row
        let weights = StartingWeights.resolve(
            ["Back Squat": "136", "Bench Press": "", "Barbell Row": "abc"],
            for: lifts,
            unit: .pounds
        )
        #expect(weights == ["Back Squat": .pounds(135)])
    }
}

@MainActor
@Suite("Building programs from templates")
struct TemplateBuildTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
    }

    func allWeights(_ template: ProgramTemplate, _ weight: Double, unit: WeightUnit = .pounds) -> [String: Weight] {
        Dictionary(uniqueKeysWithValues: template.lifts.map { ($0.name, Weight(weight, unit)) })
    }

    @Test(arguments: ProgramTemplate.all)
    func buildsDaysAndExercisesInOrder(_ template: ProgramTemplate) throws {
        let program = try template.makeProgram(unit: .pounds, startingWeights: allWeights(template, 100), in: context)

        #expect(program.name == template.name)
        #expect(program.unit == .pounds)
        #expect(program.sortedDays.map(\.name) == template.days.map(\.name))
        for (day, templateDay) in zip(program.sortedDays, template.days) {
            let slots = day.sortedEntries.compactMap(\.slot)
            #expect(slots.map(\.name) == templateDay.lifts.map(\.name))
            #expect(slots.map(\.targetSets) == templateDay.lifts.map(\.sets))
            #expect(slots.map(\.targetReps) == templateDay.lifts.map(\.reps))
            #expect(slots.map(\.equipment) == templateDay.lifts.map(\.equipment))
        }
        #expect(program.nextWorkout()?.day == program.sortedDays.first)
    }

    @Test func startingWeightsAreSnappedAndIncrementsDefaulted() throws {
        var weights = allWeights(.fullBody, 100)
        weights["Back Squat"] = .pounds(137)  // barbell: nearest loadable is 137.5
        weights["Incline DB Press"] = .pounds(22)  // dumbbell: nearest is 20

        let program = try ProgramTemplate.fullBody.makeProgram(unit: .pounds, startingWeights: weights, in: context)
        let slots = Dictionary(uniqueKeysWithValues: program.activeSlots.map { ($0.name, $0) })

        #expect(slots["Back Squat"]?.startingWeight == .pounds(137.5))
        #expect(slots["Incline DB Press"]?.startingWeight == .pounds(20))
        #expect(slots["Back Squat"]?.increment == .pounds(5))
        #expect(slots["Bench Press"]?.increment == .pounds(2.5))
    }

    @Test func kilogramProgramsUseKilograms() throws {
        let program = try ProgramTemplate.pushPullLegs.makeProgram(
            unit: .kilograms,
            startingWeights: allWeights(.pushPullLegs, 40, unit: .kilograms),
            in: context
        )
        #expect(program.unit == .kilograms)
        #expect(program.activeSlots.allSatisfy { $0.startingWeight.unit == .kilograms })
    }

    @Test func aMissingStartingWeightIsRejected() throws {
        var weights = allWeights(.fullBody, 100)
        weights["Deadlift"] = nil

        #expect(throws: TemplateError.missingStartingWeight("Deadlift")) {
            try ProgramTemplate.fullBody.makeProgram(unit: .pounds, startingWeights: weights, in: context)
        }
        #expect(ProgramLibrary.activePrograms(in: context).isEmpty, "Nothing is created")
    }

    @Test func aCustomNameAndArchivingTheActiveProgram() throws {
        let old = ProgramLibrary.createProgram(named: "Old", unit: .pounds, in: context)
        let new = try ProgramTemplate.upperLower.makeProgram(
            named: "My Split",
            unit: .pounds,
            startingWeights: allWeights(.upperLower, 100),
            in: context
        )
        #expect(new.name == "My Split")
        #expect(old.isArchived)
        #expect(ProgramLibrary.activePrograms(in: context) == [new])
    }
}

@Suite("Onboarding gate")
struct OnboardingGateTests {
    @Test(arguments: [
        (0, false, true),
        (0, true, false),
        (1, false, false),
        (2, true, false),
    ])
    func showsOnlyOnAFirstLaunchWithNoPrograms(count: Int, hasSeen: Bool, shows: Bool) {
        #expect(OnboardingGate.shouldShow(programCount: count, hasSeenOnboarding: hasSeen) == shows)
    }

    @Test(arguments: [
        (false, true, false, true),   // programs synced in mid-onboarding
        (false, true, true, false),   // onboarding itself created the program
        (true, true, false, false),   // already had programs
        (false, false, false, false), // still nothing
    ])
    func welcomeBackOnlyWhenProgramsArriveMidOnboarding(had: Bool, has: Bool, hasSeen: Bool, welcome: Bool) {
        #expect(OnboardingGate.isWelcomeBack(hadPrograms: had, hasPrograms: has, hasSeenOnboarding: hasSeen) == welcome)
    }
}
