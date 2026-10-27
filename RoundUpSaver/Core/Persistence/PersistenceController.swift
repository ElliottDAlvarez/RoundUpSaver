//
//  PersistenceController.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import CoreData

/// Owns the Core Data stack used as an offline cache.
///
/// The cache only holds data that can be fetched again from the API, so if the on-disk store
/// can't be loaded (e.g. an incompatible model) it is destroyed and rebuilt rather than crashing.
/// `@unchecked Sendable`: the only stored state is an immutable `NSPersistentContainer`, and all
/// reads and writes go through background contexts used inside `perform`.
final class PersistenceController: @unchecked Sendable {
    static let modelName = "RoundUpSaver"

    /// Loaded once per process. Loading the same model more than once (e.g. one container per test)
    /// makes Core Data warn that several entity descriptions claim the same managed object subclass.
    /// `nonisolated(unsafe)`: the model is never mutated after loading, and Core Data allows a model in use
    /// by a coordinator to be read from any thread.
    nonisolated(unsafe) static let model: NSManagedObjectModel = {
        guard let url = Bundle(for: PersistenceController.self).url(forResource: modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            preconditionFailure("Unable to load the \(modelName) Core Data model.")
        }
        return model
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Self.modelName, managedObjectModel: Self.model)

        if inMemory, let description = container.persistentStoreDescriptions.first {
            // Each in-memory controller gets its own isolated store
            description.type = NSInMemoryStoreType
            description.url = nil
        }

        Self.loadStores(of: container)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    /// A background context for cache reads and writes, so Core Data work never blocks the main thread.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    private static func loadStores(of container: NSPersistentContainer) {
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }

        guard loadError != nil else { return }

        // The store is only a cache, so remove it and start again
        for description in container.persistentStoreDescriptions {
            guard let url = description.url else { continue }
            try? container.persistentStoreCoordinator.destroyPersistentStore(at: url, type: .sqlite)
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Unable to load the cache store: \(error)")
            }
        }
    }
}
