//
//  RoundUpSavingsUseCase.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

protocol RoundUpSavingsUseCaseProtocol: Sendable {
    func pendingRoundUp(account: Account,
                        transactions: [TransactionItem]) async -> CurrencyAndAmount

    func roundUpWeek(account: Account,
                     week: DateInterval,
                     savingsGoal: SavingsGoal) async throws -> CurrencyAndAmount
}

enum RoundUpSavingsError: LocalizedError, Equatable {
    case nothingToRoundUp
    case transferInProgress

    var errorDescription: String? {
        switch self {
        case .nothingToRoundUp:
            return "There is nothing left to round up for this week."
        case .transferInProgress:
            return "A round-up transfer is already in progress."
        }
    }
}

// Actor to handle round-up savings operations, ensuring thread safety and preventing concurrent transfers.
actor RoundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol {

    private let transactionsRepository: TransactionsRepositoryProtocol
    private let savingsRepository: SavingsRepositoryProtocol
    private let historyStore: RoundUpHistoryStoreProtocol
    private let calculator: RoundUpCalculatorProtocol

    private var isTransferring = false

    init(transactionsRepository: TransactionsRepositoryProtocol,
         savingsRepository: SavingsRepositoryProtocol,
         historyStore: RoundUpHistoryStoreProtocol = UserDefaultsRoundUpHistoryStore(),
         calculator: RoundUpCalculatorProtocol = RoundUpCalculator()) {
        self.transactionsRepository = transactionsRepository
        self.savingsRepository = savingsRepository
        self.historyStore = historyStore
        self.calculator = calculator
    }

    func pendingRoundUp(account: Account,
                        transactions: [TransactionItem]) async -> CurrencyAndAmount {
        let pending = await pendingTransactions(account: account,
                                                transactions: transactions)

        return CurrencyAndAmount(currency: account.currency,
                                 amount: calculator.calculate(transactions: pending)
        )
    }

    func roundUpWeek(account: Account,
                     week: DateInterval,
                     savingsGoal: SavingsGoal) async throws -> CurrencyAndAmount {

        guard !isTransferring else {
            throw RoundUpSavingsError.transferInProgress
        }

        isTransferring = true

        // set when function exits to allow future transfers
        defer { isTransferring = false }

        let transactions = try await latestTransactions(account: account,
                                                        week: week)

        let pending = await pendingTransactions(account: account,
                                                transactions: transactions)

        let roundUp = calculator.calculate(transactions: pending)

        guard roundUp > 0 else {
            throw RoundUpSavingsError.nothingToRoundUp
        }

        let amount = CurrencyAndAmount(currency: account.currency,
                                       amount: roundUp)

        try await savingsRepository.transfer(amount: amount,
                                             to: savingsGoal,
                                             account: account)

        // Only recorded once the transfer has succeeded, so a failed transfer can be retried
        await historyStore.markAsRoundedUp(pending.map(\.id),
                                           accountId: account.id)

        return amount
    }

    private func pendingTransactions(account: Account,
                                     transactions: [TransactionItem]) async -> [TransactionItem] {
        let roundedUpIds = await historyStore.roundedUpTransactionIds(accountId: account.id)

        return transactions.filter { !roundedUpIds.contains($0.id) }
    }

    private func latestTransactions(account: Account,
                                    week: DateInterval) async throws -> [TransactionItem] {
        var latest: [TransactionItem] = []

        let stream = transactionsRepository.fetchTransactions(account: account,
                                                              from: week.start,
                                                              to: week.end)

        for try await transactions in stream {
            if let transactions {
                latest = transactions
            }
        }

        return latest
    }
}
