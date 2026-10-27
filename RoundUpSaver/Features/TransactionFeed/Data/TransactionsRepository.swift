//
//  TransactionsRepository.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

protocol TransactionsRepositoryProtocol: Sendable {
    func fetchTransactions(account: Account,
                           from: Date,
                           to: Date) -> AsyncThrowingStream<[TransactionItem]?, Error>
}

struct TransactionsRepository: TransactionsRepositoryProtocol {
    private let localStore: TransactionsLocalStoreProtocol
    private let transactionsService: TransactionsServiceProtocol

    init(localStore: TransactionsLocalStoreProtocol,
         transactionsService: TransactionsServiceProtocol) {
        self.localStore = localStore
        self.transactionsService = transactionsService
    }

    func fetchTransactions(account: Account,
                           from: Date,
                           to: Date) -> AsyncThrowingStream<[TransactionItem]?, Error> {

        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let localTransactions = try await localStore.fetchTransactions(
                        accountId: account.id,
                        from: from,
                        to: to
                    )

                    try Task.checkCancellation()
                    continuation.yield(localTransactions)

                    let remoteTransactions = try await transactionsService.getTransactions(account: account,
                                                                                          from: from,
                                                                                          to: to)

                    try Task.checkCancellation()
                    // The cache is best effort, so a failed write mustn't hide fresh data from the user
                    try? await localStore.save(remoteTransactions,
                                               accountId: account.id,
                                               from: from,
                                               to: to)

                    continuation.yield(remoteTransactions)

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
