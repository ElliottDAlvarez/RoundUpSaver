//
//  TransactionsFeedViewModel.swift
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
    private(set) var week: DateInterval
    private(set) var roundUp: CurrencyAndAmount

    let account: Account

    private let transactionsRepository: TransactionsRepositoryProtocol
    private let roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol
    private let now: () -> Date
    private var transactions: [TransactionItem] = []

    init(
        transactionsRepository: TransactionsRepositoryProtocol,
        roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol,
        account: Account,
        now: @escaping () -> Date = Date.init
    ) {
        self.transactionsRepository = transactionsRepository
        self.roundUpSavingsUseCase = roundUpSavingsUseCase
        self.account = account
        self.now = now
        self.week = Self.week(endingAt: now())
        self.roundUp = CurrencyAndAmount(currency: account.currency, amount: 0)
    }

    func load() async {
        // Only want to inital load on idle or show errors / content
        if case .idle = state {
            await fetchTransactions()
        } else {
            await updateRoundUp()
        }
    }

    func refresh() async {
        // Only want to refresh if we are not already loading
        if case .loading = state { return }

        await fetchTransactions()
    }

    private func fetchTransactions() async {
        state = .loading
        week = Self.week(endingAt: now())

        do {
            let stream = transactionsRepository.fetchTransactions(
                account: account,
                from: week.start,
                to: week.end
            )

            for try await transactions in stream {
                if let transactions {
                    self.transactions = transactions
                    await updateRoundUp()

                    state = transactions.isEmpty ? .empty : .loaded(transactions)
                }
            }

        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func updateRoundUp() async {
        roundUp = await roundUpSavingsUseCase.pendingRoundUp(
            account: account,
            transactions: transactions
        )
    }

    // The feed and the round-up share the same 7 day window, so what the customer sees is what gets saved.
    private static func week(endingAt end: Date) -> DateInterval {
        DateInterval(start: end.addingTimeInterval(-60 * 60 * 24 * 7), end: end)
    }
}
