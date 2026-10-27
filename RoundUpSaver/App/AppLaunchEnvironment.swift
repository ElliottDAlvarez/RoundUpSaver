//
//  AppLaunchEnvironment.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation

/// How the process was launched. Used to pick the dependency graph at start-up.
enum AppLaunchEnvironment: Equatable {
    /// Normal launch, using the live API and on-disk cache.
    case live
    /// Hosting the unit test bundle. The app shows nothing, so tests never trigger network or disk work.
    case unitTests
    #if DEBUG
    /// Launched by the UI test target with stubbed, deterministic dependencies.
    case uiTests(UITestScenario)
    #endif

    static func current(processInfo: ProcessInfo = .processInfo) -> AppLaunchEnvironment {
        #if DEBUG
        if UITestConfiguration.isUITesting(processInfo: processInfo) {
            return .uiTests(UITestConfiguration.scenario(processInfo: processInfo))
        }
        #endif

        // Set by Xcode when the app is launched as the host for a unit test bundle
        if processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .unitTests
        }

        return .live
    }
}
