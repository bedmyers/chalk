//
//  ProgramDay.swift
//  Chalk
//

import Foundation
import SwiftData

extension SchemaV1 {
    /// One day of a program's weekly template, e.g. "Push Day".
    @Model
    final class ProgramDay {
        var id: UUID = UUID()
        var name: String = ""
        var order: Int = 0
        var program: Program?

        @Relationship(deleteRule: .cascade, inverse: \DayEntry.day)
        var entries: [DayEntry]? = []

        /// Sessions are owned by the program; deleting a day keeps its history.
        @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.day)
        var sessions: [WorkoutSession]? = []

        init(name: String, order: Int) {
            self.name = name
            self.order = order
        }

        var sortedEntries: [DayEntry] {
            (entries ?? []).sorted { $0.order < $1.order }
        }
    }

    /// Places an exercise slot on a day. A slot on several days shares one weight
    /// and needs all of those sessions to hit for the week to count.
    @Model
    final class DayEntry {
        var id: UUID = UUID()
        var order: Int = 0
        var day: ProgramDay?
        var slot: ExerciseSlot?

        init(order: Int) {
            self.order = order
        }
    }
}
