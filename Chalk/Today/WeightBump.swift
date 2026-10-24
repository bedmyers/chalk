//
//  WeightBump.swift
//  Chalk
//

import ChalkCore
import Foundation
import SwiftData

/// A weight increase earned by finishing a block. The app's emotional payoff.
struct WeightBump: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let from: Weight
    let to: Weight

    static func == (lhs: WeightBump, rhs: WeightBump) -> Bool {
        lhs.exerciseName == rhs.exerciseName && lhs.from == rhs.from && lhs.to == rhs.to
    }
}

extension WorkoutSession {
    /// Completes the session and returns the weight increases it earned, in exercise order.
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
                guard case .increased(let from, let to) = event else { return nil }
                return WeightBump(exerciseName: slot.name, from: from, to: to)
            }
        }
    }
}
