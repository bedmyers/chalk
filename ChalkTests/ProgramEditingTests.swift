//
//  ProgramEditingTests.swift
//  ChalkTests
//

import ChalkCore
import Foundation
import SwiftData
import Testing
@testable import Chalk

// MARK: - Value types

@Suite("Exercise spec")
struct ExerciseSpecTests {
    static let base = ExerciseSpec(
        name: "Bench Press",
        equipment: .barbell,
        bodyRegion: .upper,
        targetSets: 4,
        targetReps: 8,
        increment: .pounds(5),
        weight: .pounds(185)
    )

    struct EditCase: Sendable, CustomTestStringConvertible {
        let name: String
        let edit: @Sendable (inout ExerciseSpec) -> Void
        let restarts: Bool
        var testDescription: String { name }
    }

    static let cases: [EditCase] = [
        EditCase(name: "no change", edit: { _ in }, restarts: false),
        EditCase(name: "rename", edit: { $0.name = "Flat Bench" }, restarts: false),
        EditCase(name: "body region", edit: { $0.bodyRegion = .lower }, restarts: false),
        EditCase(name: "sets", edit: { $0.targetSets = 3 }, restarts: true),
        EditCase(name: "reps", edit: { $0.targetReps = 10 }, restarts: true),
        EditCase(name: "increment", edit: { $0.increment = .pounds(10) }, restarts: true),
        EditCase(name: "equipment", edit: { $0.equipment = .dumbbell }, restarts: true),
        EditCase(name: "current weight", edit: { $0.weight = .pounds(200) }, restarts: true),
    ]

    @Test(arguments: cases)
    func restartsBlock(_ c: EditCase) {
        var edited = Self.base
        c.edit(&edited)
        #expect(edited.restartsBlock(comparedTo: Self.base) == c.restarts)
    }

    @Test(arguments: [
        ("135", WeightUnit.pounds, Weight.pounds(135)),
        ("137.5", .pounds, .pounds(137.5)),
        ("137,5", .pounds, .pounds(137.5)),
        (" 60 ", .kilograms, .kilograms(60)),
    ])
    func parsesWeights(text: String, unit: WeightUnit, expected: Weight) {
        #expect(WeightInput.parse(text, unit: unit) == expected)
    }

    @Test(arguments: ["", "abc", "1..5"])
    func rejectsNonNumbers(_ text: String) {
        #expect(WeightInput.parse(text, unit: .pounds) == nil)
    }
}

@Suite("Exercise catalog")
struct ExerciseCatalogTests {
    @Test func hasAboutTwentyLiftsAcrossEquipment() {
        let all = ExerciseCatalog.all
        #expect((20...25).contains(all.count))
        #expect(all.contains { $0.equipment == .barbell })
        #expect(all.contains { $0.equipment == .dumbbell })
        #expect(all.contains { $0.equipment == .machine })
        #expect(Set(all.map(\.name)).count == all.count, "Names must be unique")
    }

    @Test(arguments: [
        ("press", ["Bench Press", "Incline Bench Press", "Overhead Press", "DB Bench Press", "Incline DB Press"]),
        ("PULLDOWN", ["Lat Pulldown"]),
        ("", []),
        ("Lat Pulldown", []),  // exact match: suggestions get out of the way
        ("Zercher Squat", []),  // free text with no match is fine
    ])
    func suggestions(query: String, expected: [String]) {
        #expect(ExerciseCatalog.suggestions(for: query).map(\.name) == expected)
    }
}

// MARK: - Model operations

