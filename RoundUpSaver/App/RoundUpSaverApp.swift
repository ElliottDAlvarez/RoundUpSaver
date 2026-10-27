//
//  RoundUpSaverApp.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import SwiftUI

@main
struct RoundUpSaverApp: App {
    @State private var coordinator: AppCoordinator?

    init() {
        let dependencies: AppDependencies?

        switch AppLaunchEnvironment.current() {
        case .live:
            dependencies = .live()
        case .unitTests:
            // Unit tests build their own dependencies, so the host app stays idle
            dependencies = nil
        #if DEBUG
        case .uiTests(let scenario):
            dependencies = .uiTesting(scenario: scenario)
        #endif
        }

        _coordinator = State(initialValue: dependencies.map { AppCoordinator(dependencies: $0) })
    }

    var body: some Scene {
        WindowGroup {
            if let coordinator {
                AppCoordinatorView(coordinator: coordinator)
            }
        }
    }
}
