//
//  LoginViewModel.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class TransactionsFeedViewModel {
    private(set) var state: ViewState<[TransactionItem]> = .idle

    private let transactionsRepository: TransactionsRepositoryProtocol
    private let account: Account

    init(
        transactionsRepository: TransactionsRepositoryProtocol,
        account: Account
    ) {
        self.transactionsRepository = transactionsRepository
        self.account = account
    }

    func load() async {
        // Only want to inital load on idle or show errors / content
        if case .idle = state {
            await fetchTransactions()
        }
    }

    func refresh() async {
        // Only want to refresh if we are not already loading
        if case .loading = state { return }

        await fetchTransactions()
    }

    private func fetchTransactions() async {
        state = .loading

        do {
            let stream = transactionsRepository.fetchTransactions(
                account: account,
                from: Date().addingTimeInterval(-60 * 60 * 24 * 7),
                to: Date()
            )

            for try await transactions in stream {
                if let transactions {
                    state = transactions.isEmpty
                        ? .empty
                        : .loaded(transactions)
                }
            }

        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
