//
//  HistoryTests.swift
//  ChalkTests
//

import ChalkCore
import Foundation
import SwiftData
import Testing
@testable import Chalk

@MainActor
@Suite("Editing finished workouts")
struct WorkoutEditingTests {
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

    /// Logs Push Day for `week`: every set at target, except bench gets `benchReps`.
    @discardableResult
    func logPushDay(week: Int, benchReps: [Int]? = nil) -> WorkoutSession {
        let session = program.startSession(for: pushDay, week: week, in: context)
        for log in session.sortedExerciseLogs {
            let reps = (log.exerciseName == "Bench Press" ? benchReps : nil)
                ?? Array(repeating: log.targetReps, count: log.targetSets)
            for rep in reps {
                log.logSet(reps: rep, in: context)
            }
        }
        session.complete()
        return session
    }

    var bench: ExerciseSlot {
        get throws { try #require(program.activeSlots.first { $0.name == "Bench Press" }) }
    }

    /// Edits bench in `session`'s draft.
    func editingBench(in session: WorkoutSession, _ edit: (inout ExerciseDraft) -> Void) throws -> WorkoutDraft {
        var draft = session.draft
        let index = try #require(draft.exercises.firstIndex { $0.name == "Bench Press" })
        edit(&draft.exercises[index])
        return draft
    }

    // MARK: Edits that change a current weight

    @Test func loweringARepInAPassedBlockUndoesTheBump() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2)
        logPushDay(week: 3)
        #expect(try bench.progression().nextWeight == .pounds(190))

        let draft = try editingBench(in: week2) { $0.sets[3].reps = 7 }

        #expect(week2.weightChanges(applying: draft) == [
            WeightChange(exerciseName: "Bench Press", from: .pounds(190), to: .pounds(185)),
        ])
        #expect(week2.weightChanges(applying: draft).first?.description == "Bench Press 190 → 185 lb")
    }

    @Test func deletingASetFromAPassedWeekIsAMiss() throws {
        logPushDay(week: 1)
        logPushDay(week: 2)
        let week3 = logPushDay(week: 3)

        let draft = try editingBench(in: week3) { $0.sets.removeLast() }

        #expect(week3.weightChanges(applying: draft).map(\.description) == ["Bench Press 190 → 185 lb"])
    }

    @Test func addingAMissedSetEarnsTheBump() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2, benchReps: [8, 8, 8])
        logPushDay(week: 3)
        #expect(try bench.progression().nextWeight == .pounds(185))

        let draft = try editingBench(in: week2) { $0.addSet() }
        let changes = week2.weightChanges(applying: draft)
        #expect(changes.map(\.description) == ["Bench Press 185 → 190 lb"])

        week2.apply(draft, in: context)
        #expect(try bench.progression().nextWeight == .pounds(190))
    }

    @Test func onlyExercisesWhoseWeightChangesAreNamed() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2)
        logPushDay(week: 3)

        var draft = week2.draft
        // Lower bench and raise overhead press: only bench's weight changes.
        draft.exercises[0].sets[0].reps = 5
        draft.exercises[1].sets[0].reps = 12

        #expect(week2.weightChanges(applying: draft).map(\.exerciseName) == ["Bench Press"])
    }

    // MARK: Edits that don't change a current weight

    @Test func editingTheWeightLiftedChangesNothing() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2)
        logPushDay(week: 3)

        let draft = try editingBench(in: week2) { $0.sets[0].weight = .pounds(155) }

        #expect(week2.weightChanges(applying: draft).isEmpty)
    }

    @Test func raisingRepsOnAHitChangesNothing() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2)
        logPushDay(week: 3)

        let draft = try editingBench(in: week2) { $0.sets[0].reps = 10 }

        #expect(week2.weightChanges(applying: draft).isEmpty)
    }

    @Test func deletingAnExtraSetChangesNothing() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2, benchReps: [8, 8, 8, 8, 4])
        logPushDay(week: 3)

        let draft = try editingBench(in: week2) { $0.sets.removeLast() }

        #expect(week2.weightChanges(applying: draft).isEmpty)
    }

    @Test func editingABlockThatHasntClosedChangesNothingYet() throws {
        let week1 = logPushDay(week: 1)

        let draft = try editingBench(in: week1) { $0.sets[3].reps = 6 }

        // Week 1 is now a miss, but the block hasn't closed, so today's weight holds.
        #expect(week1.weightChanges(applying: draft).isEmpty)
    }

    @Test func editingAnArchivedExercisesHistoryChangesNothing() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2)
        logPushDay(week: 3)
        var restarted = try bench.spec
        restarted.targetReps = 10
        try bench.save(restarted, in: context)

        let draft = try editingBench(in: week2) { $0.sets[3].reps = 2 }

        // The old slot is archived; its successor starts from a fixed weight.
        #expect(week2.weightChanges(applying: draft).isEmpty)
    }

    /// Regression: drafts were keyed by `persistentModelID`, which changes from a
    /// temporary to a permanent ID on first save, so a save between opening the
    /// editor and tapping Save made the edit silently do nothing.
    @Test func aSaveBetweenDraftingAndApplyingKeepsTheEdit() throws {
        let session = logPushDay(week: 1)
        let draft = try editingBench(in: session) { bench in
            bench.sets[0].reps = 6
            bench.addSet()
        }

        try context.save()
        #expect(session.weightChanges(applying: draft).isEmpty)
        session.apply(draft, in: context)

        let log = try #require(session.sortedExerciseLogs.first)
        #expect(log.sortedSets.map(\.reps) == [6, 8, 8, 8, 8])
    }

    @Test func aSaveBetweenDraftingAndPreviewingStillFindsTheChange() throws {
        logPushDay(week: 1)
        let week2 = logPushDay(week: 2)
        logPushDay(week: 3)
        let draft = try editingBench(in: week2) { $0.sets[3].reps = 7 }

        try context.save()

        #expect(week2.weightChanges(applying: draft).map(\.description) == ["Bench Press 190 → 185 lb"])
    }

    @Test func anUneditedDraftEqualsTheWorkout() throws {
        let session = logPushDay(week: 1)
        #expect(session.draft == session.draft)

        let edited = try editingBench(in: session) { $0.sets[0].reps = 7 }
        #expect(edited != session.draft)
    }

    // MARK: Applying

    @Test func applyingUpdatesAddsDeletesAndRenumbers() throws {
        let session = logPushDay(week: 1)
        let draft = try editingBench(in: session) { bench in
            bench.sets[1].reps = 6
            bench.sets[2].weight = .pounds(175)
            bench.sets.remove(at: 0)
            bench.addSet()
        }

        session.apply(draft, in: context)
        try context.save()

        let log = try #require(session.sortedExerciseLogs.first)
        #expect(log.sortedSets.map(\.reps) == [6, 8, 8, 8])
        #expect(log.sortedSets.map(\.order) == [0, 1, 2, 3])
        #expect(log.sortedSets[1].weight == .pounds(175))
        #expect(log.sortedSets.last?.weight == .pounds(185))
        // 4 bench + 4 overhead press + 3 incline.
        #expect(try context.fetchCount(FetchDescriptor<SetLog>()) == 11)
    }
}

