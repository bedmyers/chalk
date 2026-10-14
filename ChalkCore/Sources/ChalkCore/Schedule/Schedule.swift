/// A position in a program: a training week and a day within it.
public struct ScheduledWorkout: Sendable, Hashable, Comparable {
    /// 1-based training week.
    public var week: Int
    /// 0-based index into the program's ordered days.
    public var day: Int

    public init(week: Int, day: Int) {
        self.week = week
        self.day = day
    }

    public static func < (lhs: ScheduledWorkout, rhs: ScheduledWorkout) -> Bool {
        (lhs.week, lhs.day) < (rhs.week, rhs.day)
    }
}

/// Decides what to train next. Weeks are training weeks, not calendar weeks.
public enum Schedule {
    /// The earliest unfinished day of the earliest unfinished week, or nil if the
    /// program has no days. Completed and skipped sessions both count as finished,
    /// so a missed day stays next until it's logged or skipped.
    public static func nextWorkout(dayCount: Int, finished: Set<ScheduledWorkout>) -> ScheduledWorkout? {
        guard dayCount > 0 else { return nil }
        // Terminates because `finished` is finite.
        var week = 1
        while true {
            if let day = (0..<dayCount).first(where: { !finished.contains(ScheduledWorkout(week: week, day: $0)) }) {
                return ScheduledWorkout(week: week, day: day)
            }
            week += 1
        }
    }

    /// The days of `week` not yet finished, in order. Skipping a week means skipping these.
    public static func remainingDays(
        inWeek week: Int,
        dayCount: Int,
        finished: Set<ScheduledWorkout>
    ) -> [ScheduledWorkout] {
        (0..<max(dayCount, 0))
            .map { ScheduledWorkout(week: week, day: $0) }
            .filter { !finished.contains($0) }
    }
}
