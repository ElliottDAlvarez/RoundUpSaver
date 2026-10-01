//
//  UITestSupport.swift
//  StarlingTechTestUITests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import XCTest

/// Mirrors `UITestScenario` in the app target. Keep raw values in sync.
enum UITestScenario: String {
    case standard
    case emptyAccounts
    case accountsError
    case emptyTransactions
    case transactionsError
    case emptySavingsGoals
    case transferError
}

/// Values matching the stub fixtures in `UITestingDependencies.swift`.
enum Fixtures {
    static let accountName = "Personal"
    static let goalName = "Holiday"
    static let roundUp = "£1.15"
    static let holidayProgress = "Saved £10.00 of £500.00"
    static let holidayProgressAfterTransfer = "Saved £11.15 of £500.00"
}

extension XCUIApplication {
    /// Launches the app with stubbed dependencies and a fixed locale so currency strings are deterministic.
    static func launchForUITesting(scenario: UITestScenario = .standard) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting", "-AppleLocale", "en_GB", "-AppleLanguages", "(en)"]
        app.launchEnvironment["UITEST_SCENARIO"] = scenario.rawValue
        app.launch()
        return app
    }
}

class StarlingUITestCase: XCTestCase {
    static let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    @discardableResult
    func waitFor(_ element: XCUIElement,
                 timeout: TimeInterval = StarlingUITestCase.timeout,
                 file: StaticString = #filePath,
                 line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "Timed out waiting for \(element)",
                      file: file,
                      line: line)
        return element
    }

    @MainActor
    func waitUntil(_ predicateFormat: String,
                   on element: XCUIElement,
                   timeout: TimeInterval = StarlingUITestCase.timeout,
                   file: StaticString = #filePath,
                   line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicateFormat),
                                                    object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Timed out waiting for '\(predicateFormat)' on \(element)",
                       file: file,
                       line: line)
    }

    // MARK: - Navigation

    @MainActor
    func openTransactionsFeed(_ app: XCUIApplication) {
        waitFor(app.buttons["accountRow_\(Fixtures.accountName)"]).tap()
        waitFor(app.navigationBars[Fixtures.accountName])
    }

    @MainActor
    func openSavingsGoalsViaRoundUp(_ app: XCUIApplication) {
        openTransactionsFeed(app)
        waitFor(app.buttons["saveRoundUpButton"]).tap()
        waitFor(app.navigationBars["Savings goals"])
    }

    @MainActor
    func openSavingsGoalsViaToolbar(_ app: XCUIApplication) {
        openTransactionsFeed(app)
        waitFor(app.buttons["savingsToolbarButton"]).tap()
        waitFor(app.navigationBars["Savings goals"])
    }
}
