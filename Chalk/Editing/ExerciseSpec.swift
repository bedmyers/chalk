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
    /// A rep wave, one value per block week. Empty means `targetReps` every week.
    var repsByWeek: [Int] = []
    var increment: Weight
    /// The starting weight for a new exercise, or the current weight for an existing one.
    var weight: Weight
    /// The built-in lift this is, if any. Powers exercise info and substitutions.
    var catalogID: String? = nil

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
            || repsByWeek != original.repsByWeek
            || increment != original.increment
            || equipment != original.equipment
            || weight != original.weight
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The catalog link to save: the chosen lift, or one whose name was typed exactly.
    var resolvedCatalogID: String? {
        catalogID ?? ExerciseCatalog.matching(name: name)?.id
    }
}

/// A built-in lift that prefills equipment and body region. Free-text names are still allowed.
nonisolated struct CatalogExercise: Sendable, Hashable, Identifiable {
    /// Stable identifier stored on exercises (`ExerciseSlot.catalogID`). Never change
    /// or reuse one: saved data refers to it. Display names can change freely.
    let id: String
    let name: String
    let equipment: Equipment
    let bodyRegion: BodyRegion
}

nonisolated enum ExerciseCatalog {
    static let all: [CatalogExercise] = [
        // Barbell
        CatalogExercise(id: "back-squat", name: "Back Squat", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(id: "front-squat", name: "Front Squat", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(id: "deadlift", name: "Deadlift", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(id: "romanian-deadlift", name: "Romanian Deadlift", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(id: "hip-thrust", name: "Hip Thrust", equipment: .barbell, bodyRegion: .lower),
        CatalogExercise(id: "bench-press", name: "Bench Press", equipment: .barbell, bodyRegion: .upper),
        CatalogExercise(id: "incline-bench-press", name: "Incline Bench Press", equipment: .barbell, bodyRegion: .upper),
        CatalogExercise(id: "overhead-press", name: "Overhead Press", equipment: .barbell, bodyRegion: .upper),
        CatalogExercise(id: "barbell-row", name: "Barbell Row", equipment: .barbell, bodyRegion: .upper),
        // Dumbbell
        CatalogExercise(id: "db-bench-press", name: "DB Bench Press", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(id: "incline-db-press", name: "Incline DB Press", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(id: "db-shoulder-press", name: "DB Shoulder Press", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(id: "db-row", name: "DB Row", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(id: "db-curl", name: "DB Curl", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(id: "db-lateral-raise", name: "DB Lateral Raise", equipment: .dumbbell, bodyRegion: .upper),
        CatalogExercise(id: "goblet-squat", name: "Goblet Squat", equipment: .dumbbell, bodyRegion: .lower),
        CatalogExercise(id: "db-walking-lunge", name: "DB Walking Lunge", equipment: .dumbbell, bodyRegion: .lower),
        // Machine / cable
        CatalogExercise(id: "lat-pulldown", name: "Lat Pulldown", equipment: .machine, bodyRegion: .upper),
        CatalogExercise(id: "seated-cable-row", name: "Seated Cable Row", equipment: .machine, bodyRegion: .upper),
        CatalogExercise(id: "cable-triceps-pushdown", name: "Cable Triceps Pushdown", equipment: .machine, bodyRegion: .upper),
        CatalogExercise(id: "face-pull", name: "Face Pull", equipment: .machine, bodyRegion: .upper),
        CatalogExercise(id: "leg-press", name: "Leg Press", equipment: .machine, bodyRegion: .lower),
        CatalogExercise(id: "leg-curl", name: "Leg Curl", equipment: .machine, bodyRegion: .lower),
        CatalogExercise(id: "leg-extension", name: "Leg Extension", equipment: .machine, bodyRegion: .lower),
        // Bodyweight
        CatalogExercise(id: "pull-up", name: "Pull-Up", equipment: .bodyweight, bodyRegion: .upper),
        CatalogExercise(id: "dip", name: "Dip", equipment: .bodyweight, bodyRegion: .upper),
    ]

    /// The built-in lift with exactly this name.
    static func named(_ name: String) -> CatalogExercise? {
        all.first { $0.name == name }
    }

    /// The built-in lift with this stable ID.
    static func withID(_ id: String) -> CatalogExercise? {
        all.first { $0.id == id }
    }

    /// The built-in lift whose name matches, ignoring case and surrounding spaces,
    /// so a typed "bench press" still links to the catalog.
    static func matching(name: String) -> CatalogExercise? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

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
        case .bodyweight: "Bodyweight"
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

/// How weights read on screen.
nonisolated enum WeightLabel {
    /// Shown in place of a weight for bodyweight lifts.
    static let bodyweight = "BW"

    /// "185 lb", or "BW" for bodyweight lifts.
    static func text(_ weight: Weight, equipment: Equipment) -> String {
        equipment.isWeighted ? weight.description : bodyweight
    }

    /// "185", or "BW" for bodyweight lifts.
    static func value(_ weight: Weight, equipment: Equipment) -> String {
        equipment.isWeighted ? weight.formattedValue : bodyweight
    }
}
