//
//  WeightBump.swift
//  Chalk
//

import ChalkCore
import Foundation
import SwiftData

/// An increase earned by finishing a block. The app's emotional payoff.
nonisolated struct WeightBump: Identifiable, Equatable, Sendable {
    /// What went up: the weight, or the reps for a bodyweight lift.
    enum Change: Equatable {
        case weight(from: Weight, to: Weight)
        /// Rep waves as shown, e.g. "6/8/10" → "7/9/11".
        case reps(from: String, to: String)
    }

    let id = UUID()
    let exerciseName: String
    let change: Change

    init(exerciseName: String, change: Change) {
        self.exerciseName = exerciseName
        self.change = change
    }

    init(exerciseName: String, from: Weight, to: Weight) {
        self.init(exerciseName: exerciseName, change: .weight(from: from, to: to))
    }

    static func == (lhs: WeightBump, rhs: WeightBump) -> Bool {
        lhs.exerciseName == rhs.exerciseName && lhs.change == rhs.change
    }
}

extension WorkoutSession {
    /// Completes the session and returns the increases it earned, in exercise order.
    /// Compares each slot's progression events before and after completing, so only
    /// blocks closed by this session count.
    @discardableResult
    func completeAndCollectBumps() -> [WeightBump] {
        var seen = Set<PersistentIdentifier>()
        let slots = sortedExerciseLogs.compactMap(\.slot).filter { seen.insert($0.persistentModelID).inserted }
        let eventCountsBefore = slots.map { $0.progression().events.count }

        complete()

        return zip(slots, eventCountsBefore).flatMap { slot, countBefore in
            slot.progression().events.dropFirst(countBefore).compactMap { event -> WeightBump? in
                switch event {
                case .increased(let from, let to):
                    WeightBump(exerciseName: slot.name, from: from, to: to)
                case .repsRaised(let from, let to):
                    WeightBump(exerciseName: slot.name, change: .reps(from: slot.repsText(extraReps: from), to: slot.repsText(extraReps: to)))
                case .held, .deloaded, .repsLowered:
                    nil
                }
            }
        }
    }
}
