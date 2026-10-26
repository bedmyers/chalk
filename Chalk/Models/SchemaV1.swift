//
//  SchemaV1.swift
//  Chalk
//

import CoreData
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
        var configuration = if inMemory {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
        }
        #if DEBUG
        if !inMemory, ProcessInfo.processInfo.arguments.contains(initializeCloudKitSchemaArgument) {
            try initializeCloudKitSchema(storeURL: configuration.url)
            // Core Data keeps the real store for this run, so the app gets a blank
            // in-memory one. Relaunch without the argument to see your data again.
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        #endif
        return try ModelContainer(
            for: schema,
            migrationPlan: ChalkMigrationPlan.self,
            configurations: [configuration]
        )
    }

    #if DEBUG
    /// Launch argument that pushes the full schema to the CloudKit *development*
    /// environment. Run once after any model change, then deploy to production in
    /// CloudKit Console. It blocks syncing while it runs, so it's never automatic.
    static let initializeCloudKitSchemaArgument = "-ChalkInitializeCloudKitSchema"

    /// Kept alive for the rest of the run. Removing its store while CloudKit
    /// mirroring is still working crashes ("…has no persistent stores…").
    private static var schemaContainer: NSPersistentCloudKitContainer?

    /// Uploads representative records for every model so CloudKit learns each record
    /// type and field, then removes them. SwiftData has no API for this, so it goes
    /// through Core Data's CloudKit container on the same store file.
    private static func initializeCloudKitSchema(storeURL: URL) throws {
        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: cloudKitContainerID
        )
        description.shouldAddStoreAsynchronously = false

        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models) else {
            throw CocoaError(.coderInvalidValue)
        }
        let container = NSPersistentCloudKitContainer(name: "Chalk", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        try container.initializeCloudKitSchema()
        schemaContainer = container
        print("Chalk: CloudKit schema uploaded to the development environment.")
    }
    #endif
}
