/// One finished session as it affects a single exercise slot.
public struct SlotSession: Sendable, Hashable {
    public enum Status: Sendable, Hashable {
        /// The session was completed. `sets` is empty if the exercise was dropped.
        case completed(sets: [SetResult])
        /// The user skipped the session's day.
        case skipped
    }

    public var week: Int
    public var status: Status

    public init(week: Int, status: Status) {
        self.week = week
        self.status = status
    }
}

/// Turns a slot's finished sessions into the weekly history the engine replays.
public enum TrainingWeeks {
    /// Groups sessions by training week, oldest first.
    ///
    /// - If every session of a week was skipped, the week is `.skipped` and pauses the block
    ///   (a skipped day or a whole skipped week, from this slot's point of view).
    /// - Otherwise skipped sessions count as sessions with no sets, as do dropped exercises,
    ///   so the week is a miss once all its scheduled sessions are in.
    public static func history(from sessions: [SlotSession]) -> [WeekResult] {
        Dictionary(grouping: sessions, by: \.week)
            .sorted { $0.key < $1.key }
            .map { _, sessions in
                if sessions.allSatisfy({ $0.status == .skipped }) {
                    return .skipped
                }
                return .logged(sessions.map { session in
                    switch session.status {
                    case .completed(let sets): SessionResult(sets: sets)
                    case .skipped: SessionResult(sets: [])
                    }
                })
            }
    }
}
