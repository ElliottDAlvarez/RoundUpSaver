//
//  TransactionsPage.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

// We could in theory make this generic too and call it PaginatedResponse<T> but for now we will keep it simple and specific to transactions
struct TransactionsPage: Sendable {
    let items: [TransactionItem]
    // let hasMore: Bool
}

struct TransactionsPageDTO: Decodable, Sendable {
    let feedItems: [TransactionItemDTO]
    // Ignoring pagination and links for this test
    // let links: LinksDTO
}
