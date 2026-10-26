//
//  WorkoutModeView.swift
//  Chalk
//
//  The workout one lift at a time. Each lift fills the screen with its weight and
//  big set buttons; swipe up for the next. A rail on the side shows what's done
//  and jumps anywhere. The last page finishes the workout.
//

import ChalkCore
import SwiftData
import SwiftUI

struct WorkoutModeView: View {
    let program: Program
    let day: ProgramDay
    let week: Int
    /// Owned by Today, so rest keeps running if you step back to the list.
    @Binding var rest: RestTimer
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: WorkoutPage?
    @State private var setTaps = 0
    @State private var restsFinished = 0

    var body: some View {
        let plan = TodayPlan(program: program, day: day, week: week)
        GeometryReader { proxy in
            ZStack {
                pages(plan, insets: proxy.safeAreaInsets)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar(plan)
                    Spacer(minLength: 0)
                    RestBar(rest: $rest)
                }

                ProgressRail(plan: plan, page: page) { target in
                    go(to: target)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .background(Theme.Colors.background)
        .sensoryFeedback(.impact(weight: .medium), trigger: setTaps)
        .sensoryFeedback(.success, trigger: restsFinished)
        .task(id: rest.endsAt) {
            // Buzz when rest ends while the app is open; the notification covers a locked phone.
            guard let remaining = rest.remaining(at: .now) else { return }
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            restsFinished += 1
        }
        .onAppear {
            if page == nil {
                page = WorkoutPager.firstPage(ids: plan.exercises.map(\.id), done: doneIDs(plan))
            }
            // Keep the screen on between sets.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func pages(_ plan: TodayPlan, insets: EdgeInsets) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, exercise in
                    LiftPage(
                        exercise: exercise,
                        number: index + 1,
                        count: plan.exercises.count,
                        isMainLift: index == 0,
                        insets: insets,
                        onTapSet: { tap(exercise, at: $0) },
                        onClearSet: clear
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(WorkoutPage.exercise(exercise.id))
                }

                WorkoutSummaryPage(plan: plan, insets: insets, onFinish: finish)
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(WorkoutPage.summary)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
    }

    private func topBar(_ plan: TodayPlan) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "list.bullet")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surface, in: Circle())
            }
            .accessibilityLabel("Back to list")

            Text(eyebrow(plan)).eyebrowStyle()
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 4)
    }

    /// "PUSH A · WEEK 2 OF 3", using the main lift's block position.
    private func eyebrow(_ plan: TodayPlan) -> String {
        guard let cycle = plan.cycle else { return "\(day.name) · Week \(week)" }
        return "\(day.name) · Week \(cycle.week) of \(cycle.length)"
    }

    private func doneIDs(_ plan: TodayPlan) -> Set<UUID> {
        Set(plan.exercises.filter(\.isDone).map(\.id))
    }

    // MARK: - Actions

    private func tap(_ exercise: PlannedExercise, at index: Int) {
        let result = program.tapSet(index, of: exercise.slot, day: day, week: week, in: modelContext)
        setTaps += 1
        guard case .logged(let finishedExercise) = result else { return }

        rest.start(RestTimer.defaultDuration(for: exercise.slot.equipment))
        if let endsAt = rest.endsAt {
            Task { await RestAlert.schedule(at: endsAt) }
        }

        if finishedExercise {
            // Let the last set's tap land before sliding to the next lift.
            let plan = TodayPlan(program: program, day: day, week: week)
            let next = WorkoutPager.page(after: exercise.id, ids: plan.exercises.map(\.id), done: doneIDs(plan))
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                go(to: next)
            }
        }
    }

    private func go(to target: WorkoutPage) {
        withAnimation(reduceMotion ? nil : .snappy) {
            page = target
        }
    }

    private func clear(_ set: SetLog) {
        set.exerciseLog?.removeSet(set, in: modelContext)
    }

    private func finish() {
        rest.stop()
        RestAlert.cancel()
        onFinish()
        dismiss()
    }
}

