//
//  OnboardingView.swift
//  Chalk
//
//  First launch: welcome → unit → template → starting weights → Today.
//

import ChalkCore
import SwiftData
import SwiftUI

/// How onboarding ended.
enum OnboardingResult {
    /// A program was built from a template; go to Today.
    case startTraining
    /// A blank program was created; go to the Program tab to add days.
    case buildProgram
    /// "Set up later": nothing was created.
    case skipped
}

/// When to show onboarding and when it was interrupted by an iCloud sync.
nonisolated enum OnboardingGate {
    /// Only on a first launch with no programs at all (active or archived).
    static func shouldShow(programCount: Int, hasSeenOnboarding: Bool) -> Bool {
        programCount == 0 && !hasSeenOnboarding
    }

    /// Programs arrived (from iCloud) while onboarding was still showing.
    static func isWelcomeBack(hadPrograms: Bool, hasPrograms: Bool, hasSeenOnboarding: Bool) -> Bool {
        !hadPrograms && hasPrograms && !hasSeenOnboarding
    }
}

struct OnboardingView: View {
    let onFinish: (OnboardingResult) -> Void

    private enum Step: Hashable {
        case unit
        case template
        case weights(ProgramTemplate)
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultUnit") private var defaultUnitRaw = WeightUnit.pounds.rawValue
    @State private var path: [Step] = []
    @State private var unit = WeightUnit.pounds
    @State private var weightTexts: [String: String] = [:]

    var body: some View {
        NavigationStack(path: $path) {
            welcome
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .unit: unitStep
                    case .template: templateStep
                    case .weights(let template): weightsStep(template)
                    }
                }
        }
        .tint(Theme.Colors.action)
        .onChange(of: unit) {
            // Typed weights are in the old unit; start the weights over.
            weightTexts = [:]
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            LeotardStripe(stripeWidth: 22)
                .frame(height: 40)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    MemphisCluster()
                }
                Text("Chalk")
                    .font(Theme.Fonts.heroWeight)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .popShadow(Theme.Colors.action)
                    .accessibilityAddTraits(.isHeader)
                Text("Enter your program once. We'll tell you what to lift, and add weight when you earn it.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Metrics.screenPadding)

            Spacer()

            VStack(spacing: 8) {
                Button("Let's Go") { path.append(.unit) }
                    .buttonStyle(.chalkPrimary)
                Button("Set Up Later") { onFinish(.skipped) }
                    .buttonStyle(.chalkSecondary)
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.background)
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var unitStep: some View {
        StepLayout(title: "Pounds or kilos?", message: "Every weight in your program uses this unit.") {
            VStack(spacing: 12) {
                ForEach(WeightUnit.allCases, id: \.self) { option in
                    ChoiceButton(
                        title: option == .pounds ? "Pounds" : "Kilograms",
                        detail: option.symbol.uppercased(),
                        isSelected: unit == option
                    ) {
                        unit = option
                        defaultUnitRaw = option.rawValue
                        path.append(.template)
                    }
                }
            }
        }
        .onAppear { unit = WeightUnit(rawValue: defaultUnitRaw) ?? .pounds }
    }

    private var templateStep: some View {
        StepLayout(title: "Pick a program", message: "You can change anything later.") {
            VStack(spacing: 12) {
                ForEach(ProgramTemplate.all) { template in
                    ChoiceButton(
                        title: template.name,
                        detail: template.summary,
                        isSelected: false
                    ) {
                        path.append(.weights(template))
                    }
                }
                ChoiceButton(title: "Start Blank", detail: "Build your own days", isSelected: false) {
                    ProgramLibrary.createProgram(named: "My Program", unit: unit, in: modelContext)
                    onFinish(.buildProgram)
                }
            }
        }
    }

    private func weightsStep(_ template: ProgramTemplate) -> some View {
        let weights = StartingWeights.resolve(weightTexts, for: template.lifts, unit: unit)
        let isComplete = weights.count == template.lifts.count
        return StartingWeightsForm(template: template, unit: unit, texts: $weightTexts)
            .navigationTitle("Starting weights")
            .safeAreaInset(edge: .bottom) {
                Button("Start Training") {
                    guard (try? template.makeProgram(unit: unit, startingWeights: weights, in: modelContext)) != nil else {
                        return
                    }
                    onFinish(.startTraining)
                }
                .buttonStyle(.chalkPrimary)
                .disabled(!isComplete)
                .padding(Theme.Metrics.screenPadding)
                .background(Theme.Colors.background)
            }
    }
}

/// A title, a line of explanation, and the step's content.
private struct StepLayout<Content: View>: View {
    let title: String
    let message: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(Theme.Fonts.screenTitle)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .popShadow()
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                content
                    .padding(.top, 8)
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
}

/// A big tappable card for a single choice.
private struct ChoiceButton: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).exerciseNameStyle()
                Spacer()
                Text(detail)
                    .font(Theme.Fonts.target)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Metrics.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .strokeBorder(isSelected ? Theme.Colors.action : Theme.Colors.border, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    OnboardingView { _ in }
        .modelContainer(try! ChalkModelContainer.make(inMemory: true))
        .preferredColorScheme(.dark)
}
#endif
