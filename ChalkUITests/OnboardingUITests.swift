//
//  OnboardingUITests.swift
//  ChalkUITests
//

import XCTest

/// First launch, end to end, against an empty in-memory store.
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ChalkEmptyStore"]
        app.launch()
        return app
    }

    /// Buttons uppercase their labels, so match case-insensitively.
    @MainActor
    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    @MainActor
    func testTemplateWithStartLightLandsOnToday() throws {
        let app = launchFresh()

        XCTAssertTrue(button("Let's Go", in: app).waitForExistence(timeout: 5))
        button("Let's Go", in: app).tap()

        // Choice labels include their detail ("Pounds, LB").
        let pounds = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Pounds'")).firstMatch
        XCTAssertTrue(pounds.waitForExistence(timeout: 5))
        pounds.tap()

        let fullBody = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Full Body'")).firstMatch
        XCTAssertTrue(fullBody.waitForExistence(timeout: 5))
        fullBody.tap()

        // Weights are required: Start Training stays disabled until all nine are set.
        let start = button("Start Training", in: app)
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled)

        // Fill every lift with "Start light", scrolling as rows load.
        let startLight = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start ' AND label ENDSWITH ' light'"))
        var attempts = 0
        while startLight.count > 0, attempts < 20 {
            let next = startLight.firstMatch
            if next.isHittable {
                next.tap()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(start.isEnabled, "All lifts should be set")
        start.tap()

        // Today shows the first day with the empty bar on squats.
        let dayA = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Day A'")).firstMatch
        XCTAssertTrue(dayA.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Today"].isSelected)
    }

    @MainActor
    func testSetUpLaterShowsTheEmptyState() throws {
        let app = launchFresh()

        XCTAssertTrue(button("Set Up Later", in: app).waitForExistence(timeout: 5))
        button("Set Up Later", in: app).tap()

        XCTAssertTrue(button("Create Program", in: app).waitForExistence(timeout: 5))
    }
}
