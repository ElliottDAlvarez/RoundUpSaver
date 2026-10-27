//
//  SavingsGoalsViewModel.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class SavingsGoalsViewModel {
    private(set) var state: ViewState<[SavingsGoal]> = .idle
    private(set) var isProcessing = false
    private(set) var roundUp: CurrencyAndAmount
    var alertMessage: String?

    var canTransferRoundUp: Bool {
        roundUp.amount > 0 && !isProcessing
    }

    @ObservationIgnored private let account: Account
    @ObservationIgnored private let week: DateInterval
    @ObservationIgnored private let savingsRepository: SavingsRepositoryProtocol
    @ObservationIgnored private let roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol
    @ObservationIgnored weak var coordinator: SavingsGoalsCoordinating?

    init(account: Account,
         week: DateInterval,
         roundUp: CurrencyAndAmount,
         savingsRepository: SavingsRepositoryProtocol,
         roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol,
         coordinator: SavingsGoalsCoordinating? = nil) {
        self.account = account
        self.week = week
        self.roundUp = roundUp
        self.savingsRepository = savingsRepository
        self.roundUpSavingsUseCase = roundUpSavingsUseCase
        self.coordinator = coordinator
    }

    func showCreateSavingsGoal() {
        coordinator?.showCreateSavingsGoal(account: account) { [weak self] in
            await self?.refresh()
        }
    }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        await fetchSavingsGoals()
    }

    func refresh() async {
        if case .loading = state { return }
        await fetchSavingsGoals()
    }

    func retry() async {
        if case .loading = state { return }
        state = .loading
        await fetchSavingsGoals()
    }

    func transferRoundUp(to savingsGoal: SavingsGoal) async {
        guard canTransferRoundUp else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let transferred = try await roundUpSavingsUseCase.roundUpWeek(account: account,
                                                                          week: week,
                                                                          savingsGoal: savingsGoal)
            roundUp = CurrencyAndAmount(currency: account.currency, amount: 0)
            alertMessage = String(localized: "\(transferred.displayString) has been added to \(savingsGoal.name).")
            await fetchSavingsGoals()
        } catch RoundUpSavingsError.nothingToRoundUp {
            roundUp = CurrencyAndAmount(currency: account.currency, amount: 0)
            alertMessage = RoundUpSavingsError.nothingToRoundUp.localizedDescription
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func fetchSavingsGoals() async {
        do {
            let goals = try await savingsRepository.fetchSavingsGoals(account: account)
            state = goals.isEmpty ? .empty : .loaded(goals)
        } catch where error.isCancellation {
            if case .loading = state { state = .idle }
        } catch {
            if case .loaded = state {
                alertMessage = error.localizedDescription
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
