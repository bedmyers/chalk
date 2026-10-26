//
//  EditWorkoutSheet.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// Edits a finished workout's sets: reps, weight lifted, adding a missed set,
/// deleting a set. If the edit changes any current weight, asks first and
/// names each change (e.g. "Bench Press 190 → 185 lb").
struct EditWorkoutSheet: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutDraft
    @State private var pendingChanges: [WeightChange] = []

    init(session: WorkoutSession) {
        self.session = session
        _draft = State(initialValue: session.draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach($draft.exercises) { $exercise in
                    Section {
                        ForEach($exercise.sets) { $set in
                            SetEditRow(set: $set, targetReps: exercise.targetReps, isWeighted: exercise.isWeighted)
                                .chalkRow()
                        }
                        .onDelete { exercise.sets.remove(atOffsets: $0) }

                        Button("Add Set", systemImage: "plus") {
                            exercise.addSet()
                        }
                        .chalkRow()
                    } header: {
                        Text(exercise.name)
                    } footer: {
                        Text("Prescribed \(exercise.isWeighted ? exercise.prescribedWeight.description : WeightLabel.bodyweight) · \(exercise.targetSets) × \(exercise.targetReps)")
                    }
                }
            }
            .chalkListStyle()
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft == session.draft)
                }
            }
            .confirmationDialog(
                pendingChanges.count == 1 ? "This changes your current weight" : "This changes your current weights",
                isPresented: Binding(get: { !pendingChanges.isEmpty }, set: { if !$0 { pendingChanges = [] } }),
                titleVisibility: .visible
            ) {
                Button("Save Changes") { commit() }
            } message: {
                Text(pendingChanges.map(\.description).joined(separator: "\n") + "\nYour next workout uses the new weight.")
            }
        }
    }

    private func save() {
        let changes = session.weightChanges(applying: draft)
        if changes.isEmpty {
            commit()
        } else {
            pendingChanges = changes
        }
    }

    private func commit() {
        session.apply(draft, in: modelContext)
        dismiss()
    }
}

private struct SetEditRow: View {
    @Binding var set: SetDraft
    let targetReps: Int
    let isWeighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isWeighted {
                TextField("Weight", value: weightValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.Colors.weight)
                    .frame(width: 72)
                    .accessibilityLabel("Weight lifted")
                Text(set.weight.unit.symbol)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Stepper(value: $set.reps, in: 0...50) {
                Text("\(set.reps) reps")
                    .foregroundStyle(set.reps >= targetReps ? Theme.Colors.done : Theme.Colors.textPrimary)
            }
        }
    }

    private var weightValue: Binding<Double> {
        Binding(
            get: { set.weight.value },
            set: { set.weight = Weight(max($0, 0), set.weight.unit) }
        )
    }
}

#if DEBUG
// TODO: This preview crashes in Xcode Previews like WorkoutDetailView's (see the note
// there). The sheet works in the app (covered by HistoryUITests).
#Preview {
    let container = SampleData.previewContainer(completedWeeks: 1)
    let session = HistoryQueries.finishedSessions(in: container.mainContext).last!
    return EditWorkoutSheet(session: session)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
#endif
