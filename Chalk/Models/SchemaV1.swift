//
//  SchemaV1.swift
//  Chalk
//

import Foundation
import SwiftData

/// The first shipped schema. Once this reaches TestFlight, fields can't be renamed
/// or removed: add a `SchemaV2` and a migration stage instead.
///
/// CloudKit rules for every model: no unique attributes, every stored property has
/// a default, every relationship is optional.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Program.self,
            ProgramDay.self,
            DayEntry.self,
            ExerciseSlot.self,
            WorkoutSession.self,
            ExerciseLog.self,
            SetLog.self,
        ]
    }
}

typealias Program = SchemaV1.Program
typealias ProgramDay = SchemaV1.ProgramDay
typealias DayEntry = SchemaV1.DayEntry
typealias ExerciseSlot = SchemaV1.ExerciseSlot
typealias WorkoutSession = SchemaV1.WorkoutSession
typealias ExerciseLog = SchemaV1.ExerciseLog
typealias SetLog = SchemaV1.SetLog

enum ChalkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum ChalkModelContainer {
    static let cloudKitContainerID = "iCloud.com.myers.Chalk"

    /// The app's container, synced to the iCloud private database. `inMemory`
    /// containers don't sync and are for tests and previews.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = if inMemory {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: ChalkMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
