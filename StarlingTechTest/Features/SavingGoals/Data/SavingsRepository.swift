//
//  SavingsRepository.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

protocol SavingsRepositoryProtocol: Sendable {
    func fetchSavingsGoals(account: Account) async throws -> [SavingsGoal]
    func createSavingsGoal(account: Account,
                           name: String,
                           target: CurrencyAndAmount?) async throws -> UUID
    func transfer(amount: CurrencyAndAmount,
                  to savingsGoal: SavingsGoal,
                  account: Account) async throws
}

struct SavingsRepository: SavingsRepositoryProtocol {
    private let savingsService: SavingsServiceProtocol

    init(savingsService: SavingsServiceProtocol) {
        self.savingsService = savingsService
    }

    func fetchSavingsGoals(account: Account) async throws -> [SavingsGoal] {
        try await savingsService.getSavingsGoals(account: account)
    }

    func createSavingsGoal(account: Account,
                           name: String,
                           target: CurrencyAndAmount?) async throws -> UUID {
        try await savingsService.createSavingsGoal(account: account,
                                                   name: name,
                                                   target: target)
    }

    func transfer(amount: CurrencyAndAmount,
                  to savingsGoal: SavingsGoal,
                  account: Account) async throws {
        try await savingsService.addMoney(account: account,
                                          savingsGoalId: savingsGoal.id,
                                          transferId: UUID(),
                                          amount: amount)
    }
}
