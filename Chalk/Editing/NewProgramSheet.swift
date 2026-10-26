//
//  NewProgramSheet.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// Names a new program, picks its unit, and starts it from a template or blank.
/// If a program is active, confirms archiving it first, since only one program
/// is active at a time.
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
    /// Nil means a blank program.
    @State private var template: ProgramTemplate?
    @State private var weightTexts: [String: String] = [:]
    @State private var isShowingWeights = false
    @State private var isConfirmingReplace = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The typed name, or the template's name if none was typed.
    private var programName: String {
        trimmedName.isEmpty ? (template?.name ?? "") : trimmedName
    }

    private var startingWeights: [String: Weight] {
        guard let template else { return [:] }
        return StartingWeights.resolve(weightTexts, for: template.lifts, unit: unit)
    }

    private var hasAllWeights: Bool {
        guard let template else { return true }
        return startingWeights.count == template.lifts.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(template?.name ?? "e.g. Push Pull Legs", text: $name)
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

                Section("Start from") {
                    templateRow(nil, title: "Blank program", detail: "Build your own days")
                    ForEach(ProgramTemplate.all) { template in
                        templateRow(template, title: template.name, detail: template.summary)
                    }
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
                    if template == nil {
                        Button("Create") { requestCreate() }
                            .disabled(programName.isEmpty)
                    } else {
                        Button("Next") { isShowingWeights = true }
                            .disabled(programName.isEmpty)
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingWeights) {
                if let template {
                    StartingWeightsForm(template: template, unit: unit, texts: $weightTexts)
                        .navigationTitle("Starting weights")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Create") { requestCreate() }
                                    .disabled(!hasAllWeights)
                            }
                        }
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
        .onChange(of: unit) {
            // Typed weights are in the old unit; start the weights over.
            weightTexts = [:]
        }
    }

    private func templateRow(_ option: ProgramTemplate?, title: String, detail: String) -> some View {
        Button {
            template = option
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Theme.Colors.textPrimary)
                    Text(detail)
                        .font(Theme.Fonts.target)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if template == option {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.Colors.action)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(template == option ? .isSelected : [])
    }

    private func requestCreate() {
        if replacing == nil {
            create()
        } else {
            isConfirmingReplace = true
        }
    }

    private func create() {
        defaultUnitRaw = unit.rawValue
        let program: Program
        if let template {
            guard let built = try? template.makeProgram(
                named: programName,
                unit: unit,
                startingWeights: startingWeights,
                in: modelContext
            ) else { return }
            program = built
        } else {
            program = ProgramLibrary.createProgram(named: programName, unit: unit, in: modelContext)
        }
        dismiss()
        onCreate(program)
    }
}
