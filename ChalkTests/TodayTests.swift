//
//  TodayTests.swift
//  ChalkTests
//

import ChalkCore
import SwiftData
import Testing
@testable import Chalk

@MainActor
@Suite("Theme fonts")
struct ThemeFontTests {
    @Test(arguments: FontName.allCases)
    func bundledFontLoadsByPostScriptName(_ font: FontName) {
        #expect(!FontName.missing.contains(font), "\(font.rawValue) didn't load; check UIAppFonts and the file name")
    }
}

@Suite("Set tap")
struct SetTapTests {
    @Test(arguments: [
        (8, 8, 7),
        (7, 8, 6),
        (1, 8, 0),
        (0, 8, 8),
        (10, 8, 9),
    ])
    func tapCountsDownThenWraps(current: Int, target: Int, expected: Int) {
        #expect(SetTap.reps(afterTapping: current, target: target) == expected)
    }
}

@MainActor
@Suite("Weight bumps")
struct WeightBumpTests {
    let container: ModelContainer
    let context: ModelContext
    let program: Program
    let pushDay: ProgramDay

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
        program = SampleData.insertProgram(into: context)
        pushDay = try #require(program.sortedDays.first)
    }

    /// Logs Push Day for `week`. Every set hits unless its exercise is in `misses`.
    /// Finishes with `completeAndCollectBumps` and returns what it earned.
    @discardableResult
    func finishPushDay(week: Int, misses: Set<String> = []) -> [WeightBump] {
        let session = program.startSession(for: pushDay, week: week, in: context)
        for log in session.sortedExerciseLogs {
            for index in 0..<log.targetSets {
                let short = misses.contains(log.exerciseName) && index == log.targetSets - 1
                log.logSet(reps: short ? log.targetReps - 1 : log.targetReps, in: context)
            }
        }
        return session.completeAndCollectBumps()
    }

    @Test func weeksBeforeTheBlockClosesEarnNothing() {
        #expect(finishPushDay(week: 1).isEmpty)
        #expect(finishPushDay(week: 2).isEmpty)
    }

    @Test func closingAPassedBlockEarnsABumpPerExercise() {
        finishPushDay(week: 1)
        finishPushDay(week: 2)
        let bumps = finishPushDay(week: 3)

        // Upper-body increments are +2.5 lb, but every bump here is raised to the
        // 5 lb minimum (barbells, and dumbbells from 20 lb up).
        #expect(bumps == [
            WeightBump(exerciseName: "Bench Press", from: .pounds(185), to: .pounds(190)),
            WeightBump(exerciseName: "Overhead Press", from: .pounds(115), to: .pounds(120)),
            WeightBump(exerciseName: "Incline DB Press", from: .pounds(60), to: .pounds(65)),
        ])
    }

    @Test func aMissedWeekOnlyCostsThatExercise() {
        finishPushDay(week: 1)
        finishPushDay(week: 2, misses: ["Bench Press"])
        let bumps = finishPushDay(week: 3)
        #expect(bumps.map(\.exerciseName) == ["Overhead Press", "Incline DB Press"])
    }

    @Test func deloadsAreNotCelebrated() throws {
        let everything: Set = ["Bench Press", "Overhead Press", "Incline DB Press"]
        for week in 1...5 {
            #expect(finishPushDay(week: week, misses: everything).isEmpty)
        }
        // The 6th miss closes the second failed block: a deload, not a bump.
        #expect(finishPushDay(week: 6, misses: everything).isEmpty)
        let bench = try #require(pushDay.sortedEntries.first?.slot)
        // 185 × 0.9 = 166.5 → nearest loadable is 167.5.
        #expect(bench.progression().events.last == .deloaded(from: .pounds(185), to: .pounds(167.5)))
    }
}

@MainActor
@Suite("Today plan")
struct TodayPlanTests {
    /// Held so the in-memory store outlives `init`; a context doesn't retain its container.
    let container: ModelContainer
    let context: ModelContext
    let program: Program

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
        program = SampleData.insertProgram(into: context)
    }

    @Test func freshProgramShowsDayOneWithLivePrescriptions() throws {
        let next = try #require(program.nextWorkout())
        let plan = TodayPlan(program: program, day: next.day, week: next.week)

        #expect(plan.day.name == "Push Day")
        #expect(plan.session == nil)
        #expect(plan.exercises.map(\.name) == ["Bench Press", "Overhead Press", "Incline DB Press"])
        #expect(plan.exercises.first?.weight == .pounds(185))
        #expect(plan.cycle == CycleProgress(week: 1, length: 3))
    }

    @Test func startedSessionShowsItsSnapshotAndLoggedSets() throws {
        let day = try #require(program.sortedDays.first)
        let session = program.startSession(for: day, week: 1, in: context)
        let bench = try #require(session.sortedExerciseLogs.first)
        bench.logSet(reps: 8, in: context)
        bench.logSet(reps: 7, in: context)

        let plan = TodayPlan(program: program, day: day, week: 1)
        #expect(plan.session === session)
        #expect(plan.exercises.first?.sets.map(\.reps) == [8, 7])
        #expect(plan.exercises.first?.weight == .pounds(185))
    }

    @Test func removingASetRenumbersTheRest() throws {
        let day = try #require(program.sortedDays.first)
        let log = try #require(program.startSession(for: day, week: 1, in: context).sortedExerciseLogs.first)
        let first = log.logSet(reps: 8, in: context)
        log.logSet(reps: 7, in: context)
        log.logSet(reps: 6, in: context)

        log.removeSet(first, in: context)

        #expect(log.sortedSets.map(\.reps) == [7, 6])
        #expect(log.sortedSets.map(\.order) == [0, 1])
        #expect(log.logSet(reps: 5, in: context).order == 2)
    }

    @Test func finishingMovesTodayToTheNextDay() throws {
        let day = try #require(program.sortedDays.first)
        program.startSession(for: day, week: 1, in: context).complete()
        #expect(program.nextWorkout()?.day.name == "Pull Day")
    }
}
