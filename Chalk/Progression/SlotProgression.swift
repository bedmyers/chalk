//
//  SlotProgression.swift
//  Chalk
//
//  Converts SwiftData models into ChalkCore value snapshots and runs the engine.
//

import ChalkCore
import Foundation
import SwiftData

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
    var slotSessions: [SlotSession] {
        (logs ?? []).compactMap { log in
            guard let session = log.session else { return nil }
            switch session.status {
            case .inProgress:
                return nil
            case .skipped:
                return SlotSession(week: session.weekNumber, status: .skipped)
            case .completed:
                let sets = log.sortedSets.map { SetResult(reps: $0.reps) }
                return SlotSession(week: session.weekNumber, status: .completed(sets: sets))
            }
        }
    }

    /// Replays this slot's history to find what to lift next.
    func progression(loading: LoadingSettings? = nil) -> ProgressionOutcome {
        let input = ProgressionInput(
            startingWeight: startingWeight,
            target: target,
            history: TrainingWeeks.history(from: slotSessions),
            loading: loading ?? .standard(for: unit)
        )
        return progressionRule.rule.evaluate(input)
    }
}
