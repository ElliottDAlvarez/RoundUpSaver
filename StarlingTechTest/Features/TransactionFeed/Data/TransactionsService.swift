//
//  TransactionsService.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

protocol TransactionsServiceProtocol: Sendable {
    func getTransactionsPage(account: Account,
                             from: Date,
                             to: Date) async throws -> TransactionsPage
}

struct TransactionsService: TransactionsServiceProtocol {
    private let apiClient: APIClientProtocol
    private let requestBuilder: APIRequestBuilder

    private let dateFormatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    init(apiClient: APIClientProtocol,
         requestBuilder: APIRequestBuilder) {
        self.apiClient = apiClient
        self.requestBuilder = requestBuilder
    }

    func getTransactionsPage(account: Account,
                             from: Date,
                             to: Date) async throws -> TransactionsPage {

        let url = try requestBuilder.url(path: "api/v2/feed/account/\(account.id.uuidString.lowercased())/category/\(account.defaultCategory.uuidString.lowercased())/paginated-transactions",
                                         queryItems: [URLQueryItem(name: "minTransactionTimestamp", value: dateFormatStyle.format(from)),
                                                      URLQueryItem(name: "maxTransactionTimestamp", value: dateFormatStyle.format(to))])

        let dto = try await apiClient.get(TransactionsPageDTO.self,
                                          url: url)

        return TransactionsPage(items: dto.feedItems.map { $0.toDomain() })
    }
}