@MainActor
@Suite("Program editing")
struct ProgramEditingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
    }

    /// The sample Push / Pull / Legs program, the only active program.
    func makeProgram() throws -> (Program, [ProgramDay]) {
        let program = SampleData.insertProgram(into: context)
        try context.save()
        return (program, program.sortedDays)
    }

    func slot(named name: String, in program: Program) throws -> ExerciseSlot {
        try #require(program.activeSlots.first { $0.name == name })
    }

    // MARK: One active program

    @Test func creatingAProgramArchivesTheActiveOne() throws {
        let (old, _) = try makeProgram()
        let new = ProgramLibrary.createProgram(named: "5x5", unit: .kilograms, in: context)

        #expect(old.isArchived)
        #expect(!new.isArchived)
        #expect(new.unit == .kilograms)
        #expect(ProgramLibrary.activePrograms(in: context) == [new])
    }

    @Test func restoringAnArchivedProgramArchivesTheActiveOne() throws {
        let (old, _) = try makeProgram()
        let new = ProgramLibrary.createProgram(named: "5x5", unit: .pounds, in: context)

        old.restore(in: context)

        #expect(!old.isArchived)
        #expect(new.isArchived)
        #expect(ProgramLibrary.activePrograms(in: context) == [old])
    }

    @Test func archivedProgramsAreListedNewestFirst() throws {
        let (first, _) = try makeProgram()
        first.archivedAt = Date(timeIntervalSinceNow: -3600)
        let second = ProgramLibrary.createProgram(named: "5x5", unit: .pounds, in: context)
        second.archivedAt = Date.now

        #expect(ProgramLibrary.archivedPrograms(in: context) == [second, first])
        #expect(ProgramLibrary.activePrograms(in: context).isEmpty)
    }

    @Test func restoringWithNoActiveProgram() throws {
        let (program, _) = try makeProgram()
        program.archive()

        program.restore(in: context)

        #expect(ProgramLibrary.activePrograms(in: context) == [program])
        #expect(ProgramLibrary.archivedPrograms(in: context).isEmpty)
    }

    @Test func restoredProgramPicksUpWhereItLeftOff() throws {
        let (program, days) = try makeProgram()
        let bench = try slot(named: "Bench Press", in: program)
        for week in 1...3 {
            let session = program.startSession(for: days[0], week: week, in: context)
            for log in session.sortedExerciseLogs {
                for _ in 0..<log.targetSets { log.logSet(reps: log.targetReps, in: context) }
            }
            session.complete()
        }
        program.skip(days[1], week: 3, in: context)

        ProgramLibrary.createProgram(named: "5x5", unit: .pounds, in: context)
        program.restore(in: context)

        #expect(bench.progression().nextWeight == .pounds(190))
        #expect(program.nextWorkout()?.week == 1)
        #expect(program.nextWorkout()?.day == days[1])
        // Skipped days aren't counted as workouts.
        #expect(program.completedWorkoutCount == 3)
    }

    // MARK: Days

    @Test func addingAndReorderingDays() throws {
        let (program, _) = try makeProgram()
        let arms = program.addDay(named: "Arms", in: context)
        #expect(program.sortedDays.map(\.name) == ["Push Day", "Pull Day", "Leg Day", "Arms"])

        program.moveDays(fromOffsets: [3], toOffset: 0)
        #expect(program.sortedDays.map(\.name) == ["Arms", "Push Day", "Pull Day", "Leg Day"])
        #expect(program.sortedDays.map(\.order) == [0, 1, 2, 3])
        // Applies to the current week right away.
        #expect(program.nextWorkout()?.day == arms)
    }

    @Test func deletingADayWithAWorkoutInProgressIsBlocked() throws {
        let (program, days) = try makeProgram()
        program.startSession(for: days[0], week: 1, in: context)

        #expect(program.hasSessionInProgress(on: days[0]))
        #expect(throws: DayDeletionError.sessionInProgress) {
            try program.deleteDay(days[0], in: context)
        }
        #expect(program.sortedDays.count == 3)
    }

    @Test func deletingADayArchivesExercisesOnlyOnThatDay() throws {
        let (program, days) = try makeProgram()
        let squat = try slot(named: "Squat", in: program)
        let legPress = try slot(named: "Leg Press", in: program)
        // Share Squat onto Push Day, so deleting Leg Day leaves it on another day.
        days[0].add(squat, in: context)

        #expect(Set(program.exercisesOnlyOn(days[2]).map(\.name)) == ["Romanian Deadlift", "Leg Press"])

        let archived = try program.deleteDay(days[2], in: context)
        try context.save()

        #expect(Set(archived.map(\.name)) == ["Romanian Deadlift", "Leg Press"])
        #expect(legPress.isArchived)
        #expect(!squat.isArchived)
        #expect(squat.entries?.count == 1)
        #expect(program.sortedDays.map(\.name) == ["Push Day", "Pull Day"])
        #expect(program.sortedDays.map(\.order) == [0, 1])
    }

    @Test func deletingADayKeepsItsHistory() throws {
        let (program, days) = try makeProgram()
        program.startSession(for: days[2], week: 1, in: context).complete()
        try program.deleteDay(days[2], in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SetLog>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseLog>()) == 3)
    }

    // MARK: Day entries

    @Test func removingAnExerciseFromItsLastDayArchivesIt() throws {
        let (program, days) = try makeProgram()
        let entry = try #require(days[0].sortedEntries.first)
        let bench = try #require(entry.slot)

        #expect(days[0].removalArchivesExercise(entry))
        #expect(days[0].remove(entry, in: context) == bench)
        #expect(bench.isArchived)
        #expect(days[0].sortedEntries.map(\.order) == [0, 1])
        #expect(!program.activeSlots.contains(bench))
    }

    @Test func removingASharedExerciseFromOneDayKeepsIt() throws {
        let (program, days) = try makeProgram()
        let squat = try slot(named: "Squat", in: program)
        let shared = days[0].add(squat, in: context)

        #expect(!days[0].removalArchivesExercise(shared))
        #expect(days[0].remove(shared, in: context) == nil)
        #expect(!squat.isArchived)
        #expect(squat.entries?.count == 1)
    }

    @Test func addingAndReorderingExercises() throws {
        let (program, days) = try makeProgram()
        var spec = ExerciseSpec.new(unit: .pounds)
        spec.name = "  Dips  "
        spec.equipment = .machine
        let dips = program.addExercise(spec, to: days[0], in: context)

        #expect(dips.name == "Dips")
        #expect(days[0].sortedEntries.last?.slot == dips)

        days[0].moveEntries(fromOffsets: [3], toOffset: 0)
        #expect(days[0].sortedEntries.first?.slot == dips)
        #expect(days[0].sortedEntries.map(\.order) == [0, 1, 2, 3])
    }

    @Test func sharingAnExerciseOntoAnotherDayUsesOneWeight() throws {
        let (program, days) = try makeProgram()
        let squat = try slot(named: "Squat", in: program)
        days[0].add(squat, in: context)

        #expect(squat.sessionsPerWeek == 2)
        let pushSquat = days[0].sortedEntries.last?.slot
        #expect(pushSquat === squat)
    }

    // MARK: Saving exercise edits

    @Test func renamingEditsInPlace() throws {
        let (program, _) = try makeProgram()
        let bench = try slot(named: "Bench Press", in: program)
        var edited = bench.spec
        edited.name = "Flat Bench"
        edited.bodyRegion = .lower

        let saved = bench.save(edited, in: context)

        #expect(saved === bench)
        #expect(!bench.isArchived)
        #expect(bench.name == "Flat Bench")
        #expect(bench.bodyRegion == .lower)
    }

    @Test(arguments: [
        "sets", "increment", "equipment", "weight",
    ])
    func progressionEditsRestartWithASuccessor(field: String) throws {
        let (program, days) = try makeProgram()
        let bench = try slot(named: "Bench Press", in: program)
        var edited = bench.spec
        switch field {
        case "sets": edited.targetSets = 3
        case "increment": edited.increment = .pounds(10)
        case "equipment": edited.equipment = .machine
        default: edited.weight = .pounds(200)
        }

        let successor = bench.save(edited, in: context)

        #expect(successor !== bench)
        #expect(bench.isArchived)
        #expect(successor.lineageID == bench.lineageID)
        #expect(successor.startingWeight == edited.weight)
        #expect(successor.progression().cycle?.week == 1)
        #expect(days[0].sortedEntries.first?.slot === successor)
    }

    @Test func editingTheCurrentWeightStartsFromTheTypedWeight() throws {
        let (program, days) = try makeProgram()
        let bench = try slot(named: "Bench Press", in: program)
        // Pass a block so the current weight is 190.
        for week in 1...3 {
            let session = program.startSession(for: days[0], week: week, in: context)
            for log in session.sortedExerciseLogs {
                for _ in 0..<log.targetSets { log.logSet(reps: log.targetReps, in: context) }
            }
            session.complete()
        }
        #expect(bench.spec.weight == .pounds(190))

        var edited = bench.spec
        edited.weight = .pounds(175)
        let successor = bench.save(edited, in: context)

        #expect(successor.progression().nextWeight == .pounds(175))
        // History stays on the archived slot.
        #expect(bench.progression().nextWeight == .pounds(190))
    }
}
