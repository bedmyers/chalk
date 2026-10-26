//
//  WorkoutEditing.swift
//  Chalk
//
//  Editing finished workouts. Edits are made on a draft, previewed against the
//  engine to find any current weights they change, then applied.
//

import ChalkCore
import Foundation
import SwiftData

/// One set in a workout being edited.
nonisolated struct SetDraft: Identifiable, Equatable, Sendable {
    let id = UUID()
    var reps: Int
    /// The weight actually lifted. Recorded only; progression uses the prescribed weight.
    var weight: Weight
    /// The stored set this came from (its stable `id`), or nil for a newly added set.
    var existing: UUID?

    /// Compares content only, so a fresh draft of an unedited workout equals the original.
    static func == (lhs: SetDraft, rhs: SetDraft) -> Bool {
        lhs.reps == rhs.reps && lhs.weight == rhs.weight && lhs.existing == rhs.existing
    }
}

/// One exercise in a workout being edited.
nonisolated struct ExerciseDraft: Identifiable, Equatable, Sendable {
    /// The exercise log's stable `id`. Not `persistentModelID`, which changes when a
    /// new object is first saved and would leave the draft pointing at nothing.
    let logID: UUID
    let name: String
    let targetSets: Int
    let targetReps: Int
    let prescribedWeight: Weight
    var sets: [SetDraft]
    /// False for bodyweight lifts, which show "BW" instead of a weight.
    var isWeighted = true

    var id: UUID { logID }

    /// A new set at the target reps and prescribed weight, for logging a missed set.
    mutating func addSet() {
        sets.append(SetDraft(reps: targetReps, weight: prescribedWeight, existing: nil))
    }
}

/// A finished workout being edited.
nonisolated struct WorkoutDraft: Equatable, Sendable {
    var exercises: [ExerciseDraft]

    /// The draft's reps per exercise log, as the engine sees them.
    var setOverrides: SetOverrides {
        Dictionary(uniqueKeysWithValues: exercises.map { exercise in
            (exercise.logID, exercise.sets.map { SetResult(reps: $0.reps) })
        })
    }
}

/// A current weight an edit would change, e.g. "Bench Press 190 → 185 lb", or a
/// bodyweight lift's reps, e.g. "Pull-Up 7/9/11 → 6/8/10 reps".
nonisolated struct WeightChange: Equatable, Sendable, CustomStringConvertible {
    let exerciseName: String
    let from: String
    let to: String

    init(exerciseName: String, from: Weight, to: Weight) {
        self.exerciseName = exerciseName
        self.from = from.formattedValue
        self.to = to.description
    }

    init(exerciseName: String, fromReps: String, toReps: String) {
        self.exerciseName = exerciseName
        self.from = fromReps
        self.to = "\(toReps) reps"
    }

    var description: String {
        "\(exerciseName) \(from) → \(to)"
    }
}

extension WorkoutSession {
    var draft: WorkoutDraft {
        WorkoutDraft(exercises: sortedExerciseLogs.map { log in
            ExerciseDraft(
                logID: log.id,
                name: log.exerciseName,
                targetSets: log.targetSets,
                targetReps: log.targetReps,
                prescribedWeight: log.prescribedWeight,
                sets: log.sortedSets.map { set in
                    SetDraft(reps: set.reps, weight: set.weight, existing: set.id)
                },
                isWeighted: log.slot?.equipment.isWeighted ?? true
            )
        })
    }

    /// The current weights that saving `draft` would change, in exercise order.
    /// Only active exercises count: an archived slot's weight isn't used anymore.
    func weightChanges(applying draft: WorkoutDraft) -> [WeightChange] {
        let overrides = draft.setOverrides
        var seen = Set<PersistentIdentifier>()
        return sortedExerciseLogs
            .compactMap(\.slot)
            .filter { !$0.isArchived && seen.insert($0.persistentModelID).inserted }
            .compactMap { slot in
                let before = slot.progression()
                let after = slot.progression(overriding: overrides)
                if before.nextWeight != after.nextWeight {
                    return WeightChange(exerciseName: slot.name, from: before.nextWeight, to: after.nextWeight)
                }
                // Bodyweight lifts progress by reps instead.
                if before.extraReps != after.extraReps {
                    return WeightChange(
                        exerciseName: slot.name,
                        fromReps: slot.repsText(extraReps: before.extraReps),
                        toReps: slot.repsText(extraReps: after.extraReps)
                    )
                }
                return nil
            }
    }

