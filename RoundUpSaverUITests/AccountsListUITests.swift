//
//  AccountsListUITests.swift
//  RoundUpSaverUITests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import XCTest

final class AccountsListUITests: BaseUITestCase {

    @MainActor
    func testDisplaysAccounts() {
        let app = XCUIApplication.launchForUITesting()

        waitFor(app.collectionViews["accountsList"])
        let row = waitFor(app.buttons["accountRow_\(Fixtures.accountName)"])

        // SwiftUI merges a button's child texts into a single accessibility label
        XCTAssertTrue(row.label.contains("PERSONAL"), "Unexpected label: \(row.label)")
        XCTAssertTrue(row.label.contains("PRIMARY"), "Unexpected label: \(row.label)")
        XCTAssertTrue(row.label.contains("GBP"), "Unexpected label: \(row.label)")
    }

    @MainActor
    func testTappingAccountOpensTransactionsFeed() {
        let app = XCUIApplication.launchForUITesting()

        openTransactionsFeed(app)

        waitFor(app.collectionViews["transactionsList"])
    }

    @MainActor
    func testShowsEmptyState() {
        let app = XCUIApplication.launchForUITesting(scenario: .emptyAccounts)

        let message = waitFor(app.staticTexts["accountsEmptyMessage"])
        XCTAssertEqual(message.label, "No accounts found")
        XCTAssertFalse(app.collectionViews["accountsList"].exists)
    }

    @MainActor
    func testShowsErrorStateWithRetry() {
        let app = XCUIApplication.launchForUITesting(scenario: .accountsError)

        let message = waitFor(app.staticTexts["accountsErrorMessage"])
        XCTAssertEqual(message.label, "Error: Unable to load accounts")

        // The stub always fails, so retrying lands back on the same error rather than a dead end
        waitFor(app.buttons["accountsRetryButton"]).tap()
        waitFor(app.staticTexts["accountsErrorMessage"])
    }
}
