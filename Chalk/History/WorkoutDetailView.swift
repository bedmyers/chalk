//
//  WorkoutDetailView.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// One finished workout's sets, with editing for completed workouts.
struct WorkoutDetailView: View {
    let session: WorkoutSession

    @State private var isEditing = false

    var body: some View {
        List {
            Section {
                Text(summary)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if session.status == .skipped {
                    Text("This day was skipped.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .chalkRow()

            // Skipped days show no exercise sections; the note above says why.
            ForEach(session.status == .skipped ? [] : session.sortedExerciseLogs) { log in
                Section {
                    if log.sortedSets.isEmpty {
                        Text("No sets logged")
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .chalkRow()
                    }
                    ForEach(log.sortedSets) { set in
                        // `order` is 0-based and renumbered on every add or delete.
                        SetHistoryRow(number: set.order + 1, set: set, targetReps: log.targetReps)
                            .chalkRow()
                    }
                } header: {
                    Text(log.exerciseName)
                } footer: {
                    Text("Prescribed \(log.prescribedWeight.description) · \(log.targetSets) × \(log.targetReps)")
                }
            }
        }
        .chalkListStyle()
        .navigationTitle(session.day?.name ?? "Workout")
        .toolbar {
            if session.status == .completed {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditWorkoutSheet(session: session)
        }
    }

    private var summary: String {
        let date = (session.completedAt ?? session.startedAt).formatted(date: .complete, time: .omitted)
        var parts = [date]
        if let program = session.program {
            parts.append(program.name)
        }
        parts.append("Week \(session.weekNumber)")
        return parts.joined(separator: " · ")
    }
}

private struct SetHistoryRow: View {
    let number: Int
    let set: SetLog
    let targetReps: Int

    var body: some View {
        let hit = set.reps >= targetReps
        HStack {
            Text("Set \(number)")
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Label("\(set.reps) reps", systemImage: hit ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(hit ? Theme.Colors.done : Theme.Colors.textPrimary)
            Text(set.weight.description)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
// TODO: This preview crashes in Xcode Previews ("Could not cast value of type
// 'UICollectionViewCell' to 'SwiftUI.AnyListCollectionViewCell'"). The screen works
// in the app (covered by HistoryUITests). A scratch copy with the same structure
// rendered, so the trigger is still unknown. EditWorkoutSheet's preview does the same.
#Preview("Detail") {
    let container = SampleData.previewContainer(completedWeeks: 1)
    let session = HistoryQueries.finishedSessions(in: container.mainContext).last!
    return NavigationStack {
        WorkoutDetailView(session: session)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
#endif
