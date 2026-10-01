//
//  TransactionItemDTO.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

struct TransactionItemDTO: Codable, Sendable {
    let feedItemUid: UUID
    let categoryUid: UUID
    let amount: CurrencyAndAmount
    let sourceAmount: CurrencyAndAmount
    let direction: TransactionDirection
    let updatedAt: String
    let transactionTime: String
    let retryAllocationUntilTime: String?
    let source: String?
    let status: String?
    let roundUp: RoundUp?
    // Decided to ignore everything that isn't relevant
//    let sourceSubType: String // Enum needed
//    let transactingApplicationUserUid: UUID
//    let counterPartyType: String // Enum needed
//    let counterPartyUid: UUID
//    let counterPartyName: String
//    let counterPartySubEntityUid: UUID
}

extension TransactionItemDTO {
    func toDomain() -> TransactionItem {
        TransactionItem(id: feedItemUid,
                        categoryId: categoryUid,
                        amount: amount,
                        direction: direction,
                        transactionTime: transactionTime,
                        source: source,
                        status: status,
                        roundUp: roundUp)
    }
}
