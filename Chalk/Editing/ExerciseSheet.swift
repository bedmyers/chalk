//
//  ExerciseSheet.swift
//  Chalk
//

import ChalkCore
import SwiftData
import SwiftUI

/// Creates or edits an exercise. Barbell and dumbbell weights snap to loadable
/// values and never go below the bar or the lightest dumbbell. Edits that
/// restart the block ask first.
struct ExerciseSheet: View {
    let target: ExerciseEditorTarget
    let unit: WeightUnit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var spec: ExerciseSpec
    @State private var weightText: String
    @State private var incrementText: String
    /// Once the user sets an increment, picking a body region or lift stops overwriting it.
    @State private var isIncrementCustomized: Bool
    @State private var isConfirmingRestart = false
    @FocusState private var focusedField: Field?

    /// The exercise as it was, for existing exercises.
    private let original: ExerciseSpec?
    private let initialWeightText: String
    private let loading: LoadingSettings

    private enum Field {
        case name, weight, increment
    }

    init(target: ExerciseEditorTarget, unit: WeightUnit) {
        let initial: ExerciseSpec
        switch target {
        case .new:
            initial = .new(unit: unit)
            original = nil
        case .existing(let slot):
            initial = slot.spec
            original = initial
        }
        self.target = target
        self.unit = unit
        loading = .standard(for: unit)
        initialWeightText = initial.weight.formattedValue
        _spec = State(initialValue: initial)
        _weightText = State(initialValue: initial.weight.formattedValue)
        _incrementText = State(initialValue: initial.increment.formattedValue)
        _isIncrementCustomized = State(initialValue: original != nil)
    }

    // MARK: - Derived values

    private var ladder: any WeightLadder { loading.ladder(for: spec.equipment) }

    private var enteredWeight: Weight? { WeightInput.parse(weightText, unit: unit) }

    /// The weight that will be saved. An untouched field keeps the current weight as-is.
    private var resolvedWeight: Weight? {
        guard spec.equipment.isWeighted else { return Weight(thousandths: 0, unit: unit) }
        if weightText == initialWeightText, spec.equipment == original?.equipment {
            return original?.weight
        }
        return enteredWeight.map { loading.snapped($0, for: spec.equipment) }
    }

    private var enteredIncrement: Weight? {
        // Bodyweight lifts add reps, not weight; keep whatever increment they had.
        guard spec.equipment.isWeighted else { return spec.increment }
        return WeightInput.parse(incrementText, unit: unit).flatMap { $0.thousandths > 0 ? $0 : nil }
    }

    private var minimumIncrease: Weight {
        ladder.minimumIncrease(from: resolvedWeight ?? spec.weight)
    }

    /// The spec to save, or nil while something is missing or invalid.
    private var resolvedSpec: ExerciseSpec? {
        guard !spec.trimmedName.isEmpty, let weight = resolvedWeight, let increment = enteredIncrement else {
            return nil
        }
        var resolved = spec
        resolved.weight = weight
        resolved.increment = increment
        // Week 1 of a wave doubles as the single reps value.
        resolved.targetReps = spec.repsByWeek.first ?? spec.targetReps
        return resolved
    }

    private var weightHint: String? {
        guard let entered = enteredWeight, let resolved = resolvedWeight, entered != resolved else { return nil }
        if entered < ladder.minimum {
            switch spec.equipment {
            case .barbell: return "The empty bar is \(ladder.minimum), so that's the lightest it can go."
            case .dumbbell: return "The lightest dumbbell is \(ladder.minimum)."
            case .machine, .bodyweight: break
            }
        }
        return "Rounds to \(resolved), the nearest weight you can load."
    }

