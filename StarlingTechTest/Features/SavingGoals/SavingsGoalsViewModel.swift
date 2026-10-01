//
//  SavingsGoalsViewModel.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
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

    private let account: Account
    private let week: DateInterval
    private let savingsRepository: SavingsRepositoryProtocol
    private let roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol

    var canTransferRoundUp: Bool {
        roundUp.amount > 0 && !isProcessing
    }

    init(account: Account,
         week: DateInterval,
         roundUp: CurrencyAndAmount,
         savingsRepository: SavingsRepositoryProtocol,
         roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol) {
        self.account = account
        self.week = week
        self.roundUp = roundUp
        self.savingsRepository = savingsRepository
        self.roundUpSavingsUseCase = roundUpSavingsUseCase
    }

    func load() async {
        if case .idle = state {
            state = .loading
            await fetchSavingsGoals()
        }
    }

    func refresh() async {
        if case .loading = state { return }

        await fetchSavingsGoals()
    }

    func createSavingsGoal(name: String,
                           targetAmount: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            alertMessage = "Please enter a name for your savings goal."
            return false
        }

        let target: CurrencyAndAmount?
        if targetAmount.isEmpty {
            target = nil
        } else if let minorUnits = minorUnits(from: targetAmount) {
            target = CurrencyAndAmount(currency: account.currency, amount: minorUnits)
        } else {
            alertMessage = "Please enter a valid target amount."
            return false
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            _ = try await savingsRepository.createSavingsGoal(account: account,
                                                              name: trimmedName,
                                                              target: target)
            await fetchSavingsGoals()
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
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
            alertMessage = "\(transferred.displayString) has been added to \(savingsGoal.name)."
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
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // Converts user input such as "12.50" into minor units (1250)
    private func minorUnits(from string: String) -> Int? {
        let normalised = string.replacingOccurrences(of: ",", with: ".")

        guard let decimal = Decimal(string: normalised), decimal > 0 else {
            return nil
        }

        var value = decimal * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)

        return NSDecimalNumber(decimal: rounded).intValue
    }
}
