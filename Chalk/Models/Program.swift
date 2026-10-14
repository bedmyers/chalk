//
//  Program.swift
//  Chalk
//

import ChalkCore
import Foundation
import SwiftData

extension SchemaV1 {
    /// A training program: a weekly template of days, repeated every training week.
    @Model
    final class Program {
        var id: UUID = UUID()
        var name: String = ""
        /// Every weight in the program uses this unit. Changing the app setting
        /// never converts an existing program.
        var unitRaw: String = WeightUnit.pounds.rawValue
        var createdAt: Date = Date.now
        /// Archiving is the normal way to retire a program; it keeps all history.
        var archivedAt: Date? = nil

        @Relationship(deleteRule: .cascade, inverse: \ProgramDay.program)
        var days: [ProgramDay]? = []

        @Relationship(deleteRule: .cascade, inverse: \ExerciseSlot.program)
        var slots: [ExerciseSlot]? = []

        /// Cascades so a hard delete leaves no orphaned sessions, logs, or sets.
        @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.program)
        var sessions: [WorkoutSession]? = []

        init(name: String, unit: WeightUnit) {
            self.name = name
            self.unitRaw = unit.rawValue
        }

        var unit: WeightUnit {
            get { WeightUnit(rawValue: unitRaw) ?? .pounds }
            set { unitRaw = newValue.rawValue }
        }

        var isArchived: Bool { archivedAt != nil }

        var sortedDays: [ProgramDay] {
            (days ?? []).sorted { $0.order < $1.order }
        }
    }
}
