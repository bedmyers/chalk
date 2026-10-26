//
//  ProgramTemplate.swift
//  Chalk
//
//  Built-in programs offered in onboarding and "Start a New Program".
//

import ChalkCore
import Foundation
import SwiftData

/// One lift in a template. Equipment and body region come from the catalog.
nonisolated struct TemplateLift: Sendable, Hashable, Identifiable {
    let name: String
    let sets: Int
    let reps: Int

    /// Lift names are unique within a template, so they key starting weights.
    var id: String { name }

    var catalogEntry: CatalogExercise? { ExerciseCatalog.named(name) }
    var equipment: Equipment { catalogEntry?.equipment ?? .barbell }
    var bodyRegion: BodyRegion { catalogEntry?.bodyRegion ?? .lower }

    init(_ name: String, _ sets: Int, _ reps: Int) {
        self.name = name
        self.sets = sets
        self.reps = reps
    }
}

nonisolated struct TemplateDay: Sendable, Hashable {
    let name: String
    let lifts: [TemplateLift]
}

nonisolated struct ProgramTemplate: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let days: [TemplateDay]

    /// Every lift in day order.
    var lifts: [TemplateLift] { days.flatMap(\.lifts) }

    /// "3 days · 12 lifts"
    var summary: String { "\(days.count) days · \(lifts.count) lifts" }

    static let pushPullLegs = ProgramTemplate(id: "ppl", name: "Push Pull Legs", days: [
        TemplateDay(name: "Push", lifts: [
            TemplateLift("Bench Press", 4, 8),
            TemplateLift("Overhead Press", 3, 8),
            TemplateLift("Incline DB Press", 3, 10),
            TemplateLift("DB Lateral Raise", 3, 12),
            TemplateLift("Cable Triceps Pushdown", 3, 12),
        ]),
        TemplateDay(name: "Pull", lifts: [
            TemplateLift("Barbell Row", 4, 8),
            TemplateLift("Lat Pulldown", 3, 10),
            TemplateLift("Face Pull", 3, 15),
            TemplateLift("DB Curl", 3, 12),
        ]),
        TemplateDay(name: "Legs", lifts: [
            TemplateLift("Back Squat", 4, 8),
            TemplateLift("Romanian Deadlift", 3, 10),
            TemplateLift("Leg Press", 3, 12),
            TemplateLift("Leg Curl", 3, 12),
        ]),
    ])

    static let upperLower = ProgramTemplate(id: "upper-lower", name: "Upper / Lower", days: [
        TemplateDay(name: "Upper A", lifts: [
            TemplateLift("Bench Press", 4, 8),
            TemplateLift("Barbell Row", 4, 8),
            TemplateLift("Overhead Press", 3, 10),
            TemplateLift("Lat Pulldown", 3, 10),
        ]),
        TemplateDay(name: "Lower A", lifts: [
            TemplateLift("Back Squat", 4, 8),
            TemplateLift("Romanian Deadlift", 3, 10),
            TemplateLift("Leg Curl", 3, 12),
        ]),
        TemplateDay(name: "Upper B", lifts: [
            TemplateLift("Incline Bench Press", 4, 8),
            TemplateLift("DB Row", 3, 10),
            TemplateLift("DB Shoulder Press", 3, 10),
            TemplateLift("DB Curl", 3, 12),
        ]),
        TemplateDay(name: "Lower B", lifts: [
            TemplateLift("Deadlift", 3, 6),
            TemplateLift("Leg Press", 3, 10),
            TemplateLift("Leg Extension", 3, 12),
        ]),
    ])

    static let fullBody = ProgramTemplate(id: "full-body", name: "Full Body", days: [
        TemplateDay(name: "Day A", lifts: [
            TemplateLift("Back Squat", 4, 8),
            TemplateLift("Bench Press", 4, 8),
            TemplateLift("Barbell Row", 3, 10),
        ]),
        TemplateDay(name: "Day B", lifts: [
            TemplateLift("Deadlift", 3, 6),
            TemplateLift("Overhead Press", 4, 8),
            TemplateLift("Lat Pulldown", 3, 10),
        ]),
        TemplateDay(name: "Day C", lifts: [
            TemplateLift("Goblet Squat", 3, 10),
            TemplateLift("Incline DB Press", 3, 10),
            TemplateLift("Seated Cable Row", 3, 10),
        ]),
    ])

    static let all = [pushPullLegs, upperLower, fullBody]
}

// MARK: - Starting weights

nonisolated enum StartingWeights {
    /// What "Not sure? Start light" fills in: the empty bar, the lightest dumbbell,
    /// or 20 lb / 10 kg on a machine (a stack's real minimum isn't known).
    static func lightest(for equipment: Equipment, unit: WeightUnit) -> Weight {
        switch equipment {
        case .barbell, .dumbbell, .bodyweight:
            LoadingSettings.standard(for: unit).ladder(for: equipment).minimum
        case .machine:
            unit == .pounds ? .pounds(20) : .kilograms(10)
        }
    }

    /// Parsed and snapped weights for the lifts that have one, keyed by lift name.
    static func resolve(
        _ texts: [String: String],
        for lifts: [TemplateLift],
        unit: WeightUnit
    ) -> [String: Weight] {
        let loading = LoadingSettings.standard(for: unit)
        var weights: [String: Weight] = [:]
        for lift in lifts {
            guard let text = texts[lift.name], let weight = WeightInput.parse(text, unit: unit) else { continue }
            weights[lift.name] = loading.snapped(weight, for: lift.equipment)
        }
        return weights
    }
}

enum TemplateError: Error, Equatable {
    /// Every lift needs a starting weight.
    case missingStartingWeight(String)
}

extension ProgramTemplate {
    /// Creates the program (archiving the active one), with one exercise per lift
    /// at its snapped starting weight and the body region's default increment.
    @discardableResult
    func makeProgram(
        named name: String? = nil,
        unit: WeightUnit,
        startingWeights: [String: Weight],
        in context: ModelContext
    ) throws(TemplateError) -> Program {
        if let missing = lifts.first(where: { startingWeights[$0.name] == nil }) {
            throw .missingStartingWeight(missing.name)
        }
        let loading = LoadingSettings.standard(for: unit)
        let program = ProgramLibrary.createProgram(named: name ?? self.name, unit: unit, in: context)
        for templateDay in days {
            let day = program.addDay(named: templateDay.name, in: context)
            for lift in templateDay.lifts {
                var spec = ExerciseSpec.new(unit: unit)
                spec.name = lift.name
                spec.equipment = lift.equipment
                spec.bodyRegion = lift.bodyRegion
                spec.targetSets = lift.sets
                spec.targetReps = lift.reps
                spec.increment = lift.bodyRegion.defaultIncrement(in: unit)
                // `startingWeights` is checked above, so this always has a value.
                let weight = startingWeights[lift.name] ?? StartingWeights.lightest(for: lift.equipment, unit: unit)
                spec.weight = loading.snapped(weight, for: lift.equipment)
                spec.catalogID = lift.catalogEntry?.id
                program.addExercise(spec, to: day, in: context)
            }
        }
        return program
    }
}