@Suite("Weight history")
struct WeightHistoryTests {
    @Test func markersForBumpsDeloadsAndEdits() {
        let a = UUID()
        let b = UUID()
        func day(_ n: Double) -> Date { Date(timeIntervalSince1970: n * 86_400) }
        let entries = [
            WeightHistoryEntry(date: day(3), slotID: a, weight: .pounds(190)),
            WeightHistoryEntry(date: day(1), slotID: a, weight: .pounds(185)),
            WeightHistoryEntry(date: day(2), slotID: a, weight: .pounds(185)),
            WeightHistoryEntry(date: day(4), slotID: a, weight: .pounds(170)),
            WeightHistoryEntry(date: day(5), slotID: b, weight: .pounds(175)),
            WeightHistoryEntry(date: day(6), slotID: b, weight: .pounds(175)),
        ]

        let points = WeightHistory.points(from: entries)

        #expect(points.map(\.weight) == [185, 185, 190, 170, 175, 175].map { Weight.pounds($0) })
        #expect(points.map(\.marker) == [nil, nil, .bump, .deload, .edited, nil])
    }

    @Test func anEditThatKeepsTheWeightIsNotMarked() {
        let points = WeightHistory.points(from: [
            WeightHistoryEntry(date: .distantPast, slotID: UUID(), weight: .pounds(185)),
            WeightHistoryEntry(date: .now, slotID: UUID(), weight: .pounds(185)),
        ])
        #expect(points.map(\.marker) == [nil, nil])
    }
}

@MainActor
@Suite("History queries")
struct HistoryQueryTests {
    @Test func finishedSessionsIncludeArchivedProgramsNewestFirst() throws {
        let container = try ChalkModelContainer.make(inMemory: true)
        let context = container.mainContext
        let old = SampleData.insertProgram(into: context)
        let oldSession = old.startSession(for: old.sortedDays[0], week: 1, in: context)
        oldSession.startedAt = Date(timeIntervalSinceNow: -7200)
        oldSession.complete()

        let new = ProgramLibrary.createProgram(named: "5x5", unit: .pounds, in: context)
        let day = new.addDay(named: "A", in: context)
        let skipped = new.skip(day, week: 1, in: context)
        skipped.startedAt = Date(timeIntervalSinceNow: -3600)
        new.startSession(for: day, week: 2, in: context)  // in progress: excluded

        let finished = HistoryQueries.finishedSessions(in: context)
        #expect(finished == [skipped, oldSession])
        #expect(old.isArchived)
        #expect(finished.last?.program?.name == "Push Pull Legs")
    }
}
