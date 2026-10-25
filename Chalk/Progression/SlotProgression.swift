//
//  SlotProgression.swift
//  Chalk
//
//  Converts SwiftData models into ChalkCore value snapshots and runs the engine.
//

import ChalkCore
import Foundation
import SwiftData

/// Replacement sets for specific exercise logs, keyed by the log's stable `id`.
/// Lets the app ask "what would the weight be if this past workout were edited?"
/// without touching the store.
typealias SetOverrides = [UUID: [SetResult]]

extension ExerciseSlot {
    /// How many days the slot is scheduled on. All of them must be in for a week to count.
    var sessionsPerWeek: Int { max(1, entries?.count ?? 0) }

    var target: ExerciseTarget {
        ExerciseTarget(
            sets: targetSets,
            reps: targetReps,
            increment: increment,
            equipment: equipment,
            sessionsPerWeek: sessionsPerWeek
        )
    }

    /// This slot's finished sessions as the engine sees them. In-progress sessions
    /// are left out; a completed session where the exercise was dropped has no sets.
    func slotSessions(overriding overrides: SetOverrides = [:]) -> [SlotSession] {
        (logs ?? []).compactMap { log in
            guard let session = log.session else { return nil }
            switch session.status {
            case .inProgress:
                return nil
            case .skipped:
                return SlotSession(week: session.weekNumber, status: .skipped)
            case .completed:
                let sets = overrides[log.id]
                    ?? log.sortedSets.map { SetResult(reps: $0.reps) }
                return SlotSession(week: session.weekNumber, status: .completed(sets: sets))
            }
        }
    }

    var slotSessions: [SlotSession] { slotSessions() }

    func progressionInput(overriding overrides: SetOverrides = [:], loading: LoadingSettings? = nil) -> ProgressionInput {
        ProgressionInput(
            startingWeight: startingWeight,
            target: target,
            history: TrainingWeeks.history(from: slotSessions(overriding: overrides)),
            loading: loading ?? .standard(for: unit)
        )
    }

    /// Replays this slot's history to find what to lift next.
    func progression(overriding overrides: SetOverrides = [:], loading: LoadingSettings? = nil) -> ProgressionOutcome {
        progressionRule.rule.evaluate(progressionInput(overriding: overrides, loading: loading))
    }

    /// Closed blocks, oldest first, for rules that work in blocks.
    var blockResults: [BlockResult] {
        switch progressionRule {
        case .threeWeekBlock: ThreeWeekBlockRule().replay(progressionInput()).blocks
        }
    }

    /// Every slot in this exercise's lineage (this one plus its predecessors and
    /// successors), oldest first, so edits show as one continuous exercise.
    var lineage: [ExerciseSlot] {
        (program?.slots ?? [])
            .filter { $0.lineageID == lineageID }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
