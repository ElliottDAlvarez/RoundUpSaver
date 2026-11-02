//
//  CreateSavingsGoalViewModel.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class CreateSavingsGoalViewModel {
    var name = ""
    var targetAmount = ""
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    var canSubmit: Bool {
        !trimmedName.isEmpty && !isSaving
    }

    @ObservationIgnored private let account: Account
    @ObservationIgnored private let savingsRepository: SavingsRepositoryProtocol
    @ObservationIgnored weak var coordinator: CreateSavingsGoalCoordinating?

    init(account: Account,
         savingsRepository: SavingsRepositoryProtocol,
         coordinator: CreateSavingsGoalCoordinating? = nil) {
        self.account = account
        self.savingsRepository = savingsRepository
        self.coordinator = coordinator
    }

    /// Validates the form and creates the goal. Errors are shown in the form so the user can fix them.
    func submit() async {
        guard !isSaving else { return }

        guard !trimmedName.isEmpty else {
            errorMessage = String(localized: "Please enter a name for your savings goal.")
            return
        }

        let trimmedTarget = targetAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: CurrencyAndAmount?

        if trimmedTarget.isEmpty {
            target = nil
        } else if let minorUnits = Self.minorUnits(from: trimmedTarget, currency: account.currency) {
            target = CurrencyAndAmount(currency: account.currency, amount: minorUnits)
        } else {
            errorMessage = String(localized: "Please enter a valid target amount.")
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await savingsRepository.createSavingsGoal(account: account,
                                                              name: trimmedName,
                                                              target: target)
            await coordinator?.didCreateSavingsGoal()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        coordinator?.didCancelCreateSavingsGoal()
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts user input such as "12.50" or "12,50" into minor units of `currency` (1250 for GBP).
    /// Accepts a positive amount with no more decimal places than the currency allows,
    /// so input like "12abc", "-5" or "12.345" (for GBP) is rejected.
    nonisolated static func minorUnits(from string: String, currency: String) -> Int? {
        let fractionDigits = CurrencyPrecision.fractionDigits(for: currency)
        let parts = string.split(separator: /[.,]/, omittingEmptySubsequences: false)

        guard (1...2).contains(parts.count),
              parts[0].wholeMatch(of: /\d{1,9}/) != nil,
              let major = Int(parts[0]) else {
            return nil
        }

        var minor = 0
        if parts.count == 2 {
            let fraction = parts[1]
            guard fractionDigits > 0,
                  (1...fractionDigits).contains(fraction.count),
                  fraction.wholeMatch(of: /\d+/) != nil,
                  let value = Int(fraction) else {
                return nil
            }

            // "12.5" means 50p, not 5p: pad the fraction out to the currency's precision
            let padding = fractionDigits - fraction.count
            minor = (0..<padding).reduce(value) { result, _ in result * 10 }
        }

        let total = major * CurrencyPrecision.minorUnitsPerMajorUnit(for: currency) + minor
        return total > 0 ? total : nil
    }
}
