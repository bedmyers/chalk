//
//  WorkoutSession.swift
//  Chalk
//

import ChalkCore
import Foundation
import SwiftData

/// What kind of session this is. Cardio and other kinds will be added as new cases
/// with their own entry types, without changing existing sessions.
nonisolated enum SessionKind: String, Sendable {
    case strength
}

nonisolated enum SessionStatus: String, Sendable {
    case inProgress
    case completed
    /// The user skipped this day. Counts as finished for scheduling.
    case skipped
}

extension SchemaV1 {
    /// One workout: a program day in a training week, completed or skipped.
    @Model
    final class WorkoutSession {
        var id: UUID = UUID()
        var kindRaw: String = SessionKind.strength.rawValue
        var statusRaw: String = SessionStatus.inProgress.rawValue
        /// 1-based training week this session belongs to.
        var weekNumber: Int = 1
        var startedAt: Date = Date.now
        var completedAt: Date? = nil
        var notes: String = ""
        var program: Program?
        var day: ProgramDay?

        @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
        var exerciseLogs: [ExerciseLog]? = []

        init(weekNumber: Int, status: SessionStatus, kind: SessionKind = .strength) {
            self.weekNumber = weekNumber
            self.statusRaw = status.rawValue
            self.kindRaw = kind.rawValue
        }

        var kind: SessionKind { SessionKind(rawValue: kindRaw) ?? .strength }

        var status: SessionStatus {
            get { SessionStatus(rawValue: statusRaw) ?? .inProgress }
            set { statusRaw = newValue.rawValue }
        }

        var isFinished: Bool { status == .completed || status == .skipped }

        var sortedExerciseLogs: [ExerciseLog] {
            (exerciseLogs ?? []).sorted { $0.order < $1.order }
        }
    }

    /// One exercise within a session, with a snapshot of what was prescribed.
    /// The snapshot keeps history accurate even if the slot later changes or is deleted.
    @Model
    final class ExerciseLog {
        var id: UUID = UUID()
        var order: Int = 0
        var exerciseName: String = ""
        var prescribedWeightThousandths: Int = 0
        var prescribedUnitRaw: String = WeightUnit.pounds.rawValue
        var targetSets: Int = 0
        var targetReps: Int = 0
        var session: WorkoutSession?
        var slot: ExerciseSlot?

        @Relationship(deleteRule: .cascade, inverse: \SetLog.exerciseLog)
        var sets: [SetLog]? = []

        init(order: Int, exerciseName: String, prescribedWeight: Weight, targetSets: Int, targetReps: Int) {
            self.order = order
            self.exerciseName = exerciseName
            self.prescribedWeightThousandths = prescribedWeight.thousandths
            self.prescribedUnitRaw = prescribedWeight.unit.rawValue
            self.targetSets = targetSets
            self.targetReps = targetReps
        }

        var prescribedWeight: Weight {
            Weight(
                thousandths: prescribedWeightThousandths,
                unit: WeightUnit(rawValue: prescribedUnitRaw) ?? .pounds
            )
        }

        var sortedSets: [SetLog] {
            (sets ?? []).sorted { $0.order < $1.order }
        }
    }

    /// One logged set. Records the weight actually lifted; progression uses the
    /// prescribed weight and judges only reps.
    @Model
    final class SetLog {
        var id: UUID = UUID()
        var order: Int = 0
        var reps: Int = 0
        var weightThousandths: Int = 0
        var unitRaw: String = WeightUnit.pounds.rawValue
        var loggedAt: Date = Date.now
        var exerciseLog: ExerciseLog?

        init(order: Int, reps: Int, weight: Weight) {
            self.order = order
            self.reps = reps
            self.weightThousandths = weight.thousandths
            self.unitRaw = weight.unit.rawValue
        }

        var weight: Weight {
            Weight(thousandths: weightThousandths, unit: WeightUnit(rawValue: unitRaw) ?? .pounds)
        }
    }
}