// MARK: - Lift page

/// One lift, filling the screen: name, target, a weight you can read from the
/// floor, and big set buttons. Nothing scrolls inside, so swipes always page.
private struct LiftPage: View {
    /// Side padding that also clears the progress rail on the right.
    static let contentInsets = EdgeInsets(top: 0, leading: Theme.Metrics.screenPadding, bottom: 0, trailing: Theme.Metrics.screenPadding + 36)

    let exercise: PlannedExercise
    let number: Int
    let count: Int
    let isMainLift: Bool
    let insets: EdgeInsets
    let onTapSet: (Int) -> Void
    let onClearSet: (SetLog) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isMainLift {
                LeotardStripe(stripeWidth: 20)
                    .frame(height: 14)
                    .padding(.bottom, 16)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Lift \(number) of \(count)").eyebrowStyle()
                Text(exercise.name)
                    .font(Theme.Fonts.focusName)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                Text("\(exercise.targetSets) × \(exercise.targetReps)")
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Self.contentInsets)

            Spacer(minLength: 12)

            weight
                .padding(Self.contentInsets)

            Spacer(minLength: 12)

            setGrid
                .padding(Self.contentInsets)
        }
        // Clear the top bar and rest bar overlays.
        .padding(.top, insets.top + 64)
        .padding(.bottom, insets.bottom + 124)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var weight: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(exercise.isWeighted ? exercise.weight.formattedValue : WeightLabel.bodyweight)
                .font(Theme.Fonts.focusWeight)
                .foregroundStyle(Theme.Colors.weight)
                .popShadow()
            if exercise.isWeighted {
                Text(exercise.weight.unit.symbol)
                    .font(Theme.Fonts.unit)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exercise.isWeighted ? exercise.weight.description : "Bodyweight")
    }

    private var setGrid: some View {
        let total = max(exercise.targetSets, exercise.sets.count)
        // One more empty button past the target, for an extra set.
        let shown = exercise.isDone ? total + 1 : total
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            ForEach(0..<shown, id: \.self) { index in
                let set = exercise.sets.indices.contains(index) ? exercise.sets[index] : nil
                SetButton(
                    number: index + 1,
                    reps: set?.reps,
                    targetReps: exercise.targetReps,
                    size: 68,
                    onTap: { onTapSet(index) },
                    onClear: set.map { set in { onClearSet(set) } }
                )
                .opacity(index >= total ? 0.5 : 1)
            }
        }
    }
}

// MARK: - Summary page

/// The last page: what's done, and the button that finishes the workout.
private struct WorkoutSummaryPage: View {
    let plan: TodayPlan
    let insets: EdgeInsets
    let onFinish: () -> Void

    private var unfinished: Int { plan.exercises.filter { !$0.isDone }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("That's a wrap!")
                .font(Theme.Fonts.screenTitle)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textPrimary)
                .popShadow()
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(plan.exercises) { exercise in
                    HStack {
                        Text(exercise.name).exerciseNameStyle()
                            .lineLimit(1)
                        Spacer()
                        Text("\(min(exercise.sets.count, exercise.targetSets))/\(exercise.targetSets)")
                            .font(Theme.Fonts.target)
                            .foregroundStyle(exercise.isDone ? Theme.Colors.done : Theme.Colors.textSecondary)
                        Image(systemName: exercise.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(exercise.isDone ? Theme.Colors.done : Theme.Colors.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(exercise.name), \(exercise.isDone ? "done" : "\(exercise.sets.count) of \(exercise.targetSets) sets")")
                }
            }
            .padding(20)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Metrics.cardCornerRadius))

