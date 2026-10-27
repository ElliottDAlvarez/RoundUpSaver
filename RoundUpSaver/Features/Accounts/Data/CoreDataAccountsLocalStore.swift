//
//  CoreDataAccountsLocalStore.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import CoreData

/// Offline cache for the accounts list, backed by Core Data.
final class CoreDataAccountsLocalStore: AccountsLocalStoreProtocol {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    func fetchAccounts() async throws -> [Account]? {
        let context = persistenceController.newBackgroundContext()

        return try await context.perform {
            let request = CachedAccount.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedAccount.sortIndex, ascending: true)]

            do {
                let cached = try context.fetch(request)
                return cached.isEmpty ? nil : cached.compactMap(\.domainModel)
            } catch {
                throw CoreDataError.fetchError("Failed to fetch cached accounts: \(error.localizedDescription)")
            }
        }
    }

    func save(_ accounts: [Account]) async throws {
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            do {
                try context.fetch(CachedAccount.fetchRequest()).forEach(context.delete)

                for (index, account) in accounts.enumerated() {
                    let cached = CachedAccount(context: context)
                    cached.id = account.id
                    cached.accountType = account.accountType
                    cached.defaultCategory = account.defaultCategory
                    cached.currency = account.currency
                    cached.createdAt = account.createdAt
                    cached.name = account.name
                    cached.sortIndex = Int64(index)
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                context.rollback()
                throw CoreDataError.saveError("Failed to cache accounts: \(error.localizedDescription)")
            }
        }
    }
}

private extension CachedAccount {
    var domainModel: Account? {
        guard let id, let accountType, let defaultCategory, let currency, let createdAt, let name else {
            return nil
        }

        return Account(id: id,
                       accountType: accountType,
                       defaultCategory: defaultCategory,
                       currency: currency,
                       createdAt: createdAt,
                       name: name)
    }
}
