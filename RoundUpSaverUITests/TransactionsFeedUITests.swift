//
//  TransactionsFeedUITests.swift
//  RoundUpSaverUITests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import XCTest

final class TransactionsFeedUITests: BaseUITestCase {

    @MainActor
    func testDisplaysTransactionsWithDirectionPrefix() {
        let app = XCUIApplication.launchForUITesting()
        openTransactionsFeed(app)

        let list = waitFor(app.collectionViews["transactionsList"])

        waitFor(list.staticTexts["-£4.35"])
        XCTAssertTrue(list.staticTexts["-£2.50"].exists)
        XCTAssertTrue(list.staticTexts["+£100.00"].exists)
        XCTAssertEqual(list.staticTexts.matching(identifier: "transactionAmount").count, 3)
    }

    @MainActor
    func testDisplaysWeeklyRoundUpSummary() {
        let app = XCUIApplication.launchForUITesting()
        openTransactionsFeed(app)

        waitFor(app.staticTexts["This week's round-up"])
        XCTAssertEqual(waitFor(app.staticTexts["roundUpAmount"]).label, Fixtures.roundUp)
        XCTAssertTrue(waitFor(app.buttons["saveRoundUpButton"]).isEnabled)
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

        waitFor(app.staticTexts[Fixtures.goalName])
    }

    @MainActor
    func testBackNavigationReturnsToAccounts() {
        let app = XCUIApplication.launchForUITesting()
        openTransactionsFeed(app)

        goBack(from: Fixtures.accountName, in: app)

        waitFor(app.buttons["accountRow_\(Fixtures.accountName)"])
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
    func testShowsErrorStateWithRetry() {
        let app = XCUIApplication.launchForUITesting(scenario: .transactionsError)
        openTransactionsFeed(app)

        XCTAssertEqual(waitFor(app.staticTexts["transactionsErrorMessage"]).label,
                       "Error: Unable to load transactions")

        waitFor(app.buttons["transactionsRetryButton"]).tap()
        waitFor(app.staticTexts["transactionsErrorMessage"])
    }
}
