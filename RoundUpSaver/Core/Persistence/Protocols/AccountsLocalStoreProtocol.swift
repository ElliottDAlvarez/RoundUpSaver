//
//  AccountsLocalStoreProtocol.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

protocol AccountsLocalStoreProtocol: Sendable {
    /// Returns the cached accounts, or `nil` when nothing has been cached yet.
    func fetchAccounts() async throws -> [Account]?

    /// Replaces the cached accounts with `accounts`.
    func save(_ accounts: [Account]) async throws
}
