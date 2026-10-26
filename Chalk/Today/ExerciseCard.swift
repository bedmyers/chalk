//
//  ExerciseCard.swift
//  Chalk
//

import ChalkCore
import SwiftUI

/// One exercise with its weight and set buttons. The featured card is today's
/// main lift: hero weight and the leotard stripe.
struct ExerciseCard: View {
    let exercise: PlannedExercise
    let isFeatured: Bool
    let onTapSet: (Int) -> Void
    let onClearSet: (SetLog) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isFeatured ? 12 : 16) {
            if isFeatured {
                featuredHeader
            } else {
                compactHeader
            }
            setRow
        }
        .padding(isFeatured ? 24 : 20)
        .padding(.top, isFeatured ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .overlay(alignment: .top) {
            if isFeatured {
                LeotardStripe().frame(height: 18)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.Metrics.cardCornerRadius))
        .overlay {
            if isFeatured {
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .strokeBorder(Theme.Colors.textPrimary, lineWidth: 3)
            }
        }
    }

    private var targetText: String { "\(exercise.targetSets) × \(exercise.targetReps)" }

    /// The weight, or "BW" for bodyweight lifts.
    private var weightText: String {
        exercise.isWeighted ? exercise.weight.formattedValue : WeightLabel.bodyweight
    }

    private var featuredHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name).exerciseNameStyle()
                Spacer()
                Text(targetText)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(weightText)
                    .font(Theme.Fonts.heroWeight)
                    .foregroundStyle(Theme.Colors.weight)
                    .popShadow()
                if exercise.isWeighted {
                    Text(exercise.weight.unit.symbol)
                        .font(Theme.Fonts.unit)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityElement(children: .combine)
        }
    }

    private var compactHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).exerciseNameStyle()
                Text(targetText)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text(weightText)
                .font(Theme.Fonts.rowWeight)
                .foregroundStyle(Theme.Colors.weight)
                .lineLimit(1)
                .accessibilityLabel(exercise.isWeighted ? exercise.weight.description : "Bodyweight")
        }
    }

    private var setRow: some View {
        let count = max(exercise.targetSets, exercise.sets.count)
        return ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(0..<count, id: \.self) { index in
                    let set = exercise.sets.indices.contains(index) ? exercise.sets[index] : nil
                    SetButton(
                        number: index + 1,
                        reps: set?.reps,
                        targetReps: exercise.targetReps,
                        size: isFeatured ? 64 : 52,
                        onTap: { onTapSet(index) },
                        onClear: set.map { set in { onClearSet(set) } }
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

/// A big round set button. Empty: tap logs the target reps. Logged: tap counts down.
struct SetButton: View {
    let number: Int
    let reps: Int?
    let targetReps: Int
    let size: CGFloat
    let onTap: () -> Void
    let onClear: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let reps {
                    let hit = reps >= targetReps
                    Circle().fill(hit ? Theme.Colors.done : Theme.Colors.border)
                    Text("\(reps)")
                        .font(Theme.Fonts.setReps)
                        .foregroundStyle(hit ? Theme.Colors.onFill : Theme.Colors.textPrimary)
                        .minimumScaleFactor(0.5)
                        .padding(6)
                } else {
                    Circle().strokeBorder(Theme.Colors.decor, style: StrokeStyle(lineWidth: 3, dash: [7, 6]))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onClear {
                Button("Clear Set", systemImage: "xmark", role: .destructive, action: onClear)
            }
        }
        .accessibilityLabel(reps.map { "Set \(number), \($0) reps" } ?? "Set \(number), not logged")
        .accessibilityHint(reps == nil ? "Logs \(targetReps) reps" : "Removes one rep")
    }
}
