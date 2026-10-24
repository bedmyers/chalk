//
//  ProgramView.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// The program's name and days, plus archive / delete / start over.
struct ProgramView: View {
    @Bindable var program: Program

    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @State private var isAddingDay = false
    @State private var newDayName = ""
    @State private var dayPendingDeletion: ProgramDay?
    @State private var dayBlockedFromDeletion: ProgramDay?
    @State private var isCreatingProgram = false
    @State private var isConfirmingArchive = false
    @State private var isConfirmingDelete = false
    /// Archive and delete run once this screen is gone, so it never renders a deleted program.
    @State private var exitAction: ExitAction?

    private enum ExitAction {
        case archive
        case delete
    }

    var body: some View {
        List {
            Section("Name") {
                TextField("Program name", text: $program.name)
                    .textInputAutocapitalization(.words)
            }
            .chalkRow()

            Section {
                ForEach(program.sortedDays) { day in
                    NavigationLink(value: Route.day(day)) {
                        DayRow(day: day)
                    }
                }
                .onMove { program.moveDays(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    guard let index = offsets.first else { return }
                    requestDeletion(of: program.sortedDays[index])
                }

                Button("Add Day", systemImage: "plus") {
                    newDayName = "Day \(program.sortedDays.count + 1)"
                    isAddingDay = true
                }
            } header: {
                Text("Days")
            } footer: {
                Text("Workouts follow this order every training week. Changes apply to the current week.")
            }
            .chalkRow()

            Section {
                Button("Start a New Program") { isCreatingProgram = true }
                NavigationLink("Archived Programs", value: Route.archivedPrograms)
                Button("Archive Program") { isConfirmingArchive = true }
                Button("Delete Program", role: .destructive) { isConfirmingDelete = true }
            }
            .chalkRow()
        }
        .chalkListStyle()
        .navigationTitle("Program")
        .toolbar {
            EditButton()
        }
        .alert("New Day", isPresented: $isAddingDay) {
            TextField("Name", text: $newDayName)
            Button("Add") {
                let name = newDayName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                program.addDay(named: name, in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \(dayPendingDeletion?.name ?? "day")?",
            isPresented: isPresent($dayPendingDeletion),
            titleVisibility: .visible,
            presenting: dayPendingDeletion
        ) { day in
            Button("Delete Day", role: .destructive) {
                _ = try? program.deleteDay(day, in: modelContext)
            }
        } message: { day in
            Text(deletionMessage(for: day))
        }
        .alert(
            "Workout in progress",
            isPresented: isPresent($dayBlockedFromDeletion),
            presenting: dayBlockedFromDeletion
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { day in
            Text("\(day.name) has a workout in progress. Finish or skip it before deleting the day.")
        }
        .confirmationDialog("Archive \(program.name)?", isPresented: $isConfirmingArchive, titleVisibility: .visible) {
            Button("Archive Program") { leave(then: .archive) }
        } message: {
            Text("Its history is kept, and archived programs can be restored later.")
        }
        .confirmationDialog("Delete \(program.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Program and History", role: .destructive) { leave(then: .delete) }
        } message: {
            Text("This permanently deletes the program and every workout logged with it. Archive it instead to keep the history.")
        }
        .sheet(isPresented: $isCreatingProgram) {
            NewProgramSheet(replacing: program) { newProgram in
                router.path = [.program(newProgram)]
            }
        }
        .onDisappear {
            switch exitAction {
            case .archive: program.archive()
            case .delete: modelContext.delete(program)
            case nil: break
            }
            exitAction = nil
        }
    }

    // MARK: - Actions

    private func requestDeletion(of day: ProgramDay) {
        if program.hasSessionInProgress(on: day) {
            dayBlockedFromDeletion = day
        } else {
            dayPendingDeletion = day
        }
    }

    private func deletionMessage(for day: ProgramDay) -> String {
        let orphaned = program.exercisesOnlyOn(day).map(\.name)
        guard !orphaned.isEmpty else {
            return "Its exercises stay on their other days. Past workouts are kept."
        }
        let names = orphaned.formatted(.list(type: .and))
        let verb = orphaned.count == 1 ? "isn't" : "aren't"
        let pronoun = orphaned.count == 1 ? "it'll" : "they'll"
        return "\(names) \(verb) on any other day, so \(pronoun) be archived. Past workouts are kept."
    }

    /// Pops back to Today, then archives or deletes once this screen is gone.
    private func leave(then action: ExitAction) {
        exitAction = action
        router.path.removeAll()
    }

    private func isPresent<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}

private struct DayRow: View {
    let day: ProgramDay

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.name).exerciseNameStyle()
            Text(summary)
                .font(Theme.Fonts.target)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        let names = day.sortedEntries.compactMap { $0.slot?.name }
        return names.isEmpty ? "No exercises yet" : names.joined(separator: " · ")
    }
}

#if DEBUG
#Preview {
    let container = SampleData.previewContainer()
    let program = ProgramLibrary.activePrograms(in: container.mainContext)[0]
    return NavigationStack {
        ProgramView(program: program)
    }
    .environment(Router())
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
#endif
