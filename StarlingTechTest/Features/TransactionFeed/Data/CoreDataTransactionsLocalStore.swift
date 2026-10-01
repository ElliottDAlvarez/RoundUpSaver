//
//  CoreDataTransactionsLocalStore.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import CoreData

final class CoreDataTransactionsLocalStore: TransactionsLocalStoreProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchTransactions(accountId: UUID, from: Date, to: Date) async throws -> [TransactionItem]? {
        // Not worrying about CoreData for tests, just here as an example of how to fetch transactions from CoreData.
        return nil

        let request: NSFetchRequest<Item> = NSFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)]

        do {
            let items = try self.context.fetch(request)
            return items.map { _ in TransactionItem(id: UUID(),
                                                    categoryId: UUID(),
                                                    amount: CurrencyAndAmount(currency: "GBP", amount: 100),
                                                    direction: "IN",
                                                    transactionTime: Date().ISO8601Format(),
                                                    roundUp: nil) }
        } catch {
            throw CoreDataError.fetchError("Failed to fetch transactions: \(error.localizedDescription)")
        }
    }

    func addTransaction() {
//        withAnimation {
//            let newItem = Item(context: viewContext)
//            newItem.timestamp = Date()
//
//            do {
//                try viewContext.save()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nsError = error as NSError
//                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//            }
//        }
    }

    private func deleteTransactions(offsets: IndexSet) {
//        withAnimation {
//            offsets.map { items[$0] }.forEach(viewContext.delete)
//
//            do {
//                try viewContext.save()
//            } catch {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                let nsError = error as NSError
//                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//            }
//        }
    }

    func save(_ transactions: [TransactionItem]) async throws {
        // Core Data persistence here
    }
}
