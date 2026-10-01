//
//  SavingsGoalsUITests.swift
//  StarlingTechTestUITests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import XCTest

final class SavingsGoalsUITests: StarlingUITestCase {

    @MainActor
    func testDisplaysSavingsGoalsAndRoundUp() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.collectionViews["savingsGoalsList"])
        XCTAssertEqual(app.staticTexts["savingsRoundUpAmount"].label, Fixtures.roundUp)
        XCTAssertTrue(app.staticTexts[Fixtures.goalName].exists)
        XCTAssertEqual(app.staticTexts["savingsGoalProgress_\(Fixtures.goalName)"].label,
                       Fixtures.holidayProgress)
        XCTAssertTrue(app.buttons["addRoundUpButton_\(Fixtures.goalName)"].isEnabled)
    }

    @MainActor
    func testTransferRoundUpToGoal() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addRoundUpButton_\(Fixtures.goalName)"]).tap()

        let alert = waitFor(app.alerts["Savings goals"])
        XCTAssertTrue(alert.staticTexts["\(Fixtures.roundUp) has been added to \(Fixtures.goalName)."].exists)
        alert.buttons["OK"].tap()

        // Round-up is consumed and the goal reflects the new balance
        waitUntil("label == '\(Fixtures.holidayProgressAfterTransfer)'",
                  on: app.staticTexts["savingsGoalProgress_\(Fixtures.goalName)"])
        XCTAssertEqual(app.staticTexts["savingsRoundUpAmount"].label, "£0.00")
        XCTAssertFalse(app.buttons["addRoundUpButton_\(Fixtures.goalName)"].isEnabled)
    }

    @MainActor
    func testTransferredRoundUpIsNotOfferedAgainOnFeed() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addRoundUpButton_\(Fixtures.goalName)"]).tap()
        waitFor(app.alerts["Savings goals"]).buttons["OK"].tap()

        app.navigationBars["Savings goals"].buttons.element(boundBy: 0).tap()
        waitFor(app.navigationBars[Fixtures.accountName])

        // Already rounded-up transactions are excluded, so the summary is hidden
        waitUntil("exists == false", on: app.buttons["saveRoundUpButton"])
        XCTAssertFalse(app.staticTexts["roundUpAmount"].exists)
    }

    @MainActor
    func testTransferFailureShowsAlertAndAllowsRetry() {
        let app = XCUIApplication.launchForUITesting(scenario: .transferError)
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addRoundUpButton_\(Fixtures.goalName)"]).tap()

        let alert = waitFor(app.alerts["Savings goals"])
        XCTAssertTrue(alert.staticTexts["Transfer failed"].exists)
        alert.buttons["OK"].tap()

        XCTAssertEqual(app.staticTexts["savingsRoundUpAmount"].label, Fixtures.roundUp)
        XCTAssertEqual(app.staticTexts["savingsGoalProgress_\(Fixtures.goalName)"].label,
                       Fixtures.holidayProgress)
        XCTAssertTrue(app.buttons["addRoundUpButton_\(Fixtures.goalName)"].isEnabled)
    }

    @MainActor
    func testEmptyStateAllowsCreatingFirstGoal() {
        let app = XCUIApplication.launchForUITesting(scenario: .emptySavingsGoals)
        openSavingsGoalsViaToolbar(app)

        waitFor(app.staticTexts["savingsGoalsEmptyMessage"])
        waitFor(app.buttons["createFirstSavingsGoalButton"]).tap()

        createGoal(in: app, name: "New Car", target: nil)

        waitFor(app.staticTexts["New Car"])
        XCTAssertEqual(app.staticTexts["savingsGoalProgress_New Car"].label, "Saved £0.00")
        XCTAssertFalse(app.staticTexts["savingsGoalsEmptyMessage"].exists)
    }

    @MainActor
    func testCreateGoalWithTargetFromToolbar() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addSavingsGoalToolbarButton"]).tap()

        createGoal(in: app, name: "Emergency Fund", target: "250")

        waitFor(app.staticTexts["Emergency Fund"])
        XCTAssertEqual(app.staticTexts["savingsGoalProgress_Emergency Fund"].label,
                       "Saved £0.00 of £250.00")
        XCTAssertTrue(app.staticTexts[Fixtures.goalName].exists)
    }

    @MainActor
    func testCreateButtonDisabledUntilNameEntered() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addSavingsGoalToolbarButton"]).tap()

        let createButton = waitFor(app.buttons["confirmCreateSavingsGoalButton"])
        XCTAssertFalse(createButton.isEnabled)

        let nameField = waitFor(app.textFields["savingsGoalNameField"])
        nameField.tap()
        nameField.typeText("   ")
        XCTAssertFalse(createButton.isEnabled)

        nameField.typeText("Gadgets")
        XCTAssertTrue(createButton.isEnabled)
    }

    @MainActor
    func testCancelDismissesCreateSheetWithoutCreatingGoal() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addSavingsGoalToolbarButton"]).tap()

        let nameField = waitFor(app.textFields["savingsGoalNameField"])
        nameField.tap()
        nameField.typeText("Discarded")

        app.buttons["cancelCreateSavingsGoalButton"].tap()

        waitUntil("exists == false", on: app.navigationBars["New savings goal"])
        XCTAssertFalse(app.staticTexts["Discarded"].exists)
    }

    @MainActor
    func testInvalidTargetShowsValidationAlert() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addSavingsGoalToolbarButton"]).tap()

        createGoal(in: app, name: "Bad Target", target: "0")

        let alert = waitFor(app.alerts["Savings goals"])
        XCTAssertTrue(alert.staticTexts["Please enter a valid target amount."].exists)
        alert.buttons["OK"].tap()

        XCTAssertFalse(app.staticTexts["Bad Target"].exists)
    }

    // MARK: - Helpers

    @MainActor
    private func createGoal(in app: XCUIApplication, name: String, target: String?) {
        waitFor(app.navigationBars["New savings goal"])

        let nameField = waitFor(app.textFields["savingsGoalNameField"])
        nameField.tap()
        nameField.typeText(name)

        if let target {
            let targetField = app.textFields["savingsGoalTargetField"]
            targetField.tap()
            targetField.typeText(target)
        }

        app.buttons["confirmCreateSavingsGoalButton"].tap()
        waitUntil("exists == false", on: app.navigationBars["New savings goal"])
    }
}
