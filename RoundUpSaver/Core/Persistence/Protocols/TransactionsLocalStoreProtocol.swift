//
//  TransactionsLocalStoreProtocol.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

protocol TransactionsLocalStoreProtocol: Sendable {
    /// Returns the cached transactions in the range, or `nil` when nothing has been cached yet.
    func fetchTransactions(accountId: UUID, from: Date, to: Date) async throws -> [TransactionItem]?

    /// Replaces the cached transactions for the account in the range with `transactions`.
    func save(_ transactions: [TransactionItem], accountId: UUID, from: Date, to: Date) async throws
}
