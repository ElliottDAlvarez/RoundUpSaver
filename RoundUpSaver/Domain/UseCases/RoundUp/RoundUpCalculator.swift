//
//  RoundUpCalculator.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

protocol RoundUpCalculatorProtocol: Sendable {
    /// Total round-up in minor units of the transactions' currency.
    func calculate(transactions: [TransactionItem]) -> Int
}

/// Rounds each eligible outgoing transaction up to the next whole major unit (e.g. £4.35 -> £5.00 saves 65p).
/// The size of a "whole unit" comes from the currency, so 3-decimal currencies round to 1000 minor units
/// and 0-decimal currencies (where every amount is already whole) produce no round-up.
struct RoundUpCalculator: RoundUpCalculatorProtocol {
    func calculate(transactions: [TransactionItem]) -> Int {
        transactions.reduce(0) { total, transaction in
            guard transaction.isEligibleForRoundUp else {
                return total
            }

            let unit = CurrencyPrecision.minorUnitsPerMajorUnit(for: transaction.amount.currency)
            let remainder = abs(transaction.amount.amount) % unit

            return total + (remainder == 0 ? 0 : unit - remainder)
        }
    }
}

private extension TransactionItem {
    var isEligibleForRoundUp: Bool {
        // Outbound only
        guard direction == .outbound else { return false }

        // Already marked as rounded up by the backend
        guard roundUp == nil else { return false }

        // Internal transfers excluded so a previous round-up is never rounded up itself
        guard source != "INTERNAL_TRANSFER" else { return false }

        guard let status else { return true }

        return !["DECLINED", "REVERSED", "REFUNDED"].contains(status)
    }
}
