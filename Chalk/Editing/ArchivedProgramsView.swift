//
//  ArchivedProgramsView.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// Archived programs: restore one (archiving the active program) or delete it for good.
struct ArchivedProgramsView: View {
    @Query(filter: #Predicate<Program> { $0.archivedAt != nil }, sort: \Program.archivedAt, order: .reverse)
    private var archived: [Program]
    @Query(filter: #Predicate<Program> { $0.archivedAt == nil })
    private var active: [Program]

    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @State private var programToRestore: Program?
    @State private var programToDelete: Program?

    var body: some View {
        List {
            Section {
                ForEach(archived) { program in
                    Button {
                        programToRestore = program
                    } label: {
                        ArchivedProgramRow(program: program)
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            programToDelete = program
                        }
                    }
                }
            } footer: {
                Text("Tap a program to restore it. Its history and weights pick up where they left off.")
            }
            .chalkRow()
        }
        .chalkListStyle()
        .navigationTitle("Archived")
        .overlay {
            if archived.isEmpty {
                ContentUnavailableView("No archived programs", systemImage: "archivebox")
            }
        }
        .confirmationDialog(
            "Restore \(programToRestore?.name ?? "program")?",
            isPresented: isPresent($programToRestore),
            titleVisibility: .visible,
            presenting: programToRestore
        ) { program in
            Button("Restore") {
                program.restore(in: modelContext)
                // Back to the Program tab's root, which now shows the restored program.
                router.programPath.removeAll()
            }
        } message: { _ in
            if let current = active.first {
                Text("Only one program is active at a time, so \(current.name) will be archived. Its history is kept.")
            } else {
                Text("It becomes your active program.")
            }
        }
        .confirmationDialog(
            "Delete \(programToDelete?.name ?? "program")?",
            isPresented: isPresent($programToDelete),
            titleVisibility: .visible,
            presenting: programToDelete
        ) { program in
            Button("Delete Program and History", role: .destructive) {
                modelContext.delete(program)
            }
        } message: { _ in
            Text("This permanently deletes the program and every workout logged with it.")
        }
    }

    private func isPresent<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}

private struct ArchivedProgramRow: View {
    let program: Program

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(program.name).exerciseNameStyle()
            Text(details)
                .font(Theme.Fonts.target)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var details: String {
        let workouts = program.completedWorkoutCount
        var parts = [workouts == 1 ? "1 workout" : "\(workouts) workouts", program.unit.symbol]
        if let archivedAt = program.archivedAt {
            parts.append("Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: " · ")
    }
}

#if DEBUG
#Preview {
    let container = SampleData.previewContainer()
    let context = container.mainContext
    ProgramLibrary.createProgram(named: "5x5", unit: .pounds, in: context)
    return NavigationStack {
        ArchivedProgramsView()
    }
    .environment(Router())
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
#endif
