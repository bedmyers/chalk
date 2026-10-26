//
//  WorkoutModeUITests.swift
//  ChalkUITests
//

import XCTest

/// Drives full-screen workout mode against in-memory sample history, where the
/// next workout is Push Day (Bench Press first, 4 sets).
final class WorkoutModeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    override func setUp() async throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// The on-screen button with this label. Neighboring pages are loaded too, so
    /// only the one on the visible page is hittable.
    @MainActor
    private func visibleButton(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex.first { $0.isHittable }
    }

    /// Uppercased for display, which also uppercases its accessibility label.
    @MainActor
    private func skipRest(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] 'Skip rest'")).firstMatch
    }

    @MainActor
    func testLoggingALiftRestsAndMovesToTheNextLift() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ChalkSampleHistory"]
        app.launch()

        // Button styles uppercase labels for display only.
        let start = app.buttons.matching(NSPredicate(format: "label ==[c] 'Start Workout'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let benchTitle = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Bench Press'")).firstMatch
        XCTAssertTrue(benchTitle.waitForExistence(timeout: 5), "Workout mode should open on the first lift")

        for set in 1...4 {
            let button = try XCTUnwrap(visibleButton("Set \(set), not logged", in: app), "Set \(set) should be on screen")
            button.tap()
            XCTAssertTrue(skipRest(in: app).waitForExistence(timeout: 2), "Logging a set starts rest")
        }

        // Finishing the last target set slides to the next lift.
        let next = expectation(for: NSPredicate { _, _ in
            app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Overhead Press'")).allElementsBoundByIndex.contains { $0.isHittable }
        }, evaluatedWith: nil)
        wait(for: [next], timeout: 5)

        // Rest keeps running across lifts until skipped.
        skipRest(in: app).tap()
        XCTAssertTrue(skipRest(in: app).waitForNonExistence(timeout: 2))

        // Jump to the summary and finish.
        app.buttons["Finish"].tap()
        let finish = app.buttons.matching(NSPredicate(format: "label ==[c] 'Finish Workout'")).allElementsBoundByIndex
        let finishButton = try XCTUnwrap(finish.first { $0.waitForExistence(timeout: 3) && $0.isHittable })
        finishButton.tap()

        // Back on Today, which has moved on to the next day.
        let pullDay = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Pull Day'")).firstMatch
        XCTAssertTrue(pullDay.waitForExistence(timeout: 5), "Finishing should close workout mode and move on")
    }

    @MainActor
    func testSteppingBackToTheListShowsLoggedSets() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ChalkSampleHistory"]
        app.launch()

        let start = app.buttons.matching(NSPredicate(format: "label ==[c] 'Start Workout'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let firstSet = app.buttons.matching(NSPredicate(format: "label == 'Set 1, not logged'")).allElementsBoundByIndex
        try XCTUnwrap(firstSet.first { $0.waitForExistence(timeout: 5) && $0.isHittable }).tap()
        app.buttons["Back to list"].tap()

        let resume = app.buttons.matching(NSPredicate(format: "label ==[c] 'Resume Workout'")).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5), "Today should know a workout is in progress")
        XCTAssertTrue(app.buttons["Set 1, 8 reps"].firstMatch.exists, "The set logged in workout mode should show in the list")
    }
}
