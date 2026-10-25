//
//  TodayPlan.swift
//  Chalk
//

import ChalkCore
import Foundation
import SwiftData

/// One exercise as shown on the Today screen.
struct PlannedExercise: Identifiable {
    let slot: ExerciseSlot
    let name: String
    let targetSets: Int
    let targetReps: Int
    let weight: Weight
    let sets: [SetLog]

    var id: UUID { slot.id }
}

/// Today's workout. Once a session is started its snapshot is shown, so the
/// prescription can't shift mid-workout; before that, the live prescription.
struct TodayPlan {
    let day: ProgramDay
    let week: Int
    let session: WorkoutSession?
    let exercises: [PlannedExercise]
    /// Block position of the day's main lift (its first exercise).
    let cycle: CycleProgress?

    init(program: Program, day: ProgramDay, week: Int) {
        self.day = day
        self.week = week
        let session = program.inProgressSession(for: day, week: week)
        self.session = session

        if let session {
            exercises = session.sortedExerciseLogs.compactMap { log in
                guard let slot = log.slot else { return nil }
                return PlannedExercise(
                    slot: slot,
                    name: log.exerciseName,
                    targetSets: log.targetSets,
                    targetReps: log.targetReps,
                    weight: log.prescribedWeight,
                    sets: log.sortedSets
                )
            }
        } else {
            exercises = day.sortedEntries.compactMap(\.slot).filter { !$0.isArchived }.map { slot in
                PlannedExercise(
                    slot: slot,
                    name: slot.name,
                    targetSets: slot.targetSets,
                    targetReps: slot.targetReps,
                    weight: slot.progression().nextWeight,
                    sets: []
                )
            }
        }
        cycle = exercises.first?.slot.progression().cycle
    }
}

/// How tapping a set button changes it.
nonisolated enum SetTap {
    /// Tapping a logged set counts its reps down by one, so a missed rep is one
    /// tap away. Tapping at zero wraps back to the target.
    static func reps(afterTapping current: Int, target: Int) -> Int {
        current > 0 ? current - 1 : target
    }
}
