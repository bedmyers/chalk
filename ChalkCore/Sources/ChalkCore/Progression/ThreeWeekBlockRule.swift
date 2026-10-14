/// Progress in blocks of three completed weeks.
///
/// - A week is a hit only if the first `target.sets` sets of every scheduled session
///   reach the target reps. Extra sets beyond the target are ignored.
/// - Weeks are training weeks, not calendar weeks: a week counts the moment its last
///   scheduled session is logged. Skipped and in-progress weeks pause the block.
/// - After three completed weeks the block closes. All hits: the weight increases
///   by the exercise's increment, rounded up to a loadable weight. Otherwise it holds.
/// - After `failedBlocksBeforeDeload` failed blocks in a row, the weight drops by
///   `deloadFraction` (rounded to a loadable weight) and the failure count resets.
public struct ThreeWeekBlockRule: ProgressionRule, Hashable {
    public static let weeksPerBlock = 3

    public var failedBlocksBeforeDeload: Int
    public var deloadFraction: Double

    public init(failedBlocksBeforeDeload: Int = 2, deloadFraction: Double = 0.10) {
        self.failedBlocksBeforeDeload = failedBlocksBeforeDeload
        self.deloadFraction = deloadFraction
    }

    /// The full state after replaying history.
    public struct Replay: Sendable, Hashable {
        public var weight: Weight
        public var blocks: [BlockResult]
        /// Completed weeks of the block still in progress.
        public var openBlockWeeks: [WeekOutcome]
        public var consecutiveFailedBlocks: Int
    }

    public func outcome(of week: WeekResult, target: ExerciseTarget) -> WeekOutcome {
        switch week {
        case .skipped:
            return .skipped
        case .logged(let sessions):
            guard sessions.count >= target.sessionsPerWeek else { return .inProgress }
            // Only the first `target.sets` sets count; extra sets are recorded but ignored.
            let allHit = sessions.allSatisfy { session in
                session.sets.count >= target.sets
                    && session.sets.prefix(target.sets).allSatisfy { $0.reps >= target.reps }
            }
            return allHit ? .hit : .miss
        }
    }

    public func replay(_ input: ProgressionInput) -> Replay {
        let ladder = input.loading.ladder(for: input.target.equipment)
        var state = Replay(
            weight: input.startingWeight,
            blocks: [],
            openBlockWeeks: [],
            consecutiveFailedBlocks: 0
        )

        for week in input.history {
            let weekOutcome = outcome(of: week, target: input.target)
            guard weekOutcome == .hit || weekOutcome == .miss else { continue }

            state.openBlockWeeks.append(weekOutcome)
            guard state.openBlockWeeks.count == Self.weeksPerBlock else { continue }

            let weight = state.weight
            let event: ProgressionEvent
            if state.openBlockWeeks.allSatisfy({ $0 == .hit }) {
                state.consecutiveFailedBlocks = 0
                event = .increased(from: weight, to: ladder.increased(weight, by: input.target.increment))
            } else {
                state.consecutiveFailedBlocks += 1
                if state.consecutiveFailedBlocks >= failedBlocksBeforeDeload {
                    state.consecutiveFailedBlocks = 0
                    let lighter = ladder.deloaded(weight, by: deloadFraction)
                    // Already at the lightest loadable weight: nothing to drop to.
                    event = lighter < weight ? .deloaded(from: weight, to: lighter) : .held(weight)
                } else {
                    event = .held(weight)
                }
            }

            state.blocks.append(BlockResult(weight: weight, weeks: state.openBlockWeeks, event: event))
            state.weight = event.resultingWeight
            state.openBlockWeeks = []
        }

        return state
    }

    public func evaluate(_ input: ProgressionInput) -> ProgressionOutcome {
        let state = replay(input)
        return ProgressionOutcome(
            nextWeight: state.weight,
            events: state.blocks.map(\.event),
            cycle: CycleProgress(week: state.openBlockWeeks.count + 1, length: Self.weeksPerBlock)
        )
    }
}
