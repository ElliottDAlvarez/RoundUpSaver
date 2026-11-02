//
//  TransactionsService.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

protocol TransactionsServiceProtocol: Sendable {
    /// Every transaction in the range.
    func getTransactions(account: Account,
                         from: Date,
                         to: Date) async throws -> [TransactionItem]
}

/// Uses `transactions-between`, which returns the whole range in one response with no pagination.
///
/// The API limits this endpoint to ranges of up to 1 year (longer ranges get HTTP 400). Round-ups only
/// ever ask for 7 days. If a feature ever needs more than a year, it should use `paginated-transactions`.
struct TransactionsService: TransactionsServiceProtocol {
    /// The API's limit for `transactions-between`. Checked here so a too-long range fails clearly before any request.
    static let maximumRange: TimeInterval = 60 * 60 * 24 * 365

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
        guard from <= to, to.timeIntervalSince(from) <= Self.maximumRange else {
            throw APIError.unsuccessful(String(localized: "Transactions can only be fetched for up to one year at a time."))
        }

        let path = "api/v2/feed/account/\(account.id.uuidString.lowercased())"
            + "/category/\(account.defaultCategory.uuidString.lowercased())/transactions-between"

        let url = try requestBuilder.url(
            path: path,
            queryItems: [URLQueryItem(name: "minTransactionTimestamp", value: dateFormatStyle.format(from)),
                         URLQueryItem(name: "maxTransactionTimestamp", value: dateFormatStyle.format(to))]
        )

        let response = try await apiClient.get(FeedItemsDTO.self, url: url)

        return response.feedItems.map { $0.toDomain() }
    }
}
