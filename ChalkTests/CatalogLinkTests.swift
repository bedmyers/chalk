//
//  CatalogLinkTests.swift
//  ChalkTests
//

import ChalkCore
import Foundation
import SwiftData
import Testing
@testable import Chalk

@Suite("Catalog IDs")
struct CatalogIDTests {
    /// Catalog IDs are stored on exercises and synced, so they must never change.
    /// If this fails, an ID was renamed or removed: add a new one instead.
    @Test func idsAreStable() {
        let expected: Set = [
            "back-squat", "front-squat", "deadlift", "romanian-deadlift", "hip-thrust",
            "bench-press", "incline-bench-press", "overhead-press", "barbell-row",
            "db-bench-press", "incline-db-press", "db-shoulder-press", "db-row", "db-curl",
            "db-lateral-raise", "goblet-squat", "db-walking-lunge",
            "lat-pulldown", "seated-cable-row", "cable-triceps-pushdown", "face-pull",
            "leg-press", "leg-curl", "leg-extension",
        ]
        #expect(expected.isSubset(of: Set(ExerciseCatalog.all.map(\.id))))
    }

    @Test func idsAreUnique() {
        let ids = ExerciseCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test(arguments: [
        ("Bench Press", "bench-press"),
        ("  bench press ", "bench-press"),
        ("FACE PULL", "face-pull"),
    ])
    func matchingIgnoresCaseAndSpaces(name: String, id: String) {
        #expect(ExerciseCatalog.matching(name: name)?.id == id)
    }

    @Test func customNamesDontMatch() {
        #expect(ExerciseCatalog.matching(name: "Zercher Squat") == nil)
        #expect(ExerciseCatalog.matching(name: "Bench") == nil)
    }
}

@MainActor
@Suite("Catalog links on exercises")
struct CatalogLinkTests {
    let container: ModelContainer
    let context: ModelContext
    let program: Program
    let day: ProgramDay

    init() throws {
        container = try ChalkModelContainer.make(inMemory: true)
        context = container.mainContext
        program = ProgramLibrary.createProgram(named: "Test", unit: .pounds, in: context)
        day = program.addDay(named: "A", in: context)
    }

    func spec(_ name: String, catalogID: String? = nil) -> ExerciseSpec {
        var spec = ExerciseSpec.new(unit: .pounds)
        spec.name = name
        spec.catalogID = catalogID
        return spec
    }

    @Test func typingACatalogNameLinksIt() {
        let slot = program.addExercise(spec("bench press"), to: day, in: context)
        #expect(slot.catalogID == "bench-press")
    }

    @Test func customExercisesHaveNoLink() {
        let slot = program.addExercise(spec("Zercher Squat"), to: day, in: context)
        #expect(slot.catalogID == nil)
    }

    @Test func renamingKeepsTheLink() {
        let slot = program.addExercise(spec("Bench Press", catalogID: "bench-press"), to: day, in: context)
        var edited = slot.spec
        edited.name = "Flat Bench"

        let saved = slot.save(edited, in: context)

        #expect(saved === slot)
        #expect(saved.catalogID == "bench-press")
    }

    @Test func restartingCarriesTheLinkToTheSuccessor() {
        let slot = program.addExercise(spec("Bench Press", catalogID: "bench-press"), to: day, in: context)
        var edited = slot.spec
        edited.targetReps = 10

        let successor = slot.save(edited, in: context)

        #expect(successor !== slot)
        #expect(successor.catalogID == "bench-press")
    }

    @Test func workoutLogsSnapshotTheLink() throws {
        program.addExercise(spec("Face Pull"), to: day, in: context)
        let session = program.startSession(for: day, week: 1, in: context)
        #expect(session.sortedExerciseLogs.first?.catalogID == "face-pull")
    }

    @Test func templateProgramsLinkEveryLift() throws {
        let template = ProgramTemplate.pushPullLegs
        let weights = Dictionary(uniqueKeysWithValues: template.lifts.map { ($0.name, Weight.pounds(50)) })
        let built = try template.makeProgram(unit: .pounds, startingWeights: weights, in: context)

        #expect(built.activeSlots.allSatisfy { $0.catalogID != nil })
        #expect(built.activeSlots.first { $0.name == "Face Pull" }?.catalogID == "face-pull")
    }
}
