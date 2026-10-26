//
//  DayView.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// What the exercise sheet is editing.
enum ExerciseEditorTarget: Identifiable {
    case new(ProgramDay)
    case existing(ExerciseSlot)

    /// Stable across saves, so the sheet isn't torn down when SwiftData autosaves.
    var id: UUID {
        switch self {
        case .new(let day): day.id
        case .existing(let slot): slot.id
        }
    }
}

/// One day's exercises: add, reorder, edit, remove.
struct DayView: View {
    @Bindable var day: ProgramDay

    @Environment(\.modelContext) private var modelContext
    @State private var editorTarget: ExerciseEditorTarget?
    @State private var entryPendingRemoval: DayEntry?

    private var unit: WeightUnit { day.program?.unit ?? .pounds }

    /// Exercises on other days that could be shared onto this one.
    private var shareableSlots: [ExerciseSlot] {
        let here = Set(day.sortedEntries.compactMap { $0.slot?.persistentModelID })
        return (day.program?.activeSlots ?? []).filter { !here.contains($0.persistentModelID) }
    }

    var body: some View {
        List {
            Section("Name") {
                TextField("Day name", text: $day.name)
                    .textInputAutocapitalization(.words)
            }
            .chalkRow()

            Section {
                ForEach(day.sortedEntries) { entry in
                    if let slot = entry.slot {
                        Button {
                            editorTarget = .existing(slot)
                        } label: {
                            ExerciseRow(slot: slot, currentDay: day)
                        }
                    }
                }
                .onMove { day.moveEntries(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    guard let index = offsets.first else { return }
                    let entry = day.sortedEntries[index]
                    if day.removalArchivesExercise(entry) {
                        entryPendingRemoval = entry
                    } else {
                        day.remove(entry, in: modelContext)
                    }
                }

                Menu {
                    Button("New Exercise", systemImage: "plus") {
                        editorTarget = .new(day)
                    }
                    if !shareableSlots.isEmpty {
                        Section("From Another Day (Shared Weight)") {
                            ForEach(shareableSlots) { slot in
                                Button(slot.name) {
                                    day.add(slot, in: modelContext)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            } header: {
                Text("Exercises")
            } footer: {
                Text("The first exercise is the day's main lift.")
            }
            .chalkRow()
        }
        .chalkListStyle()
        .navigationTitle(day.name)
        .toolbar {
            EditButton()
        }
        .sheet(item: $editorTarget) { target in
            ExerciseSheet(target: target, unit: unit)
        }
        .confirmationDialog(
            "Remove \(entryPendingRemoval?.slot?.name ?? "exercise")?",
            isPresented: Binding(
                get: { entryPendingRemoval != nil },
                set: { if !$0 { entryPendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: entryPendingRemoval
        ) { entry in
            Button("Remove and Archive", role: .destructive) {
                day.remove(entry, in: modelContext)
            }
        } message: { _ in
            Text("It isn't on any other day, so it'll be archived. Its history is kept.")
        }
    }
}

private struct ExerciseRow: View {
    let slot: ExerciseSlot
    let currentDay: ProgramDay

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.name).exerciseNameStyle()
                Text(details)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text(WeightLabel.value(slot.progression().nextWeight, equipment: slot.equipment))
                .font(Theme.Fonts.rowWeight)
                .foregroundStyle(Theme.Colors.weight)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var details: String {
        var parts = [slot.targetText(extraReps: slot.progression().extraReps), slot.equipment.displayName]
        let otherDays = (slot.entries ?? [])
            .compactMap(\.day)
            .filter { $0.persistentModelID != currentDay.persistentModelID }
            .map(\.name)
        if !otherDays.isEmpty {
            parts.append("Also on \(otherDays.formatted(.list(type: .and)))")
        }
        return parts.joined(separator: " · ")
    }
}

#if DEBUG
#Preview {
    let container = SampleData.previewContainer()
    let day = ProgramLibrary.activePrograms(in: container.mainContext)[0].sortedDays[0]
    return NavigationStack {
        DayView(day: day)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
#endif
