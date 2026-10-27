//
//  TransactionsPage.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

/// One page of `GET .../paginated-transactions` (`PaginatedFeedItems` in the API spec).
struct PaginatedFeedItemsDTO: Decodable, Sendable {
    let feedItems: [TransactionItemDTO]
    let links: LinksDTO?
}

/// HATEOAS pagination links. `next` is present while there are more pages to fetch.
struct LinksDTO: Decodable, Sendable {
    let next: String?
}
