//
//  AccountsRepository.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

protocol AccountsRepositoryProtocol: Sendable {
    func fetchAccounts() -> AsyncThrowingStream<[Account]?, Error>
}

struct AccountsRepository: AccountsRepositoryProtocol {
    private let localStore: AccountsLocalStoreProtocol
    private let accountsService: AccountsServiceProtocol

    init(localStore: AccountsLocalStoreProtocol, accountsService: AccountsServiceProtocol) {
        self.localStore = localStore
        self.accountsService = accountsService
    }

    func fetchAccounts() -> AsyncThrowingStream<[Account]?, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let localAccounts = try await localStore.fetchAccounts()

                    try Task.checkCancellation()
                    continuation.yield(localAccounts)

                    let remoteAccounts = try await accountsService.getAccounts()

                    try Task.checkCancellation()
                    try await localStore.save(remoteAccounts)

                    continuation.yield(remoteAccounts)

                    continuation.finish()

                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
