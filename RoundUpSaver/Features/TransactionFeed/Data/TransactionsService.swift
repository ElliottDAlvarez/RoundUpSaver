//
//  TransactionsService.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

protocol TransactionsServiceProtocol: Sendable {
    /// Every transaction in the window, across all pages.
    func getTransactions(account: Account,
                         from: Date,
                         to: Date) async throws -> [TransactionItem]
}

struct TransactionsService: TransactionsServiceProtocol {
    /// Safety net against a misbehaving server. A week of card spending is nowhere near this.
    static let maximumPages = 50

    private let apiClient: APIClientProtocol
    private let requestBuilder: APIRequestBuilder

    private let dateFormatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    init(apiClient: APIClientProtocol,
         requestBuilder: APIRequestBuilder) {
        self.apiClient = apiClient
        self.requestBuilder = requestBuilder
    }

    func getTransactions(account: Account,
                         from: Date,
                         to: Date) async throws -> [TransactionItem] {
        let path = "api/v2/feed/account/\(account.id.uuidString.lowercased())"
            + "/category/\(account.defaultCategory.uuidString.lowercased())/paginated-transactions"

        var nextURL: URL? = try requestBuilder.url(
            path: path,
            queryItems: [URLQueryItem(name: "minTransactionTimestamp", value: dateFormatStyle.format(from)),
                         URLQueryItem(name: "maxTransactionTimestamp", value: dateFormatStyle.format(to))]
        )

        var items: [TransactionItem] = []
        var seenIds = Set<UUID>()
        var visitedURLs = Set<URL>()

        // A round-up must see every transaction in the window, so follow `links.next` to the end
        while let url = nextURL {
            guard visitedURLs.insert(url).inserted else {
                throw APIError.unsuccessful(String(localized: "The transaction feed returned a pagination loop."))
            }
            guard visitedURLs.count <= Self.maximumPages else {
                throw APIError.unsuccessful(String(localized: "The transaction feed has too many pages."))
            }

            try Task.checkCancellation()
            let page = try await apiClient.get(PaginatedFeedItemsDTO.self, url: url)

            // Pages can overlap if new transactions arrive while paging; keep the first copy of each
            for dto in page.feedItems where seenIds.insert(dto.feedItemUid).inserted {
                items.append(dto.toDomain())
            }

            nextURL = try page.links?.next.map(requestBuilder.url(resolvingLink:))
        }

        return items
    }
}
