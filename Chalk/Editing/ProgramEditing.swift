//
//  ProgramEditing.swift
//  Chalk
//
//  Model operations behind the program editor. Structure edits apply immediately,
//  including to the current training week.
//

import ChalkCore
import Foundation
import SwiftData
import SwiftUI  // MutableCollection.move(fromOffsets:toOffset:)

nonisolated enum ProgramLibrary {
    /// Programs that aren't archived. The app keeps at most one.
    static func activePrograms(in context: ModelContext) -> [Program] {
        let descriptor = FetchDescriptor<Program>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Creates a program and archives the active one, so only one is ever active.
    @discardableResult
    static func createProgram(named name: String, unit: WeightUnit, in context: ModelContext) -> Program {
        for program in activePrograms(in: context) {
            program.archive()
        }
        let program = Program(name: name, unit: unit)
        context.insert(program)
        return program
    }
}

enum DayDeletionError: Error {
    /// The day has a workout in progress; finish or skip it first.
    case sessionInProgress
}

extension Program {
    /// Makes an archived program active again, archiving the current one.
    func restore(in context: ModelContext) {
        for program in ProgramLibrary.activePrograms(in: context) where program !== self {
            program.archive()
        }
        archivedAt = nil
    }

    /// Exercise slots still in use.
    var activeSlots: [ExerciseSlot] {
        (slots ?? []).filter { !$0.isArchived }.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func addDay(named name: String, in context: ModelContext) -> ProgramDay {
        let day = ProgramDay(name: name, order: (sortedDays.last?.order ?? -1) + 1)
        context.insert(day)
        day.program = self
        return day
    }

    func moveDays(fromOffsets source: IndexSet, toOffset destination: Int) {
        var days = sortedDays
        days.move(fromOffsets: source, toOffset: destination)
        for (index, day) in days.enumerated() {
            day.order = index
        }
    }

    /// Whether `day` has a workout in progress, which blocks deleting it.
    func hasSessionInProgress(on day: ProgramDay) -> Bool {
        (sessions ?? []).contains {
            $0.status == .inProgress && $0.day?.persistentModelID == day.persistentModelID
        }
    }

    /// Exercises that are only on `day`, so deleting it archives them.
    func exercisesOnlyOn(_ day: ProgramDay) -> [ExerciseSlot] {
        var seen = Set<PersistentIdentifier>()
        return day.sortedEntries.compactMap(\.slot).filter { slot in
            guard seen.insert(slot.persistentModelID).inserted else { return false }
            return (slot.entries ?? []).allSatisfy { $0.day?.persistentModelID == day.persistentModelID }
        }
    }

    /// Deletes `day`, archives exercises that were only on it, and renumbers the rest.
    /// Past sessions for the day are kept. Returns the archived exercises.
    @discardableResult
    func deleteDay(_ day: ProgramDay, in context: ModelContext) throws(DayDeletionError) -> [ExerciseSlot] {
        guard !hasSessionInProgress(on: day) else { throw .sessionInProgress }
        let orphaned = exercisesOnlyOn(day)

        // Detach first so relationship arrays are accurate before the delete is saved.
        for entry in day.entries ?? [] {
            entry.slot = nil
        }
        day.program = nil
        context.delete(day)

        for slot in orphaned {
            slot.archivedAt = Date.now
        }
        for (index, remaining) in sortedDays.enumerated() {
            remaining.order = index
        }
        return orphaned
    }

    /// Creates an exercise from `spec` and puts it on `day`.
    @discardableResult
    func addExercise(_ spec: ExerciseSpec, to day: ProgramDay, in context: ModelContext) -> ExerciseSlot {
        let slot = ExerciseSlot(
            name: spec.trimmedName,
            equipment: spec.equipment,
            bodyRegion: spec.bodyRegion,
            targetSets: spec.targetSets,
            targetReps: spec.targetReps,
            increment: spec.increment,
            startingWeight: spec.weight
        )
        context.insert(slot)
        slot.program = self
        day.add(slot, in: context)
        return slot
    }
}

extension ProgramDay {
    /// Puts `slot` at the end of this day. A slot on several days shares one weight.
    @discardableResult
    func add(_ slot: ExerciseSlot, in context: ModelContext) -> DayEntry {
        let entry = DayEntry(order: (sortedEntries.last?.order ?? -1) + 1)
        context.insert(entry)
        entry.day = self
        entry.slot = slot
        return entry
    }

    func moveEntries(fromOffsets source: IndexSet, toOffset destination: Int) {
        var entries = sortedEntries
        entries.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in entries.enumerated() {
            entry.order = index
        }
    }

    /// Whether removing `entry` takes its exercise off its last day, archiving it.
    func removalArchivesExercise(_ entry: DayEntry) -> Bool {
        guard let slot = entry.slot else { return false }
        return (slot.entries ?? []).allSatisfy { $0.persistentModelID == entry.persistentModelID }
    }

    /// Removes `entry` and archives its exercise if it's on no other day.
    /// Returns the archived exercise, if any.
    @discardableResult
    func remove(_ entry: DayEntry, in context: ModelContext) -> ExerciseSlot? {
        let archived = removalArchivesExercise(entry) ? entry.slot : nil
        entry.slot = nil
        entry.day = nil
        context.delete(entry)
        archived?.archivedAt = Date.now
        for (index, remaining) in sortedEntries.enumerated() {
            remaining.order = index
        }
        return archived
    }
}

extension ExerciseSlot {
    /// The slot as the editor sees it, with its current weight.
    var spec: ExerciseSpec {
        ExerciseSpec(
            name: name,
            equipment: equipment,
            bodyRegion: bodyRegion,
            targetSets: targetSets,
            targetReps: targetReps,
            increment: increment,
            weight: progression().nextWeight
        )
    }

    /// Saves an edit. Cosmetic edits (name, body region) apply in place; anything
    /// that restarts the block archives this slot and returns a successor.
    @discardableResult
    func save(_ edited: ExerciseSpec, in context: ModelContext) -> ExerciseSlot {
        guard edited.restartsBlock(comparedTo: spec) else {
            name = edited.trimmedName
            bodyRegion = edited.bodyRegion
            return self
        }
        return restart(with: edited, in: context)
    }

    /// Archives this slot and starts a successor at `spec.weight` with a fresh
    /// 3-week count, so past weeks are never re-judged. The successor shares
    /// `lineageID` and takes over this slot's days.
    @discardableResult
    func restart(with spec: ExerciseSpec, in context: ModelContext) -> ExerciseSlot {
        let successor = ExerciseSlot(
            name: spec.trimmedName,
            equipment: spec.equipment,
            bodyRegion: spec.bodyRegion,
            targetSets: spec.targetSets,
            targetReps: spec.targetReps,
            increment: spec.increment,
            startingWeight: spec.weight,
            lineageID: lineageID
        )
        successor.progressionRuleRaw = progressionRuleRaw
        context.insert(successor)
        successor.program = program
        for entry in entries ?? [] {
            entry.slot = successor
        }
        archivedAt = Date.now
        return successor
    }
}
