//
//  FeedItemsDTO.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

/// Response of `GET .../transactions-between` (`FeedItems` in the API spec): every transaction in the range.
struct FeedItemsDTO: Decodable, Sendable {
    let feedItems: [TransactionItemDTO]
}
