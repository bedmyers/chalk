//
//  ExerciseSlot.swift
//  Chalk
//

import ChalkCore
import Foundation
import SwiftData

/// The progression scheme an exercise slot uses. Stored by raw value, so new
/// cases can be added without a migration.
nonisolated enum ProgressionRuleKind: String, CaseIterable, Sendable {
    case threeWeekBlock

    var rule: any ProgressionRule {
        switch self {
        case .threeWeekBlock: ThreeWeekBlockRule()
        }
    }
}

extension SchemaV1 {
    /// One progression track: an exercise with a target, an increment, and a starting weight.
    ///
    /// Changing targets archives the slot and starts a new one from the current
    /// weight, so old weeks are never re-judged. Slots that share a `lineageID`
    /// are shown as one continuous exercise.
    @Model
    final class ExerciseSlot {
        var id: UUID = UUID()
        var lineageID: UUID = UUID()
        var name: String = ""
        var equipmentRaw: String = Equipment.barbell.rawValue
        var bodyRegionRaw: String = BodyRegion.lower.rawValue
        var targetSets: Int = 3
        var targetReps: Int = 8
        /// A rep wave, one value per block week ("6,8,10"). Empty means
        /// `targetReps` every week.
        var repsByWeekRaw: String = ""
        var incrementThousandths: Int = 0
        var startingWeightThousandths: Int = 0
        var progressionRuleRaw: String = ProgressionRuleKind.threeWeekBlock.rawValue
        /// The built-in lift this is (`CatalogExercise.id`), or nil for a custom one.
        /// Powers exercise info and substitution suggestions.
        var catalogID: String? = nil
        var createdAt: Date = Date.now
        var archivedAt: Date? = nil
        var program: Program?

        @Relationship(deleteRule: .cascade, inverse: \DayEntry.slot)
        var entries: [DayEntry]? = []

        /// Logs belong to sessions; deleting a slot keeps its history.
        @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.slot)
        var logs: [ExerciseLog]? = []

        init(
            name: String,
            equipment: Equipment,
            bodyRegion: BodyRegion,
            targetSets: Int,
            targetReps: Int,
            repsByWeek: [Int] = [],
            increment: Weight,
            startingWeight: Weight,
            lineageID: UUID = UUID(),
            catalogID: String? = nil
        ) {
            self.catalogID = catalogID
            self.name = name
            self.equipmentRaw = equipment.rawValue
            self.bodyRegionRaw = bodyRegion.rawValue
            self.targetSets = targetSets
            self.targetReps = repsByWeek.first ?? targetReps
            self.repsByWeekRaw = RepWave.raw(repsByWeek)
            self.incrementThousandths = increment.thousandths
            self.startingWeightThousandths = startingWeight.thousandths
            self.lineageID = lineageID
        }

        var unit: WeightUnit { program?.unit ?? .pounds }

        var equipment: Equipment {
            get { Equipment(rawValue: equipmentRaw) ?? .barbell }
            set { equipmentRaw = newValue.rawValue }
        }

        var bodyRegion: BodyRegion {
            get { BodyRegion(rawValue: bodyRegionRaw) ?? .lower }
            set { bodyRegionRaw = newValue.rawValue }
        }

        var progressionRule: ProgressionRuleKind {
            ProgressionRuleKind(rawValue: progressionRuleRaw) ?? .threeWeekBlock
        }

        /// The rep wave, or empty for the same reps every week.
        var repsByWeek: [Int] { RepWave.parse(repsByWeekRaw) }

        var increment: Weight { Weight(thousandths: incrementThousandths, unit: unit) }
        var startingWeight: Weight { Weight(thousandths: startingWeightThousandths, unit: unit) }
        var isArchived: Bool { archivedAt != nil }
    }
}

/// Stores a rep wave as text so it syncs as a plain CloudKit field.
nonisolated enum RepWave {
    static func raw(_ reps: [Int]) -> String {
        reps.map(String.init).joined(separator: ",")
    }

    /// "6,8,10" → [6, 8, 10]. Anything unreadable means no wave.
    static func parse(_ raw: String) -> [Int] {
        let parts = raw.split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        let reps = parts.compactMap { $0 }
        return reps.count == parts.count && reps.allSatisfy { $0 > 0 } ? reps : []
    }

    /// "6/8/10", or "8" for the same reps every week.
    static func text(reps: Int, repsByWeek: [Int]) -> String {
        repsByWeek.isEmpty ? "\(reps)" : repsByWeek.map(String.init).joined(separator: "/")
    }
}
