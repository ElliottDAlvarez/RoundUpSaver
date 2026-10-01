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
final class AccountsListViewModel {
    private(set) var state: ViewState<[Account]> = .idle

    private let accountsRepository: AccountsRepositoryProtocol

    private var loadTask: Task<Void, Never>?

    init(accountsRepository: AccountsRepositoryProtocol) {
        self.accountsRepository = accountsRepository
    }

    func load() async {
        if case .idle = state {
            state = .loading

            do {
                let stream = accountsRepository.fetchAccounts()

                for try await accounts in stream {
                    if let accounts {
                        state = accounts.isEmpty
                            ? .empty
                            : .loaded(accounts)
                    }
                }
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
