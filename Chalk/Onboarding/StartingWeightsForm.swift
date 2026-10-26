//
//  StartingWeightsForm.swift
//  Chalk
//

import ChalkCore
import SwiftUI

/// Starting weights for every lift in a template. Each is blank and required;
/// "Not sure? Start light" fills in the lightest valid weight.
struct StartingWeightsForm: View {
    let template: ProgramTemplate
    let unit: WeightUnit
    @Binding var texts: [String: String]

    var body: some View {
        List {
            Section {
                Text("Start lighter than you think. Chalk adds weight when you earn it.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(progress)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(isComplete ? Theme.Colors.done : Theme.Colors.textSecondary)
            }
            .chalkRow()

            ForEach(template.days, id: \.name) { day in
                Section(day.name) {
                    ForEach(day.lifts) { lift in
                        StartingWeightRow(lift: lift, unit: unit, text: binding(for: lift))
                            .chalkRow()
                    }
                }
            }
        }
        .chalkListStyle()
    }

    private var setCount: Int {
        StartingWeights.resolve(texts, for: template.lifts, unit: unit).count
    }

    private var isComplete: Bool { setCount == template.lifts.count }

    private var progress: String {
        isComplete ? "All \(template.lifts.count) lifts set" : "\(setCount) of \(template.lifts.count) lifts set"
    }

    private func binding(for lift: TemplateLift) -> Binding<String> {
        Binding(get: { texts[lift.name] ?? "" }, set: { texts[lift.name] = $0 })
    }
}

private struct StartingWeightRow: View {
    let lift: TemplateLift
    let unit: WeightUnit
    @Binding var text: String

    @FocusState private var isFocused: Bool

    private var loading: LoadingSettings { .standard(for: unit) }
    private var entered: Weight? { WeightInput.parse(text, unit: unit) }
    private var snapped: Weight? { entered.map { loading.snapped($0, for: lift.equipment) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lift.name).exerciseNameStyle()
                    Text("\(lift.sets) × \(lift.reps) · \(lift.equipment.displayName)")
                        .font(Theme.Fonts.target)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                TextField("—", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Theme.Fonts.rowWeight)
                    .foregroundStyle(Theme.Colors.weight)
                    .frame(maxWidth: 120)
                    .focused($isFocused)
                    .accessibilityLabel("\(lift.name) starting weight")
                Text(unit.symbol)
                    .font(Theme.Fonts.unit)
                    .textCase(.uppercase)
            }

            if text.isEmpty {
                Button("Not sure? Start light") {
                    text = StartingWeights.lightest(for: lift.equipment, unit: unit).formattedValue
                }
                .font(Theme.Fonts.target)
                .foregroundStyle(Theme.Colors.action)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Start \(lift.name) light")
            } else if let hint {
                Text(hint)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: isFocused) { _, focused in
            // Show the snapped value once the user leaves the field.
            if !focused, let snapped, snapped != entered {
                text = snapped.formattedValue
            }
        }
    }

    private var hint: String? {
        guard let entered else { return "Enter a number" }
        guard let snapped, snapped != entered else { return nil }
        return "Rounds to \(snapped), the nearest weight you can load."
    }
}
