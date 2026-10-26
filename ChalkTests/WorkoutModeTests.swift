//
//  WorkoutModeTests.swift
//  ChalkTests
//

import ChalkCore
import Foundation
import SwiftData
import Testing
@testable import Chalk

@Suite("Workout pager")
struct WorkoutPagerTests {
    static let a = UUID(), b = UUID(), c = UUID()
    static let ids = [a, b, c]

    @Test func nextIsTheNextUnfinishedLiftBelow() {
        #expect(WorkoutPager.page(after: Self.a, ids: Self.ids, done: [Self.a]) == .exercise(Self.b))
        #expect(WorkoutPager.page(after: Self.a, ids: Self.ids, done: [Self.a, Self.b]) == .exercise(Self.c))
    }

    @Test func wrapsBackToLiftsSkippedEarlier() {
        // Did C first because the rack was taken: A and B are still to do.
        #expect(WorkoutPager.page(after: Self.c, ids: Self.ids, done: [Self.c]) == .exercise(Self.a))
        #expect(WorkoutPager.page(after: Self.b, ids: Self.ids, done: [Self.b, Self.c]) == .exercise(Self.a))
    }

    @Test func summaryWhenEverythingIsDone() {
        #expect(WorkoutPager.page(after: Self.c, ids: Self.ids, done: Set(Self.ids)) == .summary)
    }

    @Test func opensOnTheFirstUnfinishedLift() {
        #expect(WorkoutPager.firstPage(ids: Self.ids, done: []) == .exercise(Self.a))
        #expect(WorkoutPager.firstPage(ids: Self.ids, done: [Self.a]) == .exercise(Self.b))
        #expect(WorkoutPager.firstPage(ids: Self.ids, done: Set(Self.ids)) == .summary)
        #expect(WorkoutPager.firstPage(ids: [], done: []) == .summary)
    }
}

@Suite("Rest timer")
struct RestTimerTests {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func countsDownFromWhenItEnds() {
        var timer = RestTimer()
        #expect(timer.remaining(at: now) == nil)
        timer.start(90, now: now)
        #expect(timer.remaining(at: now) == 90)
        #expect(timer.remaining(at: now.addingTimeInterval(60)) == 30)
        #expect(timer.remaining(at: now.addingTimeInterval(90)) == nil)
    }

    @Test func addingTimeExtendsOrStarts() {
        var timer = RestTimer()
        timer.add(30, now: now)
        #expect(timer.remaining(at: now) == 30)
        timer.add(30, now: now)
        #expect(timer.remaining(at: now) == 60)

        // After it ran out, adding starts fresh from now.
        let later = now.addingTimeInterval(120)
        timer.add(30, now: later)
        #expect(timer.remaining(at: later) == 30)
    }

    @Test func skipStops() {
        var timer = RestTimer()
        timer.start(90, now: now)
        timer.stop()
        #expect(timer.remaining(at: now) == nil)
    }

    @Test(arguments: [(Equipment.barbell, 150.0), (.dumbbell, 90), (.machine, 90), (.bodyweight, 90)])
    func defaultDurations(equipment: Equipment, seconds: TimeInterval) {
        #expect(RestTimer.defaultDuration(for: equipment) == seconds)
    }

    @Test(arguments: [(150.0, "2:30"), (90, "1:30"), (59.2, "1:00"), (0.4, "0:01"), (605, "10:05")])
    func text(remaining: TimeInterval, expected: String) {
        #expect(RestTimer.text(remaining) == expected)
    }
}

@MainActor
@Suite("Set taps")
struct SetTapLoggingTests {
    let container: ModelContainer
    let context: ModelContext
    let program: Program
    let day: ProgramDay
    let bench: ExerciseSlot

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
        program = ProgramLibrary.createProgram(named: "Test", unit: .pounds, in: context)
        day = program.addDay(named: "Push", in: context)
        var spec = ExerciseSpec.new(unit: .pounds)
        spec.name = "Bench Press"
        spec.targetSets = 3
        spec.targetReps = 8
        spec.weight = .pounds(185)
        bench = program.addExercise(spec, to: day, in: context)
    }

    func sets() -> [Int] {
        program.inProgressSession(for: day, week: 1)?.sortedExerciseLogs.first?.sortedSets.map(\.reps) ?? []
    }

    @Test func firstTapStartsTheSessionAndLogsTheTarget() {
        #expect(program.inProgressSession(for: day, week: 1) == nil)
        #expect(program.tapSet(0, of: bench, day: day, week: 1, in: context) == .logged(finishedExercise: false))
        #expect(sets() == [8])
    }

    @Test func theLastTargetSetFinishesTheExercise() {
        program.tapSet(0, of: bench, day: day, week: 1, in: context)
        program.tapSet(1, of: bench, day: day, week: 1, in: context)
        #expect(program.tapSet(2, of: bench, day: day, week: 1, in: context) == .logged(finishedExercise: true))
        // An extra set doesn't finish it again.
        #expect(program.tapSet(3, of: bench, day: day, week: 1, in: context) == .logged(finishedExercise: false))
        #expect(sets() == [8, 8, 8, 8])
    }

    @Test func tappingALoggedSetCountsDown() {
        program.tapSet(0, of: bench, day: day, week: 1, in: context)
        #expect(program.tapSet(0, of: bench, day: day, week: 1, in: context) == .adjusted)
        #expect(sets() == [7])
    }

    @Test func plannedExerciseIsDoneOnceEveryTargetSetIsLogged() throws {
        for index in 0..<3 {
            #expect(try #require(TodayPlan(program: program, day: day, week: 1).exercises.first).isDone == false)
            program.tapSet(index, of: bench, day: day, week: 1, in: context)
        }
        #expect(try #require(TodayPlan(program: program, day: day, week: 1).exercises.first).isDone)
    }
}

@MainActor
@Suite("Finishing a workout")
struct WorkoutFinishTests {
    @Test func finishingMovesOnToTheNextDay() throws {
        let container = SampleData.previewContainer(completedWeeks: 3)
        let context = container.mainContext
        let program = ProgramLibrary.activePrograms(in: context)[0]
        let next = try #require(program.nextWorkout())
        let plan = TodayPlan(program: program, day: next.day, week: next.week)
        let bench = try #require(plan.exercises.first)
        for i in 0..<4 { program.tapSet(i, of: bench.slot, day: next.day, week: next.week, in: context) }
        let after = try #require(program.nextWorkout())
        #expect(after.day.name == next.day.name)
        let finishPlan = TodayPlan(program: program, day: after.day, week: after.week)
        #expect(finishPlan.session != nil)
        finishPlan.session?.completeAndCollectBumps()
        let moved = try #require(program.nextWorkout())
        #expect(moved.day.name == "Pull Day")
        #expect(moved.week == next.week)
    }
}
