//  PassPouch — Testing Foundation (Phase 5)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import XCTest

/// Minimal UI smoke tests: the app must launch cleanly and its main
/// (database picker) screen must be reachable, including Settings navigation.
/// Full unlock-flow UI tests need a database fixture placed in the simulator
/// and are documented as a follow-up (see docs/phase-5-report.md).
final class KeePassiumUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppLaunchesToDatabasePicker() {
        XCTAssertEqual(app.state, .runningForeground, "App must stay in the foreground (no crash)")
        // The database picker screen carries a Settings toolbar button
        // (accessibilityIdentifier "settings_button", set in code).
        let settingsButton = app.buttons["settings_button"]
        let appeared = settingsButton.waitForExistence(timeout: 15)
        XCTAssertTrue(appeared, "Database picker screen with Settings button must appear after launch")
    }

    func testSettingsNavigation() {
        // First launch with no databases shows the onboarding sheet, which
        // covers the toolbar — walk through it with Skip/Continue.
        for _ in 0..<6 {
            let skipButton = app.buttons["Skip"]
            let continueButton = app.buttons["Continue"]
            if skipButton.exists && skipButton.isHittable {
                skipButton.tap()
            } else if continueButton.exists && continueButton.isHittable {
                continueButton.tap()
            } else {
                break
            }
        }

        let settingsButton = app.buttons["settings_button"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 15) && settingsButton.isHittable,
            "Settings entry point must be reachable from the database picker")
        settingsButton.tap()
        let settingsScreen = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsScreen.waitForExistence(timeout: 10),
            "Tapping Settings must open the Settings screen")
    }
}
