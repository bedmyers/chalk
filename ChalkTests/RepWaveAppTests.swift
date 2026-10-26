//
//  RepWaveAppTests.swift
//  ChalkTests
//

import ChalkCore
import Foundation
import SwiftData
import Testing
@testable import Chalk

@Suite("Rep wave storage")
struct RepWaveStorageTests {
    @Test(arguments: [
        ([6, 8, 10], "6,8,10"),
        ([12], "12"),
        ([], ""),
    ])
    func roundTrips(reps: [Int], raw: String) {
        #expect(RepWave.raw(reps) == raw)
        #expect(RepWave.parse(raw) == reps)
    }

    @Test(arguments: ["6,x,10", "6,0,10", "-1"])
    func unreadableMeansNoWave(raw: String) {
        #expect(RepWave.parse(raw).isEmpty)
    }

    @Test func text() {
        #expect(RepWave.text(reps: 8, repsByWeek: []) == "8")
        #expect(RepWave.text(reps: 6, repsByWeek: [6, 8, 10]) == "6/8/10")
    }

    @Test func changingTheWaveRestartsTheBlock() {
        var original = ExerciseSpec.new(unit: .pounds)
        original.repsByWeek = [6, 8, 10]
        var edited = original
        edited.repsByWeek = [6, 8, 12]
        #expect(edited.restartsBlock(comparedTo: original))
        #expect(!original.restartsBlock(comparedTo: original))
    }
}

