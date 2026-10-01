//
//  TransactionsLocalStoreProtocol.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

protocol TransactionsLocalStoreProtocol: Sendable {
    func fetchTransactions(accountId: UUID, from: Date, to: Date) async throws -> [TransactionItem]?
    func save(_ transactions: [TransactionItem]) async throws
}
