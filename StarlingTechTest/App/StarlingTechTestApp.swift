//
//  StarlingTechTestApp.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import SwiftUI
import CoreData

@main
struct StarlingTechTestApp: App {
    @State private var dependencies = AppDependencies.makeForCurrentEnvironment()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            AccountsListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(dependencies)
        }
    }
}
