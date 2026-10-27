//
//  TransactionItem.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

enum TransactionDirection: String, Codable, Sendable {
    case inbound = "IN"
    case outbound = "OUT"
}

struct TransactionItem: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let categoryId: UUID
    let amount: CurrencyAndAmount
    let direction: TransactionDirection
    let transactionTime: String
    // Kept as raw strings incase it changes later. Could enum if fixed or add default fallback.
    let source: String?
    let status: String?
    let roundUp: RoundUp?

    enum CodingKeys: String, CodingKey {
        case id, amount, direction, transactionTime, source, status, roundUp
        case categoryId = "categoryUid"
    }

    /// The transaction time as a `Date`, or `nil` if the API sent a timestamp that can't be parsed.
    var transactionDate: Date? {
        ISO8601DateParser.date(from: transactionTime)
    }
}
