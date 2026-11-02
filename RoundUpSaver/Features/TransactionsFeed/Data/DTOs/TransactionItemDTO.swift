//
//  TransactionItemDTO.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

/// A `FeedItem` from the API. The spec marks no fields as required, so only the fields the
/// round-up genuinely needs are non-optional; anything else unused is left out so a missing
/// field can't fail decoding of the whole feed.
struct TransactionItemDTO: Decodable, Sendable {
    let feedItemUid: UUID
    let categoryUid: UUID
    let amount: CurrencyAndAmount
    let direction: TransactionDirection
    let transactionTime: String
    let source: String?
    let status: String?
    let roundUp: RoundUp?
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
