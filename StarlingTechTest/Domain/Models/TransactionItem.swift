//
//  TransactionItem.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

struct TransactionItem: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let categoryId: UUID
    let amount: CurrencyAndAmount
    let direction: String // Enum needed IN / OUT
    let transactionTime: String
    let roundUp: RoundUp?

    enum CodingKeys: String, CodingKey {
        case id, amount, direction, transactionTime, roundUp
        case categoryId = "categoryUid"
    }
}

struct TransactionItemDTO: Codable, Sendable {
    let feedItemUid: UUID
    let categoryUid: UUID
    let amount: CurrencyAndAmount
    let sourceAmount: CurrencyAndAmount
    let direction: String // Enum needed
    let updatedAt: String
    let transactionTime: String
    let retryAllocationUntilTime: String?
    let roundUp: RoundUp?
    // Decided to ignore everything that isn't relevant
//    let source: String // Enum needed
//    let sourceSubType: String // Enum needed
//    let status: String // Enum needed
//    let transactingApplicationUserUid: UUID
//    let counterPartyType: String // Enum needed
//    let counterPartyUid: UUID
//    let counterPartyName: String
//    let counterPartySubEntityUid: UUID
}
