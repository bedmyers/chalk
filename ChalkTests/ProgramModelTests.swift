//
//  ProgramModelTests.swift
//  ChalkTests
//

import ChalkCore
import Foundation
import SwiftData
import Testing
@testable import Chalk

/// Exercises the SwiftData models, the model → engine translation, and scheduling
/// against an in-memory container.
@MainActor
@Suite("Program models")
struct ProgramModelTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
    }

    // MARK: Fixtures

    /// Push / Pull / Legs, one slot per day, 4×8 at 135 lb, +5 lb.
    func makePushPullLegs() -> (Program, [ProgramDay], [ExerciseSlot]) {
        let program = Program(name: "PPL", unit: .pounds)
        context.insert(program)
        let names = [("Push", "Bench Press"), ("Pull", "Barbell Row"), ("Legs", "Squat")]
        var days: [ProgramDay] = []
        var slots: [ExerciseSlot] = []
        for (index, (dayName, exercise)) in names.enumerated() {
            let day = ProgramDay(name: dayName, order: index)
            context.insert(day)
            day.program = program
            let slot = makeSlot(exercise, in: program)
            schedule(slot, on: day, order: 0)
            days.append(day)
            slots.append(slot)
        }
        return (program, days, slots)
    }

    /// Two days, with squat on both (one shared weight).
    func makeSharedSquat() -> (Program, [ProgramDay], ExerciseSlot) {
        let program = Program(name: "A/B", unit: .pounds)
        context.insert(program)
        let squat = makeSlot("Squat", in: program)
        let days = ["Day A", "Day B"].enumerated().map { index, name in
            let day = ProgramDay(name: name, order: index)
            context.insert(day)
            day.program = program
            schedule(squat, on: day, order: 0)
            return day
        }
        return (program, days, squat)
    }

    func makeSlot(_ name: String, in program: Program) -> ExerciseSlot {
        let slot = ExerciseSlot(
            name: name,
            equipment: .barbell,
            bodyRegion: .lower,
            targetSets: 4,
            targetReps: 8,
            increment: .pounds(5),
            startingWeight: .pounds(135)
        )
        context.insert(slot)
        slot.program = program
        return slot
    }

    func schedule(_ slot: ExerciseSlot, on day: ProgramDay, order: Int) {
        let entry = DayEntry(order: order)
        context.insert(entry)
        entry.day = day
        entry.slot = slot
    }

    /// Starts, logs, and completes a session where every exercise gets `reps`.
    @discardableResult
    func train(_ program: Program, _ day: ProgramDay, week: Int, reps: [Int] = [8, 8, 8, 8]) -> WorkoutSession {
        let session = program.startSession(for: day, week: week, in: context)
        for log in session.sortedExerciseLogs {
            for rep in reps {
                log.logSet(reps: rep, in: context)
            }
        }
        session.complete()
        return session
    }

    func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: Scheduling

    @Test func nextWorkoutWalksThroughTheWeek() throws {
        let (program, days, _) = makePushPullLegs()
        #expect(program.nextWorkout()?.day == days[0])

        train(program, days[0], week: 1)
        #expect(program.nextWorkout()?.day == days[1])

        program.skip(days[1], week: 1, in: context)
        let next = try #require(program.nextWorkout())
        #expect(next.week == 1)
        #expect(next.day == days[2])

        train(program, days[2], week: 1)
        let week2 = try #require(program.nextWorkout())
        #expect(week2.week == 2)
        #expect(week2.day == days[0])
    }

    @Test func inProgressSessionDoesNotAdvanceTheSchedule() {
        let (program, days, _) = makePushPullLegs()
        let session = program.startSession(for: days[0], week: 1, in: context)
        #expect(program.nextWorkout()?.day == days[0])
        #expect(program.startSession(for: days[0], week: 1, in: context) === session)
    }

    @Test func skipRestOfWeekSkipsOnlyUnfinishedDays() throws {
        let (program, days, _) = makePushPullLegs()
        train(program, days[0], week: 1)

        let skipped = program.skipRestOfWeek(1, in: context)
        #expect(skipped.map(\.day) == [days[1], days[2]])
        #expect(skipped.allSatisfy { $0.status == .skipped && $0.weekNumber == 1 })

        let next = try #require(program.nextWorkout())
        #expect(next.week == 2)
        #expect(next.day == days[0])
    }

    @Test func skippingAnInProgressSessionReusesIt() {
        let (program, days, _) = makePushPullLegs()
        let session = program.startSession(for: days[0], week: 1, in: context)
        #expect(program.skip(days[0], week: 1, in: context) === session)
        #expect(session.status == .skipped)
        #expect(program.sessions?.count == 1)
    }

    // MARK: Skipping one day mid-week

    @Test func skippedDayPausesThatDaysExercisesOnly() {
        let (program, days, slots) = makePushPullLegs()
        let (bench, row) = (slots[0], slots[1])

        for week in 1...3 {
            train(program, days[0], week: week)
            if week == 2 {
                program.skip(days[1], week: week, in: context)
            } else {
                train(program, days[1], week: week)
            }
            train(program, days[2], week: week)
        }

        // Bench hit all three weeks: increased.
        #expect(bench.progression().nextWeight == .pounds(140))
        // Row's week 2 was skipped, so its block is paused at week 3 of 3.
        #expect(row.progression().nextWeight == .pounds(135))
        #expect(row.progression().cycle?.week == 3)

        // Row's next completed week closes its block.
        train(program, days[0], week: 4)
        train(program, days[1], week: 4)
        #expect(row.progression().nextWeight == .pounds(140))
    }

    @Test func skippingOneOfASharedSlotsDaysIsAMiss() {
        let (program, days, squat) = makeSharedSquat()

        for week in 1...3 {
            train(program, days[0], week: week)
            if week == 2 {
                program.skip(days[1], week: week, in: context)
            } else {
                train(program, days[1], week: week)
            }
        }

        let outcome = squat.progression()
        #expect(outcome.nextWeight == .pounds(135))
        #expect(outcome.events == [.held(.pounds(135))])
    }

    @Test func skippingBothOfASharedSlotsDaysPauses() {
        let (program, days, squat) = makeSharedSquat()
        train(program, days[0], week: 1)
        train(program, days[1], week: 1)
        program.skipRestOfWeek(2, in: context)
        for week in 3...4 {
            train(program, days[0], week: week)
            train(program, days[1], week: week)
        }
        #expect(squat.progression().nextWeight == .pounds(140))
    }

    // MARK: Translation details

    @Test func droppedExerciseInACompletedSessionIsAMiss() {
        let (program, days, slots) = makePushPullLegs()
        train(program, days[0], week: 1)
        // Session completed, but no sets logged for bench.
        program.startSession(for: days[0], week: 2, in: context).complete()
        train(program, days[0], week: 3)
        #expect(slots[0].progression().events == [.held(.pounds(135))])
    }

    @Test func extraSetsAndActualWeightDontAffectProgression() {
        let (program, days, slots) = makePushPullLegs()
        for week in 1...3 {
            let session = program.startSession(for: days[0], week: week, in: context)
            let log = session.sortedExerciseLogs[0]
            for _ in 0..<4 { log.logSet(reps: 8, weight: .pounds(145), in: context) }
            log.logSet(reps: 3, in: context)
            session.complete()
        }
        #expect(slots[0].progression().nextWeight == .pounds(140))
    }

    // MARK: Exercise log snapshot

    @Test func exerciseLogSnapshotsThePrescription() throws {
        let (program, days, _) = makePushPullLegs()
        for week in 1...3 {
            train(program, days[0], week: week)
        }
        let session = program.startSession(for: days[0], week: 4, in: context)
        let log = try #require(session.sortedExerciseLogs.first)
        #expect(log.exerciseName == "Bench Press")
        #expect(log.prescribedWeight == .pounds(140))
        #expect(log.targetSets == 4)
        #expect(log.targetReps == 8)
    }

    // MARK: Replacing targets

    @Test func replacingTargetsStartsAContinuousSuccessor() throws {
        let (program, days, slots) = makePushPullLegs()
        let bench = slots[0]
        for week in 1...3 {
            train(program, days[0], week: week)
        }

        var edited = bench.spec
        edited.targetSets = 3
        edited.targetReps = 10
        let successor = bench.save(edited, in: context)

        #expect(bench.isArchived)
        #expect(!successor.isArchived)
        #expect(successor.lineageID == bench.lineageID)
        #expect(successor.startingWeight == .pounds(140))
        #expect(successor.targetSets == 3)
        #expect(successor.targetReps == 10)
        #expect(bench.entries?.isEmpty == true)
        #expect(days[0].sortedEntries.first?.slot == successor)

        // Old history stays on the archived slot; new sessions go to the successor.
        #expect(bench.progression().nextWeight == .pounds(140))
        let log = try #require(program.startSession(for: days[0], week: 4, in: context).sortedExerciseLogs.first)
        #expect(log.slot == successor)
        #expect(log.prescribedWeight == .pounds(140))
        #expect(log.targetReps == 10)
    }

    // MARK: Archive and hard delete

    @Test func archiveKeepsEverything() throws {
        let (program, days, _) = makePushPullLegs()
        train(program, days[0], week: 1)
        program.archive()
        try context.save()

        #expect(program.isArchived)
        #expect(try count(Program.self) == 1)
        #expect(try count(WorkoutSession.self) == 1)
        #expect(try count(SetLog.self) == 4)
    }

    @Test func hardDeleteCascadesToEverything() throws {
        let (program, days, _) = makePushPullLegs()
        train(program, days[0], week: 1)
        program.skip(days[1], week: 1, in: context)
        try context.save()

        context.delete(program)
        try context.save()

        #expect(try count(Program.self) == 0)
        #expect(try count(ProgramDay.self) == 0)
        #expect(try count(DayEntry.self) == 0)
        #expect(try count(ExerciseSlot.self) == 0)
        #expect(try count(WorkoutSession.self) == 0)
        #expect(try count(ExerciseLog.self) == 0)
        #expect(try count(SetLog.self) == 0)
    }
}
