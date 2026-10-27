//
//  UITestSupport.swift
//  RoundUpSaverUITests
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
    /// Launches the app with stubbed dependencies, a fixed clock (set by the app's UI test dependencies),
    /// and a fixed locale and time zone, so every run renders exactly the same text.
    static func launchForUITesting(scenario: UITestScenario = .standard) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting", "-AppleLocale", "en_GB", "-AppleLanguages", "(en)"]
        app.launchEnvironment["UITEST_SCENARIO"] = scenario.rawValue
        app.launchEnvironment["TZ"] = "Europe/London"
        app.launch()
        return app
    }
}

class BaseUITestCase: XCTestCase {
    /// Generous enough for a cold simulator on CI; waits return as soon as the condition is met.
    static let timeout: TimeInterval = 15

    /// Tests that deliberately run in several UI configurations override this to keep XCTest's orientation.
    class var resetsOrientation: Bool { true }

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Launch tests run in every UI configuration (including landscape) and leave the device rotated.
        // Resetting here keeps each test independent of the order the suite runs in.
        if Self.resetsOrientation {
            MainActor.assumeIsolated {
                XCUIDevice.shared.orientation = .portrait
            }
        }
    }

    @MainActor
    @discardableResult
    func waitFor(_ element: XCUIElement,
                 timeout: TimeInterval = BaseUITestCase.timeout,
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
                   timeout: TimeInterval = BaseUITestCase.timeout,
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

    @MainActor
    func waitForLabel(_ label: String,
                      on element: XCUIElement,
                      file: StaticString = #filePath,
                      line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label),
                                                    object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: Self.timeout), .completed,
                       "Timed out waiting for label '\(label)' on \(element)",
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

    @MainActor
    func goBack(from navigationBarTitle: String, in app: XCUIApplication) {
        waitFor(app.navigationBars[navigationBarTitle]).buttons.element(boundBy: 0).tap()
    }
}
