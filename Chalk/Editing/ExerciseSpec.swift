//
//  ExerciseSpec.swift
//  Chalk
//
//  Value types behind the exercise editor, kept free of SwiftData so they're easy to test.
//

import ChalkCore
import Foundation

/// Everything the exercise sheet edits.
nonisolated struct ExerciseSpec: Equatable, Sendable {
    var name: String
    var equipment: Equipment
    var bodyRegion: BodyRegion
    var targetSets: Int
    var targetReps: Int
    var increment: Weight
    /// The starting weight for a new exercise, or the current weight for an existing one.
    var weight: Weight

    /// A blank barbell exercise starting at the empty bar.
    static func new(unit: WeightUnit) -> ExerciseSpec {
        ExerciseSpec(
            name: "",
            equipment: .barbell,
            bodyRegion: .lower,
            targetSets: 3,
            targetReps: 8,
            increment: BodyRegion.lower.defaultIncrement(in: unit),
            weight: PlateSet.standard(for: unit).bar
        )
    }

    /// Saving `self` over `original` restarts the 3-week count when it changes
    /// anything progression depends on: targets, increment, equipment, or weight.
    /// Name and body region are cosmetic.
    func restartsBlock(comparedTo original: ExerciseSpec) -> Bool {
        targetSets != original.targetSets
            || targetReps != original.targetReps
            || increment != original.increment
            || equipment != original.equipment
            || weight != original.weight
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// A built-in lift that prefills equipment and body region. Free-text names are still allowed.
nonisolated struct CatalogExercise: Sendable, Hashable, Identifiable {
    let name: String
    let equipment: Equipment
    let bodyRegion: BodyRegion

    var id: String { name }
}

nonisolated enum ExerciseCatalog {
    static let all: [CatalogExercise] = [
        // Barbell
        CatalogExercise(name: "Back Squat", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(name: "Front Squat", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(name: "Deadlift", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(name: "Romanian Deadlift", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(name: "Hip Thrust", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(name: "Bench Press", equipment: .barbell, bodyRegion: .upper),
        CatalogExercise(name: "Incline Bench Press", equipment: .barbell, bodyRegion: .upper),
        CatalogExercise(name: "Overhead Press", equipment: .barbell, bodyRegion: .upper),
        CatalogExercise(name: "Barbell Row", equipment: .barbell, bodyRegion: .upper),
        // Dumbbell
        CatalogExercise(name: "DB Bench Press", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(name: "Incline DB Press", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(name: "DB Shoulder Press", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(name: "DB Row", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(name: "DB Curl", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(name: "DB Lateral Raise", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(name: "Goblet Squat", equipment: .dumbbell, bodyRegion: .lower),
        CatalogExercise(name: "DB Walking Lunge", equipment: .dumbbell, bodyRegion: .lower),
        // Machine / cable
        CatalogExercise(name: "Lat Pulldown", equipment: .machine, bodyRegion: .upper),
        CatalogExercise(name: "Seated Cable Row", equipment: .machine, bodyRegion: .upper),
        CatalogExercise(name: "Cable Triceps Pushdown", equipment: .machine, bodyRegion: .upper),
        CatalogExercise(name: "Leg Press", equipment: .machine, bodyRegion: .lower),
        CatalogExercise(name: "Leg Curl", equipment: .machine, bodyRegion: .lower),
        CatalogExercise(name: "Leg Extension", equipment: .machine, bodyRegion: .lower),
    ]

    /// Built-in lifts whose names contain `query`, ignoring case. Empty for an
    /// empty query or an exact match, so suggestions get out of the way once chosen.
    static func suggestions(for query: String, limit: Int = 5) -> [CatalogExercise] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              !all.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame })
        else { return [] }
        return Array(all.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(limit))
    }
}

/// Parsing typed weights.
nonisolated enum WeightInput {
    /// "137.5" or "137,5" → 137.5 in `unit`. Nil if it isn't a number.
    static func parse(_ text: String, unit: WeightUnit) -> Weight? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return Weight(value, unit)
    }
}

extension Equipment {
    nonisolated var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .machine: "Machine"
        }
    }
}

extension BodyRegion {
    nonisolated var displayName: String {
        switch self {
        case .upper: "Upper"
        case .lower: "Lower"
        }
    }
}
