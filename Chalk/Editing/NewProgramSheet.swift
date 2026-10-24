//
//  NewProgramSheet.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// Names a new program and picks its unit. If a program is active, confirms
/// archiving it first, since only one program is active at a time.
struct NewProgramSheet: View {
    /// The active program that creating this one will archive.
    let replacing: Program?
    let onCreate: (Program) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// The unit picked last time, used as the default for new programs.
    @AppStorage("defaultUnit") private var defaultUnitRaw = WeightUnit.pounds.rawValue
    @State private var name = ""
    @State private var unit = WeightUnit.pounds
    @State private var isConfirmingReplace = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Push Pull Legs", text: $name)
                        .textInputAutocapitalization(.words)
                }
                .chalkRow()

                Section {
                    Picker("Unit", selection: $unit) {
                        Text("Pounds").tag(WeightUnit.pounds)
                        Text("Kilograms").tag(WeightUnit.kilograms)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Unit")
                } footer: {
                    Text("Every weight in the program uses this unit.")
                }
                .chalkRow()
            }
            .chalkListStyle()
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if replacing == nil {
                            create()
                        } else {
                            isConfirmingReplace = true
                        }
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog(
                "Archive \(replacing?.name ?? "current program")?",
                isPresented: $isConfirmingReplace,
                titleVisibility: .visible
            ) {
                Button("Archive and Create") { create() }
            } message: {
                Text("Only one program is active at a time. Its history is kept, and archived programs can be restored later.")
            }
        }
        .onAppear {
            unit = WeightUnit(rawValue: defaultUnitRaw) ?? .pounds
        }
    }

    private func create() {
        defaultUnitRaw = unit.rawValue
        let program = ProgramLibrary.createProgram(named: trimmedName, unit: unit, in: modelContext)
        dismiss()
        onCreate(program)
    }
}
