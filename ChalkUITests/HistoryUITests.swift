//
//  HistoryUITests.swift
//  ChalkUITests
//

import XCTest

/// Drives History in the real app against in-memory sample history
/// (three passed weeks of Push / Pull / Legs).
final class HistoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchWithSampleHistory() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ChalkSampleHistory"]
        app.launch()
        return app
    }

    @MainActor
    func testOpeningAndEditingAPastWorkout() throws {
        let app = launchWithSampleHistory()

        app.buttons["History"].tap()
        // Names are uppercased for display only; labels keep their case.
        let firstWorkout = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Leg Day'")).firstMatch
        XCTAssertTrue(firstWorkout.waitForExistence(timeout: 5))
        firstWorkout.tap()

        let firstSet = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Set 1'")).firstMatch
        XCTAssertTrue(firstSet.waitForExistence(timeout: 5), "Workout detail should list sets")

        app.navigationBars.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Workout"].waitForExistence(timeout: 5))

        // An extra set doesn't change any current weight, so this saves without asking.
        app.buttons["Add Set"].firstMatch.tap()
        app.navigationBars.buttons["Save"].tap()

        XCTAssertFalse(app.staticTexts["This changes your current weight"].exists, "An extra set shouldn't change weights")
        let editBar = app.navigationBars["Edit Workout"]
        XCTAssertTrue(editBar.waitForNonExistence(timeout: 5), "Saving should close the sheet")

        let fifthSet = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Set 5'")).firstMatch
        XCTAssertTrue(fifthSet.waitForExistence(timeout: 5), "The added set should be saved")
    }

    @MainActor
    func testHistoryIsReachableWithoutAnActiveProgram() throws {
        let app = launchWithSampleHistory()

        app.buttons["Program"].tap()
        let archive = app.buttons["Archive Program"]
        // The list loads rows lazily; the button is below the fold.
        for _ in 0..<3 where !archive.exists {
            app.swipeUp()
        }
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        archive.tap()
        // Confirm in the dialog. Its button shares the list button's label, and the
        // list's is covered while the dialog is up, so tap whichever is hittable.
        let matches = app.buttons.matching(identifier: "Archive Program")
        XCTAssertTrue(matches.element(boundBy: 1).waitForExistence(timeout: 5), "Archiving should ask first")
        let confirm = (0..<matches.count).map { matches.element(boundBy: $0) }.first { $0.isHittable }
        try XCTUnwrap(confirm).tap()
        // Button styles uppercase their labels ("CREATE PROGRAM").
        let createProgram = app.buttons.matching(NSPredicate(format: "label ==[c] 'Create Program'")).firstMatch
        XCTAssertTrue(createProgram.waitForExistence(timeout: 5), "Program tab should offer to start over")

        app.buttons["History"].tap()
        let archivedWorkout = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Push Pull Legs'")).firstMatch
        XCTAssertTrue(archivedWorkout.waitForExistence(timeout: 5), "Archived program's workouts stay in History")
    }

    @MainActor
    func testExerciseHistoryShowsBlocks() throws {
        let app = launchWithSampleHistory()

        app.buttons["History"].tap()
        app.buttons["Exercises"].tap()
        let bench = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Blocks'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Up to 190"].exists, "The passed block should show its bump")
    }
}