    /// Writes `draft` back: updates edited sets, adds new ones, deletes removed
    /// ones, and renumbers.
    func apply(_ draft: WorkoutDraft, in context: ModelContext) {
        for exercise in draft.exercises {
            guard let log = sortedExerciseLogs.first(where: { $0.id == exercise.logID }) else {
                continue
            }
            let kept = Set(exercise.sets.compactMap(\.existing))
            for set in log.sortedSets where !kept.contains(set.id) {
                set.exerciseLog = nil
                context.delete(set)
            }
            let stored = Dictionary(uniqueKeysWithValues: log.sortedSets.map { ($0.id, $0) })
            for (index, draftSet) in exercise.sets.enumerated() {
                if let id = draftSet.existing, let set = stored[id] {
                    set.order = index
                    set.reps = draftSet.reps
                    set.weightThousandths = draftSet.weight.thousandths
                    set.unitRaw = draftSet.weight.unit.rawValue
                } else {
                    let set = SetLog(order: index, reps: draftSet.reps, weight: draftSet.weight)
                    context.insert(set)
                    set.exerciseLog = log
                }
            }
        }
    }
}

// MARK: - Weight history for charts

/// A marker on the weight chart.
nonisolated enum WeightMarker: String, Sendable {
    /// Earned by a passed block.
    case bump
    /// After two failed blocks.
    case deload
    /// Set by hand when the exercise was edited.
    case edited
}

/// One prescribed weight over time for an exercise.
nonisolated struct WeightHistoryEntry: Sendable, Equatable {
    let date: Date
    /// Which slot in the lineage this came from.
    let slotID: UUID
    let weight: Weight
}

nonisolated struct WeightPoint: Identifiable, Sendable, Equatable {
    let id: Int
    let date: Date
    let weight: Weight
    let marker: WeightMarker?
}

nonisolated enum WeightHistory {
    /// Chart points in date order. A weight change within one slot is a bump or a
    /// deload; a change across slots in the lineage is a hand edit.
    static func points(from entries: [WeightHistoryEntry]) -> [WeightPoint] {
        let sorted = entries.sorted { $0.date < $1.date }
        return sorted.enumerated().map { index, entry in
            var marker: WeightMarker?
            if index > 0 {
                let previous = sorted[index - 1]
                if entry.weight != previous.weight {
                    if entry.slotID != previous.slotID {
                        marker = .edited
                    } else {
                        marker = entry.weight > previous.weight ? .bump : .deload
                    }
                }
            }
            return WeightPoint(id: index, date: entry.date, weight: entry.weight, marker: marker)
        }
    }
}

extension ExerciseSlot {
    /// What was prescribed at each completed workout across the lineage, plus the
    /// current weight as of `now`, so a just-earned bump shows on the chart.
    func weightHistory(now: Date = .now) -> [WeightHistoryEntry] {
        let logged = lineage.flatMap { slot in
            (slot.logs ?? []).compactMap { log -> WeightHistoryEntry? in
                guard let session = log.session, session.status == .completed else { return nil }
                return WeightHistoryEntry(
                    date: session.completedAt ?? session.startedAt,
                    slotID: slot.id,
                    weight: log.prescribedWeight
                )
            }
        }
        return logged + [WeightHistoryEntry(date: now, slotID: id, weight: progression().nextWeight)]
    }
}

// MARK: - Queries

nonisolated enum HistoryQueries {
    /// Completed and skipped sessions from every program, newest first.
    static func finishedSessions(in context: ModelContext) -> [WorkoutSession] {
        let inProgress = SessionStatus.inProgress.rawValue
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw != inProgress },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
