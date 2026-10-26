//
//  WorkoutLogic.swift
//  Chalk
//
//  The rules behind full-screen workout mode, kept out of the views so they're testable.
//

import ChalkCore
import Foundation
import SwiftData
import UserNotifications

/// What tapping a set button did.
nonisolated enum SetTapResult: Equatable, Sendable {
    /// A new set was logged. `finishedExercise` is true when it was the last target set.
    case logged(finishedExercise: Bool)
    /// An already-logged set's reps were adjusted.
    case adjusted
    /// The exercise isn't in today's session.
    case ignored
}

extension Program {
    /// Logs or adjusts set `index` of `slot` in `day`'s session, starting the session
    /// on the first tap. Empty sets log the target reps; logged sets count down.
    @discardableResult
    func tapSet(_ index: Int, of slot: ExerciseSlot, day: ProgramDay, week: Int, in context: ModelContext) -> SetTapResult {
        let session = startSession(for: day, week: week, in: context)
        guard let log = session.sortedExerciseLogs.first(where: {
            $0.slot?.persistentModelID == slot.persistentModelID
        }) else { return .ignored }

        let sets = log.sortedSets
        if sets.indices.contains(index) {
            sets[index].reps = SetTap.reps(afterTapping: sets[index].reps, target: log.targetReps)
            return .adjusted
        }
        log.logSet(reps: log.targetReps, in: context)
        return .logged(finishedExercise: sets.count + 1 == log.targetSets)
    }
}

extension PlannedExercise {
    /// Every target set is logged.
    var isDone: Bool { sets.count >= targetSets }
}

/// A page in workout mode: one per lift, then the summary.
nonisolated enum WorkoutPage: Hashable, Sendable {
    case exercise(UUID)
    case summary
}

nonisolated enum WorkoutPager {
    /// Where to go after finishing the lift `current`: the next unfinished lift
    /// below it, then any unfinished lift above it, then the summary.
    static func page(after current: UUID, ids: [UUID], done: Set<UUID>) -> WorkoutPage {
        let start = (ids.firstIndex(of: current) ?? -1) + 1
        let order = ids[min(start, ids.count)...] + ids[..<min(start, ids.count)]
        return order.first { !done.contains($0) }.map(WorkoutPage.exercise) ?? .summary
    }

    /// Where to open: the first unfinished lift, or the summary if everything's done.
    static func firstPage(ids: [UUID], done: Set<UUID>) -> WorkoutPage {
        ids.first { !done.contains($0) }.map(WorkoutPage.exercise) ?? .summary
    }
}

/// The rest between sets. Stores when rest ends rather than counting down, so it
/// stays right while the phone is locked or the app is in the background.
nonisolated struct RestTimer: Equatable, Sendable {
    private(set) var endsAt: Date?

    /// Seconds left, or nil if no rest is running.
    func remaining(at now: Date) -> TimeInterval? {
        guard let endsAt, endsAt > now else { return nil }
        return endsAt.timeIntervalSince(now)
    }

    mutating func start(_ duration: TimeInterval, now: Date = .now) {
        endsAt = now.addingTimeInterval(duration)
    }

    /// Adds time to the running rest, or starts one.
    mutating func add(_ seconds: TimeInterval, now: Date = .now) {
        endsAt = max(endsAt ?? now, now).addingTimeInterval(seconds)
    }

    mutating func stop() {
        endsAt = nil
    }

    /// Default rest: 2:30 for barbell lifts, 1:30 for everything else.
    static func defaultDuration(for equipment: Equipment) -> TimeInterval {
        equipment == .barbell ? 150 : 90
    }

    /// "2:30", rounding up so it never shows 0:00 while time is left.
    static func text(_ remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}

/// A local notification for when rest ends, so a locked phone still says "go".
enum RestAlert {
    private static let id = "chalk.rest"

    /// Asks for permission the first time, then replaces any pending alert.
    static func schedule(at date: Date) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Rest's over!"
        content.body = "Next set. And up!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
