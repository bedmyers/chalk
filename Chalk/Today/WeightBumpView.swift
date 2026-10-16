//
//  WeightBumpView.swift
//  Chalk
//
//  The weight-bump moment: leotard stripe, old → new weight, haptic, animation.
//

import ChalkCore
import SwiftUI

struct WeightBumpView: View {
    let bumps: [WeightBump]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LeotardStripe(stripeWidth: 22)
                .frame(height: 40)
                .offset(x: isRevealed || reduceMotion ? 0 : -500)

            // Scrolls only if a big day earns more bumps than fit.
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("And up! And up!")
                        .font(Theme.Fonts.eyebrow)
                        .textCase(.uppercase)
                        .tracking(3)
                        .foregroundStyle(Theme.Colors.done)

                    ForEach(bumps) { bump in
                        bumpRow(bump)
                    }

                    Text(bumps.count == 1
                         ? "Three weeks, every rep. Grab a bigger plate."
                         : "Three weeks, every rep. Grab bigger plates.")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(Theme.Metrics.screenPadding)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            HStack {
                Spacer()
                MemphisCluster()
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)

            Button("Let's Go") {
                onDismiss()
            }
            .buttonStyle(.chalkPrimary)
                .padding(Theme.Metrics.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.background)
        .sensoryFeedback(.success, trigger: isRevealed)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .bouncy(duration: 0.6, extraBounce: 0.25).delay(0.15)) {
                isRevealed = true
            }
        }
    }

    private func bumpRow(_ bump: WeightBump) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bump.exerciseName).exerciseNameStyle()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(bump.from.formattedValue)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Image(systemName: "arrow.right")
                    .font(Theme.Fonts.unit)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(bump.to.formattedValue)
                    .foregroundStyle(Theme.Colors.weight)
                    .popShadow(Theme.Colors.action)
                    .scaleEffect(isRevealed || reduceMotion ? 1 : 0.3, anchor: .bottomLeading)
                    .opacity(isRevealed ? 1 : 0)
                Text(bump.to.unit.symbol)
                    .font(Theme.Fonts.unit)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .font(Theme.Fonts.screenTitle)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bump.exerciseName) up from \(bump.from.description) to \(bump.to.description)")
    }
}

#if DEBUG
#Preview("One bump") {
    WeightBumpView(bumps: [
        WeightBump(exerciseName: "Bench Press", from: .pounds(185), to: .pounds(190)),
    ], onDismiss: {})
    .preferredColorScheme(.dark)
}

#Preview("Three bumps") {
    WeightBumpView(bumps: [
        WeightBump(exerciseName: "Bench Press", from: .pounds(185), to: .pounds(190)),
        WeightBump(exerciseName: "Overhead Press", from: .pounds(115), to: .pounds(120)),
        WeightBump(exerciseName: "Incline DB Press", from: .pounds(60), to: .pounds(65)),
    ], onDismiss: {})
    .preferredColorScheme(.dark)
}
#endif
