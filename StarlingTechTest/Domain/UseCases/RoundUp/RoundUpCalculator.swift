//
//  RoundUpCalculator.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

protocol RoundUpCalculatorProtocol: Sendable {
    func calculate(transactions: [TransactionItem]) -> Int
}

struct RoundUpCalculator: RoundUpCalculatorProtocol {
    func calculate(transactions: [TransactionItem]) -> Int {

        transactions.reduce(0) { total, transaction in
            guard transaction.isEligibleForRoundUp else {
                return total
            }

            let remainder = abs(transaction.amount.amount) % 100

            return total + (remainder == 0 ? 0 : 100 - remainder)
        }
    }
}

private extension TransactionItem {
    // Outbound only
    var isEligibleForRoundUp: Bool {
        guard direction == .outbound else { return false }

        // Already marked as rounded
        guard roundUp == nil else { return false }

        // Internal transfers excluded so a previous round-up is never rounded up itself
        guard source != "INTERNAL_TRANSFER" else { return false }

        guard let status else { return true }

        return !["DECLINED", "REVERSED", "REFUNDED"].contains(status)
    }
}