    private var incrementHint: String {
        if let increment = enteredIncrement, increment < minimumIncrease {
            return "\(increment) is raised to \(minimumIncrease), the smallest jump for this lift."
        }
        return "Goes up by at least \(minimumIncrease) after a passed block."
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                exerciseSection
                targetSection
                if spec.equipment.isWeighted {
                    weightSection
                    incrementSection
                }
            }
            .chalkListStyle()
            .navigationTitle(original == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(resolvedSpec == nil)
                }
            }
            .confirmationDialog(
                "This restarts your 3-week count",
                isPresented: $isConfirmingRestart,
                titleVisibility: .visible
            ) {
                Button("Save and Restart") {
                    if let resolvedSpec { commit(resolvedSpec) }
                }
            } message: {
                if let resolvedSpec {
                    Text("\(resolvedSpec.trimmedName) starts a fresh block at \(restartTarget(resolvedSpec)). Past workouts are kept.")
                }
            }
            .onChange(of: spec.bodyRegion) {
                applyDefaultIncrementIfNeeded()
            }
            .onChange(of: spec.name) {
                // Link to the catalog lift with this name. Renaming an existing
                // exercise to something custom keeps its original link.
                spec.catalogID = ExerciseCatalog.matching(name: spec.name)?.id ?? original?.catalogID
            }
            .onChange(of: focusedField) { previous, _ in
                // Show the snapped value once the user leaves the weight field.
                if previous == .weight, let resolvedWeight, weightText != initialWeightText {
                    weightText = resolvedWeight.formattedValue
                }
                if previous == .increment {
                    isIncrementCustomized = true
                }
            }
        }
    }

    private var exerciseSection: some View {
        Section("Exercise") {
            TextField("Name", text: $spec.name)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)

            ForEach(ExerciseCatalog.suggestions(for: spec.name)) { suggestion in
                Button {
                    apply(suggestion)
                } label: {
                    HStack {
                        Text(suggestion.name)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(suggestion.equipment.displayName)
                            .font(Theme.Fonts.target)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            Picker("Equipment", selection: $spec.equipment) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    Text(equipment.displayName).tag(equipment)
                }
            }
            .pickerStyle(.segmented)

            Picker("Body", selection: $spec.bodyRegion) {
                ForEach(BodyRegion.allCases, id: \.self) { region in
                    Text(region.displayName).tag(region)
                }
            }
            .pickerStyle(.segmented)
        }
        .chalkRow()
    }

    private var targetSection: some View {
        Section {
            Stepper("\(spec.targetSets) sets", value: $spec.targetSets, in: 1...10)
            Picker("Reps", selection: hasWave) {
                Text("Same every week").tag(false)
                Text("By week").tag(true)
            }
            .pickerStyle(.segmented)
            if spec.repsByWeek.isEmpty {
                Stepper("\(spec.targetReps) reps", value: $spec.targetReps, in: 1...50)
            } else {
                ForEach(spec.repsByWeek.indices, id: \.self) { week in
                    Stepper("Week \(week + 1): \(spec.repsByWeek[week]) reps", value: $spec.repsByWeek[week], in: 1...50)
                }
            }
        } header: {
            Text("Target")
        } footer: {
            Text(targetFooter)
        }
        .chalkRow()
    }

    /// Switches between one rep target and a 3-week wave, keeping week 1's reps.
    private var hasWave: Binding<Bool> {
        Binding {
            !spec.repsByWeek.isEmpty
        } set: { wave in
            if wave {
                let start = spec.targetReps
                spec.repsByWeek = [start, start + 2, start + 4]
            } else {
                spec.targetReps = spec.repsByWeek.first ?? spec.targetReps
                spec.repsByWeek = []
            }
        }
    }

    private var targetFooter: String {
        switch (spec.equipment.isWeighted, spec.repsByWeek.isEmpty) {
        case (true, true): "Hit every set for 3 weeks to add weight."
        case (true, false): "Reps climb each week. Hit all 3 weeks to add weight and start over at week 1."
        case (false, true): "Hit every set for 3 weeks to add a rep."
        case (false, false): "Reps climb each week. Hit all 3 weeks to add a rep to every week."
        }
    }

    /// What a restarted exercise starts at: its weight, or its reps for bodyweight lifts.
    private func restartTarget(_ spec: ExerciseSpec) -> String {
        guard !spec.equipment.isWeighted else { return spec.weight.description }
        return "\(spec.targetSets) × \(RepWave.text(reps: spec.targetReps, repsByWeek: spec.repsByWeek))"
    }

    private var weightSection: some View {
        Section {
            HStack(spacing: 12) {
                stepButton(systemImage: "minus", label: "Lighter") { stepWeight(up: false) }
                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(Theme.Fonts.rowWeight)
                    .foregroundStyle(Theme.Colors.weight)
                    .focused($focusedField, equals: .weight)
                    .accessibilityLabel(original == nil ? "Starting weight" : "Current weight")
                Text(unit.symbol)
                    .font(Theme.Fonts.unit)
                    .textCase(.uppercase)
                stepButton(systemImage: "plus", label: "Heavier") { stepWeight(up: true) }
            }
            .padding(.vertical, 4)
        } header: {
            Text(original == nil ? "Starting weight" : "Current weight")
        } footer: {
            if let weightHint {
                Text(weightHint)
            }
        }
        .chalkRow()
    }

    private var incrementSection: some View {
        Section {
            HStack {
                TextField("Increment", text: $incrementText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .increment)
                Text(unit.symbol)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        } header: {
            Text("Increment")
        } footer: {
            Text(incrementHint)
        }
        .chalkRow()
    }

    private func stepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Theme.Fonts.button)
                .foregroundStyle(Theme.Colors.onFill)
                .frame(width: 48, height: 48)
                .background(Theme.Colors.action, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    /// Steps by the lift's smallest jump: 5 lb, or 2.5 lb for dumbbells under 20 lb.
    private func stepWeight(up: Bool) {
        let current = resolvedWeight ?? spec.weight
        weightText = loading.stepped(current, for: spec.equipment, up: up).formattedValue
    }

    private func apply(_ suggestion: CatalogExercise) {
        spec.name = suggestion.name
        spec.equipment = suggestion.equipment
        spec.bodyRegion = suggestion.bodyRegion
        spec.catalogID = suggestion.id
        applyDefaultIncrementIfNeeded()
        focusedField = nil
    }

    private func applyDefaultIncrementIfNeeded() {
        guard !isIncrementCustomized else { return }
        incrementText = spec.bodyRegion.defaultIncrement(in: unit).formattedValue
    }

    private func save() {
        guard let resolvedSpec else { return }
        if let original, resolvedSpec.restartsBlock(comparedTo: original) {
            isConfirmingRestart = true
        } else {
            commit(resolvedSpec)
        }
    }

    private func commit(_ spec: ExerciseSpec) {
        switch target {
        case .new(let day):
            day.program?.addExercise(spec, to: day, in: modelContext)
        case .existing(let slot):
            slot.save(spec, in: modelContext)
        }
        dismiss()
    }
}

#if DEBUG
#Preview("New") {
    let container = SampleData.previewContainer()
    let day = ProgramLibrary.activePrograms(in: container.mainContext)[0].sortedDays[0]
    return ExerciseSheet(target: .new(day), unit: .pounds)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Edit") {
    let container = SampleData.previewContainer()
    let slot = ProgramLibrary.activePrograms(in: container.mainContext)[0].activeSlots[0]
    return ExerciseSheet(target: .existing(slot), unit: .pounds)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
#endif
