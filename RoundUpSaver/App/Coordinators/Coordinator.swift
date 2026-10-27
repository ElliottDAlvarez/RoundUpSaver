//
//  Coordinator.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/// Base protocol for coordinators that own a `NavigationStack` path.
///
/// In MVVM-C, coordinators own navigation and screen assembly:
/// - **Views** render state and pass user intents to their view model.
/// - **View models** hold presentation logic and ask their coordinator to navigate,
///   using a small feature-specific protocol (e.g. `AccountsListCoordinating`).
/// - **Coordinators** create view models, inject dependencies, and change navigation state.
@MainActor
protocol Coordinator: AnyObject {
    associatedtype Route: Hashable

    var path: [Route] { get set }

    func push(_ route: Route)
    func pop()
    func popToRoot()
}

extension Coordinator {
    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
