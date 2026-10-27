//
//  AccountsListViewModel.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class AccountsListViewModel {
    private(set) var state: ViewState<[Account]> = .idle

    /// Set when a refresh fails while cached accounts are already on screen.
    var alertMessage: String?

    @ObservationIgnored private let accountsRepository: AccountsRepositoryProtocol
    @ObservationIgnored weak var coordinator: AccountsListCoordinating?

    init(accountsRepository: AccountsRepositoryProtocol,
         coordinator: AccountsListCoordinating? = nil) {
        self.accountsRepository = accountsRepository
        self.coordinator = coordinator
    }

    func didSelect(_ account: Account) {
        coordinator?.showTransactionsFeed(for: account)
    }

    /// Loads the accounts the first time the screen appears.
    func load() async {
        guard case .idle = state else { return }
        await fetchAccounts()
    }

    func retry() async {
        if case .loading = state { return }
        await fetchAccounts()
    }

    private func fetchAccounts() async {
        state = .loading

        do {
            for try await accounts in accountsRepository.fetchAccounts() {
                guard let accounts else { continue }
                state = accounts.isEmpty ? .empty : .loaded(accounts)
            }
        } catch where error.isCancellation {
            // The screen went away; nothing to show
        } catch {
            if case .loaded = state {
                // Keep the cached accounts visible and tell the user they may be out of date
                alertMessage = error.localizedDescription
            } else {
                state = .failed(error.localizedDescription)
            }
        }

        // If the fetch ended without producing anything (e.g. cancelled), allow it to run again
        if case .loading = state {
            state = .idle
        }
    }
}
