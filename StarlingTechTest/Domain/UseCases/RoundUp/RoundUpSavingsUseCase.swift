//
//  RoundUpSavingsUseCase.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/*protocol RoundUpSavingsUseCaseProtocol: Sendable {
    func execute(
        account: Account,
        week: DateInterval,
        savingsGoal: SavingsGoal
    ) async throws
}

struct RoundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol {

    private let transactionsRepository: TransactionsRepositoryProtocol
    private let savingsRepository: SavingsRepositoryProtocol

    init(
        transactionsRepository: TransactionsRepositoryProtocol,
        savingsRepository: SavingsRepositoryProtocol
    ) {
        self.transactionsRepository = transactionsRepository
        self.savingsRepository = savingsRepository
    }

    func execute(
        account: Account,
        week: DateInterval,
        savingsGoal: SavingsGoal
    ) async throws {

        let transactions = try await transactionsRepository.fetchTransactions(
            account: account,
            from: week.start,
            to: week.end
        )

        let roundUp = calculateRoundUp(transactions)

        guard roundUp > 0 else {
            return
        }

        try await savingsRepository.transfer(
            amount: roundUp,
            to: savingsGoal
        )
    }

    private func calculateRoundUp(
        _ transactions: [TransactionItem]
    ) -> Int {
        transactions
            .filter { $0.direction == "OUT" }
            .reduce(0) { total, transaction in
                let amount = transaction.amount.amount
                let remainder = amount % 100

                return total + (remainder == 0 ? 0 : 100 - remainder)
            }
    }
}
*/
