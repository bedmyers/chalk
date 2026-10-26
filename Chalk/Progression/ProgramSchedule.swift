//
//  ProgramSchedule.swift
//  Chalk
//
//  Starting, skipping, and finishing workouts. Weeks are training weeks:
//  a week ends when every day in it is completed or skipped.
//

import ChalkCore
import Foundation
import SwiftData

extension Program {
    /// Completed and skipped sessions as positions in the schedule.
    var finishedWorkouts: Set<ScheduledWorkout> {
        let dayIndex = Dictionary(
            uniqueKeysWithValues: sortedDays.enumerated().map { ($1.persistentModelID, $0) }
        )
        return Set((sessions ?? []).compactMap { session in
            guard session.isFinished,
                  let day = session.day,
                  let index = dayIndex[day.persistentModelID]
            else { return nil }
            return ScheduledWorkout(week: session.weekNumber, day: index)
        })
    }

    /// The workout to do next. A missed day stays next until it's logged or skipped.
    func nextWorkout() -> (week: Int, day: ProgramDay)? {
        let days = sortedDays
        guard let next = Schedule.nextWorkout(dayCount: days.count, finished: finishedWorkouts) else {
            return nil
        }
        return (next.week, days[next.day])
    }

    /// The in-progress session for `day` in `week`, if one has been started.
    func inProgressSession(for day: ProgramDay, week: Int) -> WorkoutSession? {
        session(for: day, week: week, status: .inProgress)
    }

    /// Starts the session for `day` in `week`, or returns it if it's already in progress.
    @discardableResult
    func startSession(for day: ProgramDay, week: Int, in context: ModelContext) -> WorkoutSession {
        if let existing = session(for: day, week: week, status: .inProgress) {
            return existing
        }
        return makeSession(for: day, week: week, status: .inProgress, in: context)
    }

    /// Skips one day. An in-progress session for that day becomes skipped.
    @discardableResult
    func skip(_ day: ProgramDay, week: Int, in context: ModelContext) -> WorkoutSession {
        if let existing = session(for: day, week: week, status: .inProgress) {
            existing.status = .skipped
            existing.completedAt = Date.now
            return existing
        }
        return makeSession(for: day, week: week, status: .skipped, in: context)
    }

    /// Skips every day of `week` that isn't finished yet.
    @discardableResult
    func skipRestOfWeek(_ week: Int, in context: ModelContext) -> [WorkoutSession] {
        let days = sortedDays
        return Schedule.remainingDays(inWeek: week, dayCount: days.count, finished: finishedWorkouts)
            .map { skip(days[$0.day], week: week, in: context) }
    }

    /// The normal way to retire a program. All history is kept.
    func archive() {
        archivedAt = Date.now
    }

    // MARK: - Private

    private func session(for day: ProgramDay, week: Int, status: SessionStatus) -> WorkoutSession? {
        (sessions ?? []).first {
            $0.day?.persistentModelID == day.persistentModelID
                && $0.weekNumber == week
                && $0.status == status
        }
    }

    /// Creates a session with one exercise log per scheduled slot, each snapshotting
    /// the prescribed weight and targets at the moment the session is created.
    private func makeSession(
        for day: ProgramDay,
        week: Int,
        status: SessionStatus,
        in context: ModelContext
    ) -> WorkoutSession {
        let slots = day.sortedEntries.compactMap(\.slot).filter { !$0.isArchived }
        // Compute prescriptions before the new logs exist, so they can't affect the replay.
        let prescribed = slots.map { $0.progression().nextWeight }

        let session = WorkoutSession(weekNumber: week, status: status)
        context.insert(session)
        session.program = self
        session.day = day
        if status != .inProgress {
            session.completedAt = Date.now
        }

        for (index, (slot, weight)) in zip(slots, prescribed).enumerated() {
            let log = ExerciseLog(
                order: index,
                exerciseName: slot.name,
                prescribedWeight: weight,
                targetSets: slot.targetSets,
                targetReps: slot.targetReps,
                catalogID: slot.catalogID
            )
            context.insert(log)
            log.session = session
            log.slot = slot
        }
        return session
    }
}

extension WorkoutSession {
    func complete() {
        status = .completed
        completedAt = Date.now
    }
}

extension ExerciseLog {
    /// Appends a set. Defaults to the prescribed weight.
    @discardableResult
    func logSet(reps: Int, weight: Weight? = nil, in context: ModelContext) -> SetLog {
        let set = SetLog(order: sets?.count ?? 0, reps: reps, weight: weight ?? prescribedWeight)
        context.insert(set)
        set.exerciseLog = self
        return set
    }

    /// Deletes a set and renumbers the ones after it.
    func removeSet(_ set: SetLog, in context: ModelContext) {
        let remaining = sortedSets.filter { $0.persistentModelID != set.persistentModelID }
        // Detach first so `sets` is accurate before the delete is saved.
        set.exerciseLog = nil
        context.delete(set)
        for (index, set) in remaining.enumerated() {
            set.order = index
        }
    }
}