@MainActor
@Suite("Rep waves in the app")
struct RepWaveAppTests {
    let container: ModelContainer
    let context: ModelContext
    let program: Program
    let day: ProgramDay

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
        program = ProgramLibrary.createProgram(named: "Test", unit: .pounds, in: context)
        day = program.addDay(named: "Push A", in: context)
    }

    @discardableResult
    func addBench() -> ExerciseSlot {
        var spec = ExerciseSpec.new(unit: .pounds)
        spec.name = "Bench Press"
        spec.bodyRegion = .upper
        spec.targetSets = 4
        spec.targetReps = 6
        spec.repsByWeek = [6, 8, 10]
        spec.increment = .pounds(5)
        spec.weight = .pounds(185)
        return program.addExercise(spec, to: day, in: context)
    }

    @discardableResult
    func addPullUps(sets: Int = 4, wave: [Int] = [6, 8, 10]) -> ExerciseSlot {
        var spec = ExerciseSpec.new(unit: .pounds)
        spec.name = "Pull-Up"
        spec.equipment = .bodyweight
        spec.bodyRegion = .upper
        spec.targetSets = sets
        spec.targetReps = wave[0]
        spec.repsByWeek = wave
        spec.weight = .pounds(0)
        return program.addExercise(spec, to: day, in: context)
    }

    /// Logs the day for `week`, every set at its target unless `short`.
    @discardableResult
    func finishWeek(_ week: Int, short: Bool = false) -> [WeightBump] {
        let session = program.startSession(for: day, week: week, in: context)
        for log in session.sortedExerciseLogs {
            for _ in 0..<log.targetSets {
                log.logSet(reps: short ? log.targetReps - 1 : log.targetReps, in: context)
            }
        }
        return session.completeAndCollectBumps()
    }

    @Test func slotStoresTheWave() {
        let bench = addBench()
        #expect(bench.repsByWeek == [6, 8, 10])
        #expect(bench.repsByWeekRaw == "6,8,10")
        #expect(bench.targetReps == 6)
        #expect(bench.targetText(extraReps: 0) == "4 × 6/8/10")
    }

    @Test func todayShowsEachWeeksReps() {
        addBench()
        #expect(TodayPlan(program: program, day: day, week: 1).exercises.first?.targetReps == 6)
        finishWeek(1)
        #expect(TodayPlan(program: program, day: day, week: 2).exercises.first?.targetReps == 8)
        finishWeek(2)
        #expect(TodayPlan(program: program, day: day, week: 3).exercises.first?.targetReps == 10)
    }

    @Test func eachWorkoutRecordsThatWeeksReps() throws {
        addBench()
        finishWeek(1)
        finishWeek(2)
        let session = program.startSession(for: day, week: 3, in: context)
        let log = try #require(session.sortedExerciseLogs.first)
        #expect(log.targetReps == 10)
        #expect(log.prescribedWeight == .pounds(185))
    }

    @Test func passingTheWaveBumpsTheWeightAndStartsOver() {
        let bench = addBench()
        #expect(finishWeek(1).isEmpty)
        #expect(finishWeek(2).isEmpty)
        #expect(finishWeek(3) == [WeightBump(exerciseName: "Bench Press", from: .pounds(185), to: .pounds(190))])
        #expect(bench.progression().nextReps == 6)
        #expect(TodayPlan(program: program, day: day, week: 4).exercises.first?.targetReps == 6)
    }

    @Test func aMissedWeekMovesOnButHoldsTheWeight() {
        let bench = addBench()
        finishWeek(1)
        finishWeek(2, short: true)
        #expect(bench.progression().nextReps == 10)
        #expect(finishWeek(3).isEmpty)
        #expect(bench.progression().nextWeight == .pounds(185))
        #expect(bench.progression().nextReps == 6)
    }

    @Test func bodyweightBumpRaisesTheWave() {
        let pullUps = addPullUps()
        finishWeek(1)
        finishWeek(2)
        let bumps = finishWeek(3)
        #expect(bumps == [WeightBump(exerciseName: "Pull-Up", change: .reps(from: "6/8/10", to: "7/9/11"))])
        #expect(pullUps.progression().nextReps == 7)
        #expect(pullUps.targetText(extraReps: pullUps.progression().extraReps) == "4 × 7/9/11")
    }

    @Test func editingABodyweightLiftKeepsTheRepsItEarned() {
        let pullUps = addPullUps()
        finishWeek(1)
        finishWeek(2)
        finishWeek(3)

        var edited = pullUps.spec
        #expect(edited.repsByWeek == [7, 9, 11])
        #expect(edited.targetReps == 7)
        edited.targetSets = 3
        let successor = pullUps.save(edited, in: context)

        #expect(successor !== pullUps)
        #expect(successor.repsByWeek == [7, 9, 11])
        #expect(successor.progression().nextReps == 7)
        #expect(successor.progression().extraReps == 0)
    }

    @Test func renamingABodyweightLiftDoesntRestart() {
        let pullUps = addPullUps()
        finishWeek(1)
        finishWeek(2)
        finishWeek(3)

        var edited = pullUps.spec
        edited.name = "Wide Pull-Up"
        #expect(pullUps.save(edited, in: context) === pullUps)
        #expect(pullUps.progression().extraReps == 1)
    }

    @Test func editingAWorkoutPreviewsBodyweightRepChanges() throws {
        addPullUps()
        finishWeek(1)
        finishWeek(2)
        finishWeek(3)
        let week3 = try #require(program.sessions?.first { $0.weekNumber == 3 })

        var draft = week3.draft
        draft.exercises[0].sets[3].reps = 9
        #expect(week3.weightChanges(applying: draft).map(\.description) == ["Pull-Up 7/9/11 → 6/8/10 reps"])
    }

    @Test func catalogHasBodyweightLifts() {
        #expect(ExerciseCatalog.withID("pull-up")?.equipment == .bodyweight)
        #expect(ExerciseCatalog.withID("dip")?.equipment == .bodyweight)
    }

    @Test(arguments: [
        (Equipment.barbell, "185 lb"),
        (.bodyweight, "BW"),
    ])
    func weightLabels(equipment: Equipment, expected: String) {
        #expect(WeightLabel.text(.pounds(185), equipment: equipment) == expected)
    }
}
