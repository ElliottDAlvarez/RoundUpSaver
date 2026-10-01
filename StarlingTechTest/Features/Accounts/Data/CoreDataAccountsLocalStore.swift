//
//  CoreDataAccountsLocalStore.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import CoreData

final class CoreDataAccountsLocalStore: AccountsLocalStoreProtocol {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAccounts() async throws -> [Account]? {
        // Not worrying about CoreData for test just here as an example
        return nil

        let request: NSFetchRequest<Item> = NSFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)]

        do {
            let items = try self.context.fetch(request)
            return items.map { _ in Account(id: UUID(),
                                            accountType: "PRIMARY",
                                            defaultCategory: UUID(),
                                            currency: "GBP",
                                            createdAt: Date(),
                                            name: "Testing") }
        } catch {
            throw CoreDataError.fetchError("Failed to fetch accounts: \(error.localizedDescription)")
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

    func save(_ accounts: [Account]) async throws {
        // Core Data persistence here
    }
}
