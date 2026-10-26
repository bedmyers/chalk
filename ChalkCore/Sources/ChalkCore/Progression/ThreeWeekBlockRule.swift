/// Progress in blocks of three completed weeks.
///
/// - Each week of a block has its own rep target: the same reps every week, or a
///   rep wave such as 6/8/10 (`ExerciseTarget.repsByWeek`).
/// - A week is a hit only if the first `target.sets` sets of every scheduled session
///   reach that week's reps. Extra sets beyond the target are ignored.
/// - Weeks are training weeks, not calendar weeks: a week counts the moment its last
///   scheduled session is logged. Skipped and in-progress weeks pause the block.
///   A missed week doesn't stop the block; the next week's target comes next.
/// - After three completed weeks the block closes and the next one starts at week 1.
///   All hits: the weight increases by the exercise's increment, rounded up to a
///   loadable weight. Otherwise it holds.
/// - After `failedBlocksBeforeDeload` failed blocks in a row, the weight drops by
///   `deloadFraction` (rounded to a loadable weight) and the failure count resets.
/// - Bodyweight lifts have no weight to change. A passed block adds a rep to every
///   week of the wave instead (6/8/10 → 7/9/11), and a deload takes one away,
///   never below the original wave.
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
        /// Reps a bodyweight lift has earned on top of its original wave.
        public var extraReps: Int
        public var blocks: [BlockResult]
        /// Completed weeks of the block still in progress.
        public var openBlockWeeks: [WeekOutcome]
        public var consecutiveFailedBlocks: Int
    }

    /// How a week counts, judged against week 1's reps of the block.
    public func outcome(of week: WeekResult, target: ExerciseTarget) -> WeekOutcome {
        outcome(of: week, target: target, reps: target.reps(inBlockWeek: 0))
    }

    /// How a week counts, judged against `reps` per set.
    public func outcome(of week: WeekResult, target: ExerciseTarget, reps: Int) -> WeekOutcome {
        switch week {
        case .skipped:
            return .skipped
        case .logged(let sessions):
            guard sessions.count >= target.sessionsPerWeek else { return .inProgress }
            // Only the first `target.sets` sets count; extra sets are recorded but ignored.
            let allHit = sessions.allSatisfy { session in
                session.sets.count >= target.sets
                    && session.sets.prefix(target.sets).allSatisfy { $0.reps >= reps }
            }
            return allHit ? .hit : .miss
        }
    }

    public func replay(_ input: ProgressionInput) -> Replay {
        let ladder = input.loading.ladder(for: input.target.equipment)
        let isWeighted = input.target.equipment.isWeighted
        var state = Replay(
            weight: input.startingWeight,
            extraReps: 0,
            blocks: [],
            openBlockWeeks: [],
            consecutiveFailedBlocks: 0
        )

        for week in input.history {
            let reps = input.target.reps(inBlockWeek: state.openBlockWeeks.count, extraReps: state.extraReps)
            let weekOutcome = outcome(of: week, target: input.target, reps: reps)
            guard weekOutcome == .hit || weekOutcome == .miss else { continue }

            state.openBlockWeeks.append(weekOutcome)
            guard state.openBlockWeeks.count == Self.weeksPerBlock else { continue }

            let weight = state.weight
            let extraReps = state.extraReps
            let event: ProgressionEvent
            if state.openBlockWeeks.allSatisfy({ $0 == .hit }) {
                state.consecutiveFailedBlocks = 0
                event = isWeighted
                    ? .increased(from: weight, to: ladder.increased(weight, by: input.target.increment))
                    : .repsRaised(from: extraReps, to: extraReps + 1)
            } else {
                state.consecutiveFailedBlocks += 1
                if state.consecutiveFailedBlocks >= failedBlocksBeforeDeload {
                    state.consecutiveFailedBlocks = 0
                    event = deloadEvent(weight: weight, extraReps: extraReps, isWeighted: isWeighted, ladder: ladder)
                } else {
                    event = .held(weight)
                }
            }

            state.blocks.append(BlockResult(
                weight: weight,
                extraReps: extraReps,
                weeks: state.openBlockWeeks,
                event: event
            ))
            switch event {
            case .repsRaised(_, let to), .repsLowered(_, let to): state.extraReps = to
            case .held(let to), .increased(_, let to), .deloaded(_, let to): state.weight = to
            }
            state.openBlockWeeks = []
        }

        return state
    }

    /// One step easier: ~`deloadFraction` lighter, or one rep fewer per week for
    /// bodyweight lifts. Holds when there's nothing lighter to drop to.
    private func deloadEvent(
        weight: Weight,
        extraReps: Int,
        isWeighted: Bool,
        ladder: any WeightLadder
    ) -> ProgressionEvent {
        if isWeighted {
            let lighter = ladder.deloaded(weight, by: deloadFraction)
            return lighter < weight ? .deloaded(from: weight, to: lighter) : .held(weight)
        }
        // Never below the wave the user set up.
        return extraReps > 0 ? .repsLowered(from: extraReps, to: extraReps - 1) : .held(weight)
    }

    public func evaluate(_ input: ProgressionInput) -> ProgressionOutcome {
        let state = replay(input)
        let blockWeek = state.openBlockWeeks.count
        return ProgressionOutcome(
            nextWeight: state.weight,
            nextReps: input.target.reps(inBlockWeek: blockWeek, extraReps: state.extraReps),
            extraReps: state.extraReps,
            events: state.blocks.map(\.event),
            cycle: CycleProgress(week: blockWeek + 1, length: Self.weeksPerBlock)
        )
    }
}
