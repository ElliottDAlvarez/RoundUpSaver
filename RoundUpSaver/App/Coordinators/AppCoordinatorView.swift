//
//  AppCoordinatorView.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import SwiftUI

/// Connects the `AppCoordinator`'s navigation state to SwiftUI's `NavigationStack` and sheets.
struct AppCoordinatorView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.makeRootView()
                .navigationDestination(for: AppRoute.self) { route in
                    coordinator.makeView(for: route)
                }
        }
        .sheet(item: $coordinator.sheet, onDismiss: coordinator.sheetDidDismiss) { sheet in
            coordinator.makeView(for: sheet)
        }
        .sensoryFeedback(.selection, trigger: coordinator.path) { oldPath, newPath in
            // Play haptic feedback when the savings goals screen is pushed
            guard newPath.count > oldPath.count, case .savingsGoals = newPath.last else { return false }
            return true
        }
    }
}

#if DEBUG
#Preview {
    AppCoordinatorView(coordinator: AppCoordinator(dependencies: .uiTesting(scenario: .standard)))
}
#endif
