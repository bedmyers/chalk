//
//  TodayView.swift
//  Chalk
//
//  Open the app → today's workout is pre-filled → tap through sets.
//

import ChalkCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(filter: #Predicate<Program> { $0.archivedAt == nil }, sort: \Program.createdAt)
    private var programs: [Program]

    var body: some View {
        Group {
            if let program = programs.first {
                TodayWorkoutView(program: program)
            } else {
                NoProgramView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
}

struct TodayWorkoutView: View {
    let program: Program

    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingSkip = false
    @State private var setTaps = 0

    var body: some View {
        if let next = program.nextWorkout() {
            workout(TodayPlan(program: program, day: next.day, week: next.week))
        } else {
            EmptyStateView(title: "No days yet", message: "Add a day to \(program.name) to get started.")
        }
    }

    private func workout(_ plan: TodayPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(plan)
                    .padding(.bottom, 8)

                ForEach(plan.exercises) { exercise in
                    ExerciseCard(
                        exercise: exercise,
                        isFeatured: exercise.id == plan.exercises.first?.id,
                        onTapSet: { tapSet(exercise, at: $0, in: plan) },
                        onClearSet: clear
                    )
                }

                VStack(spacing: 8) {
                    Button("Finish Workout") {
                        plan.session?.complete()
                    }
                    .buttonStyle(.chalkPrimary)
                    .disabled(plan.session == nil)

                    Button("Skip This Day") {
                        isConfirmingSkip = true
                    }
                    .buttonStyle(.chalkSecondary)
                }
                .padding(.top, 8)
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.impact(weight: .medium), trigger: setTaps)
        .confirmationDialog("Skip \(plan.day.name)?", isPresented: $isConfirmingSkip, titleVisibility: .visible) {
            Button("Skip Day", role: .destructive) {
                program.skip(plan.day, week: plan.week, in: modelContext)
            }
        } message: {
            Text("You'll move on to the next day.")
        }
    }

    private func header(_ plan: TodayPlan) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow(plan)).eyebrowStyle()
                Text(plan.day.name)
                    .font(Theme.Fonts.screenTitle)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .popShadow()
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.trailing, 96)
            .frame(maxWidth: .infinity, alignment: .leading)

            MemphisCluster()
        }
    }

    /// "TUE · WEEK 2 OF 3", using the main lift's block position.
    private func eyebrow(_ plan: TodayPlan) -> String {
        let weekday = Date.now.formatted(.dateTime.weekday(.abbreviated))
        guard let cycle = plan.cycle else { return "\(weekday) · Week \(plan.week)" }
        return "\(weekday) · Week \(cycle.week) of \(cycle.length)"
    }

    // MARK: - Actions

    /// Starts the session on the first tap, then logs or adjusts the set.
    private func tapSet(_ exercise: PlannedExercise, at index: Int, in plan: TodayPlan) {
        let session = program.startSession(for: plan.day, week: plan.week, in: modelContext)
        guard let log = session.sortedExerciseLogs.first(where: {
            $0.slot?.persistentModelID == exercise.slot.persistentModelID
        }) else { return }

        let sets = log.sortedSets
        if sets.indices.contains(index) {
            sets[index].reps = SetTap.reps(afterTapping: sets[index].reps, target: log.targetReps)
        } else {
            log.logSet(reps: log.targetReps, in: modelContext)
        }
        setTaps += 1
    }

    private func clear(_ set: SetLog) {
        set.exerciseLog?.removeSet(set, in: modelContext)
    }
}

/// Shown when there's no active program.
struct NoProgramView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        EmptyStateView(
            title: "No program yet",
            message: "Set up your program and starting weights once. Chalk handles the rest."
        ) {
            #if DEBUG
            Button("Load Sample Program") {
                SampleData.insertProgram(into: modelContext)
            }
            .buttonStyle(.chalkPrimary)
            #endif
        }
    }
}

struct EmptyStateView<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(Theme.Fonts.screenTitle)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textPrimary)
                .popShadow()
            Text(message)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            actions
                .padding(.top, 8)
        }
        .padding(Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(title: String, message: String) {
        self.init(title: title, message: message) { EmptyView() }
    }
}

#if DEBUG
#Preview("Today") {
    TodayView()
        .modelContainer(SampleData.previewContainer())
        .preferredColorScheme(.dark)
}

#Preview("Mid-workout") {
    TodayView()
        .modelContainer(SampleData.previewContainer(setsLogged: [8, 8]))
        .preferredColorScheme(.dark)
}

#Preview("No program") {
    TodayView()
        .modelContainer(try! ChalkModelContainer.make(inMemory: true))
        .preferredColorScheme(.dark)
}
#endif