            if unfinished > 0 {
                Text(unfinished == 1
                     ? "One lift isn't finished. Finishing now counts it as a miss this week."
                     : "\(unfinished) lifts aren't finished. Finishing now counts them as a miss this week.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            Button("Finish Workout", action: onFinish)
                .buttonStyle(.chalkPrimary)
                .disabled(plan.session == nil)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.trailing, 36)
        .padding(.top, insets.top + 64)
        .padding(.bottom, insets.bottom + 124)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Progress rail

/// One dot per lift, then a flag for the summary. Teal when done; tap to jump.
private struct ProgressRail: View {
    let plan: TodayPlan
    let page: WorkoutPage?
    let onSelect: (WorkoutPage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(plan.exercises) { exercise in
                dot(for: .exercise(exercise.id), isDone: exercise.isDone, isStarted: !exercise.sets.isEmpty)
                    .accessibilityLabel("\(exercise.name), \(exercise.isDone ? "done" : "\(exercise.sets.count) of \(exercise.targetSets) sets")")
            }
            Button {
                onSelect(.summary)
            } label: {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(page == .summary ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .frame(width: 44, height: 36)
            }
            .accessibilityLabel("Finish")
        }
        .padding(.vertical, 6)
        .background(Theme.Colors.surface.opacity(0.85), in: Capsule())
        .padding(.trailing, 4)
    }

    private func dot(for target: WorkoutPage, isDone: Bool, isStarted: Bool) -> some View {
        let isCurrent = page == target
        return Button {
            onSelect(target)
        } label: {
            Circle()
                .fill(isDone ? Theme.Colors.done : (isStarted ? Theme.Colors.textSecondary : Theme.Colors.border))
                .frame(width: isCurrent ? 14 : 10, height: isCurrent ? 14 : 10)
                .overlay {
                    if isCurrent {
                        Circle().strokeBorder(Theme.Colors.textPrimary, lineWidth: 2)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isCurrent)
    }
}

// MARK: - Rest bar

/// The rest countdown, pinned to the bottom while it runs.
private struct RestBar: View {
    @Binding var rest: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let remaining = rest.remaining(at: context.date) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Rest").eyebrowStyle()
                        Text(RestTimer.text(remaining))
                            .font(Theme.Fonts.timer)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rest, \(RestTimer.text(remaining)) left")

                    Spacer()

                    Button("+30s") { add(30) }
                        .font(Theme.Fonts.button)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(minWidth: 64, minHeight: 48)
                        .background(Theme.Colors.border, in: Capsule())
                        .accessibilityLabel("Add 30 seconds")

                    Button("Skip") { skip() }
                        .font(Theme.Fonts.button)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.onFill)
                        .frame(minWidth: 72, minHeight: 48)
                        .background(Theme.Colors.action, in: Capsule())
                        .accessibilityLabel("Skip rest")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Metrics.cardCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                        .strokeBorder(Theme.Colors.border, lineWidth: 1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: rest)
    }

    private func add(_ seconds: TimeInterval) {
        rest.add(seconds)
        if let endsAt = rest.endsAt {
            Task { await RestAlert.schedule(at: endsAt) }
        }
    }

    private func skip() {
        rest.stop()
        RestAlert.cancel()
    }
}

#if DEBUG
private struct WorkoutModePreview: View {
    let program: Program
    @State var rest = RestTimer()

    var body: some View {
        if let next = program.nextWorkout() {
            WorkoutModeView(program: program, day: next.day, week: next.week, rest: $rest, onFinish: {})
        }
    }
}

#Preview("Workout mode") {
    let container = SampleData.previewContainer(setsLogged: [8, 8])
    let program = ProgramLibrary.activePrograms(in: container.mainContext)[0]
    return WorkoutModePreview(program: program)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Resting") {
    let container = SampleData.previewContainer(setsLogged: [8, 8])
    let program = ProgramLibrary.activePrograms(in: container.mainContext)[0]
    var rest = RestTimer()
    rest.start(102)
    return WorkoutModePreview(program: program, rest: rest)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
#endif
