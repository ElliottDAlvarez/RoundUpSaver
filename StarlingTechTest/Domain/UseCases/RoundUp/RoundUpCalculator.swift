//
//  RoundUpCalculator.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

struct RoundUpCalculator {

    func calculate(
        transactions: [TransactionItem]
    ) -> Int {

        transactions.reduce(0) { total, transaction in
            guard transaction.direction == "OUT" else {
                return total
            }

            let amount = transaction.amount.amount
            let remainder = amount % 100

            return total + (remainder == 0 ? 0 : 100 - remainder)
        }
    }
}
