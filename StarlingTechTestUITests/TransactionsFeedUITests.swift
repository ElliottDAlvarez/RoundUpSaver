//
//  TransactionsFeedUITests.swift
//  StarlingTechTestUITests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import XCTest

final class TransactionsFeedUITests: StarlingUITestCase {

    @MainActor
    func testDisplaysTransactionsWithDirectionPrefix() {
        let app = XCUIApplication.launchForUITesting()
        openTransactionsFeed(app)

        let list = waitFor(app.collectionViews["transactionsList"])

        XCTAssertTrue(list.staticTexts["-£4.35"].waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(list.staticTexts["-£2.50"].exists)
        XCTAssertTrue(list.staticTexts["+£100.00"].exists)
        XCTAssertEqual(list.staticTexts.matching(identifier: "transactionAmount").count, 3)
    }

    @MainActor
    func testDisplaysWeeklyRoundUpSummary() {
        let app = XCUIApplication.launchForUITesting()
        openTransactionsFeed(app)

        XCTAssertTrue(waitFor(app.staticTexts["This week's round-up"]).exists)

        let amount = waitFor(app.staticTexts["roundUpAmount"])
        XCTAssertEqual(amount.label, Fixtures.roundUp)

        let saveButton = waitFor(app.buttons["saveRoundUpButton"])
        XCTAssertTrue(saveButton.isEnabled)
    }

    @MainActor
    func testSaveRoundUpOpensSavingsGoals() {
        let app = XCUIApplication.launchForUITesting()

        openSavingsGoalsViaRoundUp(app)

        XCTAssertEqual(waitFor(app.staticTexts["savingsRoundUpAmount"]).label, Fixtures.roundUp)
    }

    @MainActor
    func testSavingsToolbarButtonOpensSavingsGoals() {
        let app = XCUIApplication.launchForUITesting()

        openSavingsGoalsViaToolbar(app)

        XCTAssertTrue(waitFor(app.staticTexts[Fixtures.goalName]).exists)
    }

    @MainActor
    func testBackNavigationReturnsToAccounts() {
        let app = XCUIApplication.launchForUITesting()
        openTransactionsFeed(app)

        app.navigationBars[Fixtures.accountName].buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["accountRow_\(Fixtures.accountName)"].waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testShowsEmptyStateWithoutRoundUp() {
        let app = XCUIApplication.launchForUITesting(scenario: .emptyTransactions)
        openTransactionsFeed(app)

        XCTAssertEqual(waitFor(app.staticTexts["transactionsEmptyMessage"]).label, "No transactions found")
        XCTAssertFalse(app.staticTexts["roundUpAmount"].exists)
        XCTAssertFalse(app.buttons["saveRoundUpButton"].exists)
    }

    @MainActor
    func testShowsErrorState() {
        let app = XCUIApplication.launchForUITesting(scenario: .transactionsError)
        openTransactionsFeed(app)

        XCTAssertEqual(waitFor(app.staticTexts["transactionsErrorMessage"]).label,
                       "Error: Unable to load transactions")
    }
}
