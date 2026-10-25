//
//  HistoryView.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// Past workouts (every program) and exercises (active program).
struct HistoryView: View {
    private enum Tab: String, CaseIterable {
        case workouts = "Workouts"
        case exercises = "Exercises"
    }

    @State private var tab = Tab.workouts

    var body: some View {
        Group {
            switch tab {
            case .workouts: WorkoutsListView()
            case .exercises: ExercisesListView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .safeAreaInset(edge: .top) {
            Picker("Show", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 8)
        }
        .navigationTitle("History")
    }
}

// MARK: - Workouts

/// Completed and skipped workouts from every program, newest first.
struct WorkoutsListView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.statusRaw != "inProgress" },
           sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    var body: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(value: Route.workout(session)) {
                    WorkoutRow(session: session)
                }
            }
            .chalkRow()
        }
        .chalkListStyle()
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Finished workouts show up here.")
                )
            }
        }
    }
}

private struct WorkoutRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.day?.name ?? "Deleted day").exerciseNameStyle()
                Text(caption)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(summary)
                .font(Theme.Fonts.target)
                .foregroundStyle(session.status == .skipped ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
        }
        .padding(.vertical, 4)
    }

    /// Date, program, and training week, e.g. "Oct 24 · Push Pull Legs · Week 2".
    private var caption: String {
        let date = (session.completedAt ?? session.startedAt).formatted(.dateTime.month(.abbreviated).day())
        var parts = [date]
        if let program = session.program {
            parts.append(program.name)
        }
        parts.append("Week \(session.weekNumber)")
        return parts.joined(separator: " · ")
    }

    private var summary: String {
        guard session.status == .completed else { return "Skipped" }
        let sets = session.sortedExerciseLogs.reduce(0) { $0 + ($1.sets?.count ?? 0) }
        return sets == 1 ? "1 set" : "\(sets) sets"
    }
}

// MARK: - Exercises

/// The active program's exercises, in the order they appear across its days.
struct ExercisesListView: View {
    @Query(filter: #Predicate<Program> { $0.archivedAt == nil }, sort: \Program.createdAt)
    private var programs: [Program]

    private var slots: [ExerciseSlot] {
        guard let program = programs.first else { return [] }
        var seen = Set<PersistentIdentifier>()
        return program.sortedDays
            .flatMap(\.sortedEntries)
            .compactMap(\.slot)
            .filter { !$0.isArchived && seen.insert($0.persistentModelID).inserted }
    }

    var body: some View {
        List {
            ForEach(slots) { slot in
                NavigationLink(value: Route.exerciseHistory(slot)) {
                    ExerciseHistoryRow(slot: slot)
                }
            }
            .chalkRow()
        }
        .chalkListStyle()
        .overlay {
            if slots.isEmpty {
                ContentUnavailableView(
                    "No exercises",
                    systemImage: "dumbbell",
                    description: Text("Your active program's exercises show up here.")
                )
            }
        }
    }
}

private struct ExerciseHistoryRow: View {
    let slot: ExerciseSlot

    var body: some View {
        let outcome = slot.progression()
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.name).exerciseNameStyle()
                Text(caption(outcome))
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text(outcome.nextWeight.formattedValue)
                .font(Theme.Fonts.rowWeight)
                .foregroundStyle(Theme.Colors.weight)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func caption(_ outcome: ProgressionOutcome) -> String {
        var parts = ["\(slot.targetSets) × \(slot.targetReps)"]
        if let cycle = outcome.cycle {
            parts.append("Week \(cycle.week) of \(cycle.length)")
        }
        return parts.joined(separator: " · ")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(Router())
    .modelContainer(SampleData.previewContainer(completedWeeks: 3))
    .preferredColorScheme(.dark)
}
#endif
