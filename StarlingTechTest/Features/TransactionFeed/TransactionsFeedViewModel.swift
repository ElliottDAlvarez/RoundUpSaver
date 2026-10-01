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
        // Only want to refresh if we are not already loading / refreshing
        if case .loading = state { return }
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        // Keep the current content on screen while refreshing. Swapping the List out for a
        // loading view removes the `.refreshable` container, which cancels this task mid-flight.
        await fetchTransactions(showLoading: false)
    }

    @ObservationIgnored private var isRefreshing = false

    private func fetchTransactions(showLoading: Bool = true) async {
        let previousState = state
        if showLoading {
            state = .loading
        }
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

        } catch where Self.isCancellation(error) {
            // Cancelled (e.g. refresh gesture interrupted) - don't surface as an error.
        } catch {
            state = .failed(error.localizedDescription)
        }

        // If the fetch ended without producing anything (e.g. cancelled), don't leave the UI stuck loading.
        if case .loading = state {
            if case .loading = previousState {
                state = .idle
            } else {
                state = previousState
            }
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
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
