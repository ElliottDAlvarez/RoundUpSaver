//
//  AccountsLocalStoreProtocol.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

protocol AccountsLocalStoreProtocol: Sendable {
    func fetchAccounts() async throws -> [Account]?
    func save(_ accounts: [Account]) async throws
}
