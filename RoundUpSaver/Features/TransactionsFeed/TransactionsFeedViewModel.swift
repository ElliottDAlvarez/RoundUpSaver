//
//  TransactionsFeedViewModel.swift
//  RoundUpSaver
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

    /// Set when a refresh fails while transactions are already on screen.
    var alertMessage: String?

    var title: String { account.name }

    @ObservationIgnored private let account: Account
    @ObservationIgnored private let transactionsRepository: TransactionsRepositoryProtocol
    @ObservationIgnored private let roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var transactions: [TransactionItem] = []
    @ObservationIgnored private var isFetching = false
    @ObservationIgnored weak var coordinator: TransactionsFeedCoordinating?

    init(transactionsRepository: TransactionsRepositoryProtocol,
         roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol,
         account: Account,
         coordinator: TransactionsFeedCoordinating? = nil,
         now: @escaping () -> Date = Date.init) {
        self.transactionsRepository = transactionsRepository
        self.roundUpSavingsUseCase = roundUpSavingsUseCase
        self.account = account
        self.coordinator = coordinator
        self.now = now
        self.week = Self.week(endingAt: now())
        self.roundUp = CurrencyAndAmount(currency: account.currency, amount: 0)
    }

    func showSavingsGoals() {
        coordinator?.showSavingsGoals(for: account, week: week, roundUp: roundUp)
    }

    /// Called every time the screen appears. Loads on first appearance; afterwards only recalculates
    /// the round-up, which may have changed if it was saved on the savings goals screen.
    func load() async {
        if case .idle = state {
            await fetchTransactions(showLoading: true)
        } else {
            await updateRoundUp()
        }
    }

    /// Pull to refresh. Keeps the current content on screen: swapping the List for a loading view
    /// would remove the `.refreshable` container and cancel this task mid-flight.
    func refresh() async {
        await fetchTransactions(showLoading: false)
    }

    func retry() async {
        await fetchTransactions(showLoading: true)
    }

    private func fetchTransactions(showLoading: Bool) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        let previousState = state
        if showLoading {
            state = .loading
        }
        week = Self.week(endingAt: now())

        do {
            let stream = transactionsRepository.fetchTransactions(account: account,
                                                                  from: week.start,
                                                                  to: week.end)

            for try await transactions in stream {
                guard let transactions else { continue }
                self.transactions = transactions
                await updateRoundUp()
                state = transactions.isEmpty ? .empty : .loaded(transactions)
            }
        } catch where error.isCancellation {
            // The screen went away or the refresh was interrupted; nothing to show
        } catch {
            if case .loaded = state {
                // Keep what's on screen and tell the user it may be out of date
                alertMessage = error.localizedDescription
            } else {
                state = .failed(error.localizedDescription)
            }
        }

        // If the fetch ended without producing anything (e.g. cancelled), don't leave the UI stuck loading
        if case .loading = state {
            if case .loading = previousState {
                state = .idle
            } else {
                state = previousState
            }
        }
    }

    private func updateRoundUp() async {
        roundUp = await roundUpSavingsUseCase.pendingRoundUp(account: account,
                                                             transactions: transactions)
    }

    // The feed and the round-up share the same 7 day window, so what the customer sees is what gets saved.
    private static func week(endingAt end: Date) -> DateInterval {
        DateInterval(start: end.addingTimeInterval(-60 * 60 * 24 * 7), end: end)
    }
}
