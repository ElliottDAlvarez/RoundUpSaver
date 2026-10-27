//
//  RoundUpSaverUITestsLaunchTests.swift
//  RoundUpSaverUITests
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import XCTest

final class RoundUpSaverUITestsLaunchTests: BaseUITestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override class var resetsOrientation: Bool {
        false
    }

    /// Captures the first screen in each UI configuration (light/dark, orientation).
    /// Uses stubbed data so the screenshot is identical every run.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication.launchForUITesting()

        waitFor(app.buttons["accountRow_\(Fixtures.accountName)"])

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Only meaningful as a trend; there is no baseline, so it never fails on timing alone
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            _ = XCUIApplication.launchForUITesting()
        }
    }
}
