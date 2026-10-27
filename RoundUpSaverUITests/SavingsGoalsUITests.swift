//
//  SavingsGoalsUITests.swift
//  RoundUpSaverUITests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import XCTest

final class SavingsGoalsUITests: BaseUITestCase {

    @MainActor
    func testDisplaysSavingsGoalsAndRoundUp() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.collectionViews["savingsGoalsList"])
        XCTAssertEqual(waitFor(app.staticTexts["savingsRoundUpAmount"]).label, Fixtures.roundUp)
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
        waitFor(alert.staticTexts["\(Fixtures.roundUp) has been added to \(Fixtures.goalName)."])
        alert.buttons["OK"].tap()

        // Round-up is consumed and the goal reflects the new balance
        waitForLabel(Fixtures.holidayProgressAfterTransfer,
                     on: app.staticTexts["savingsGoalProgress_\(Fixtures.goalName)"])
        waitForLabel("£0.00", on: app.staticTexts["savingsRoundUpAmount"])
        waitUntil("isEnabled == false", on: app.buttons["addRoundUpButton_\(Fixtures.goalName)"])
    }

    @MainActor
    func testTransferredRoundUpIsNotOfferedAgainOnFeed() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addRoundUpButton_\(Fixtures.goalName)"]).tap()
        waitFor(app.alerts["Savings goals"]).buttons["OK"].tap()
        waitUntil("exists == false", on: app.alerts["Savings goals"])

        goBack(from: "Savings goals", in: app)
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
        waitFor(alert.staticTexts["Transfer failed"])
        alert.buttons["OK"].tap()
        waitUntil("exists == false", on: alert)

        XCTAssertEqual(app.staticTexts["savingsRoundUpAmount"].label, Fixtures.roundUp)
        XCTAssertEqual(app.staticTexts["savingsGoalProgress_\(Fixtures.goalName)"].label,
                       Fixtures.holidayProgress)
        waitUntil("isEnabled == true", on: app.buttons["addRoundUpButton_\(Fixtures.goalName)"])
    }

    @MainActor
    func testEmptyStateAllowsCreatingFirstGoal() {
        let app = XCUIApplication.launchForUITesting(scenario: .emptySavingsGoals)
        openSavingsGoalsViaToolbar(app)

        waitFor(app.staticTexts["savingsGoalsEmptyMessage"])
        waitFor(app.buttons["createFirstSavingsGoalButton"]).tap()

        createGoal(in: app, name: "New Car", target: nil)

        waitFor(app.staticTexts["New Car"])
        XCTAssertEqual(waitFor(app.staticTexts["savingsGoalProgress_New Car"]).label, "Saved £0.00")
        XCTAssertFalse(app.staticTexts["savingsGoalsEmptyMessage"].exists)
    }

    @MainActor
    func testCreateGoalWithTargetFromToolbar() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addSavingsGoalToolbarButton"]).tap()

        createGoal(in: app, name: "Emergency Fund", target: "250")

        waitFor(app.staticTexts["Emergency Fund"])
        XCTAssertEqual(waitFor(app.staticTexts["savingsGoalProgress_Emergency Fund"]).label,
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
        waitUntil("isEnabled == false", on: createButton)

        nameField.typeText("Gadgets")
        waitUntil("isEnabled == true", on: createButton)
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
    func testInvalidTargetShowsInlineErrorAndKeepsForm() {
        let app = XCUIApplication.launchForUITesting()
        openSavingsGoalsViaRoundUp(app)

        waitFor(app.buttons["addSavingsGoalToolbarButton"]).tap()

        fillGoalForm(in: app, name: "Bad Target", target: "0")
        app.buttons["confirmCreateSavingsGoalButton"].tap()

        // The form stays open with the user's input so they can correct it
        XCTAssertEqual(waitFor(app.staticTexts["createSavingsGoalErrorMessage"]).label,
                       "Please enter a valid target amount.")
        XCTAssertTrue(app.navigationBars["New savings goal"].exists)

        app.buttons["cancelCreateSavingsGoalButton"].tap()
        waitUntil("exists == false", on: app.navigationBars["New savings goal"])
        XCTAssertFalse(app.staticTexts["Bad Target"].exists)
    }

    // MARK: - Helpers

    @MainActor
    private func fillGoalForm(in app: XCUIApplication, name: String, target: String?) {
        waitFor(app.navigationBars["New savings goal"])

        let nameField = waitFor(app.textFields["savingsGoalNameField"])
        nameField.tap()
        nameField.typeText(name)

        if let target {
            let targetField = app.textFields["savingsGoalTargetField"]
            targetField.tap()
            targetField.typeText(target)
        }

        waitUntil("isEnabled == true", on: app.buttons["confirmCreateSavingsGoalButton"])
    }

    @MainActor
    private func createGoal(in app: XCUIApplication, name: String, target: String?) {
        fillGoalForm(in: app, name: name, target: target)
        app.buttons["confirmCreateSavingsGoalButton"].tap()
        waitUntil("exists == false", on: app.navigationBars["New savings goal"])
    }
}
