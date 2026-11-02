//
//  CoreDataTransactionsLocalStore.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import CoreData

/// Offline cache for the transaction feed, backed by Core Data.
final class CoreDataTransactionsLocalStore: TransactionsLocalStoreProtocol {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    func fetchTransactions(accountId: UUID,
                           from: Date,
                           to: Date) async throws -> [TransactionItem]? {
        let context = persistenceController.newBackgroundContext()

        return try await context.perform {
            let request = CachedTransaction.fetchRequest()
            request.predicate = Self.predicate(accountId: accountId, from: from, to: to)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedTransaction.transactionDate, ascending: false)]

            do {
                let cached = try context.fetch(request)
                return cached.isEmpty ? nil : cached.compactMap(\.domainModel)
            } catch {
                throw CoreDataError.fetchError("Failed to fetch cached transactions: \(error.localizedDescription)")
            }
        }
    }

    func save(_ transactions: [TransactionItem],
              accountId: UUID,
              from: Date,
              to: Date) async throws {
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            do {
                // The API response is the source of truth for this window, so replace what was cached
                let request = CachedTransaction.fetchRequest()
                request.predicate = Self.predicate(accountId: accountId, from: from, to: to)
                try context.fetch(request).forEach(context.delete)

                for transaction in transactions {
                    // A timestamp that can't be parsed can't be matched to a window, so don't cache it
                    guard let date = ISO8601DateParser.date(from: transaction.transactionTime) else { continue }

                    let cached = CachedTransaction(context: context)
                    cached.id = transaction.id
                    cached.accountId = accountId
                    cached.categoryId = transaction.categoryId
                    cached.minorUnits = Int64(transaction.amount.amount)
                    cached.currency = transaction.amount.currency
                    cached.direction = transaction.direction.rawValue
                    cached.transactionTime = transaction.transactionTime
                    cached.transactionDate = date
                    cached.source = transaction.source
                    cached.status = transaction.status
                    cached.roundUpGoalCategoryId = transaction.roundUp?.goalCategoryId
                    cached.roundUpMinorUnits = Int64(transaction.roundUp?.amount.amount ?? 0)
                    cached.roundUpCurrency = transaction.roundUp?.amount.currency
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                context.rollback()
                throw CoreDataError.saveError("Failed to cache transactions: \(error.localizedDescription)")
            }
        }
    }

    private static func predicate(accountId: UUID, from: Date, to: Date) -> NSPredicate {
        NSPredicate(format: "accountId == %@ AND transactionDate >= %@ AND transactionDate <= %@",
                    accountId as CVarArg, from as NSDate, to as NSDate)
    }
}

private extension CachedTransaction {
    var domainModel: TransactionItem? {
        guard let id,
              let categoryId,
              let currency,
              let direction = direction.flatMap(TransactionDirection.init(rawValue:)),
              let transactionTime else {
            return nil
        }

        var roundUp: RoundUp?
        if let roundUpGoalCategoryId, let roundUpCurrency {
            roundUp = RoundUp(goalCategoryId: roundUpGoalCategoryId,
                              amount: CurrencyAndAmount(currency: roundUpCurrency,
                                                        amount: Int(roundUpMinorUnits)))
        }

        return TransactionItem(id: id,
                               categoryId: categoryId,
                               amount: CurrencyAndAmount(currency: currency, amount: Int(minorUnits)),
                               direction: direction,
                               transactionTime: transactionTime,
                               source: source,
                               status: status,
                               roundUp: roundUp)
    }
}
