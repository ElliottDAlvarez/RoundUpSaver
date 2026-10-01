//
//  TransactionsService.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

protocol TransactionsServiceProtocol: Sendable {
    func getTransactionsPage(account: Account, from: Date, to: Date) async throws -> TransactionsPage
}

struct TransactionsService: TransactionsServiceProtocol {
    private let apiClient: APIClientProtocol
    private let requestBuilder: APIRequestBuilder

    init(apiClient: APIClientProtocol,
         requestBuilder: APIRequestBuilder) {
        self.apiClient = apiClient
        self.requestBuilder = requestBuilder
    }

    func getTransactionsPage(account: Account, from: Date, to: Date) async throws -> TransactionsPage {

        let url = try requestBuilder.url(path: "api/v2/feed/account/\(account.id.uuidString.lowercased())/category/\(account.defaultCategory.uuidString.lowercased())/paginated-transactions",
                                         queryItems: [URLQueryItem(name: "minTransactionTimestamp", value: dateFormatter.string(from: from)),
                                                      URLQueryItem(name: "maxTransactionTimestamp", value: dateFormatter.string(from: to))])

        let dto = try await apiClient.get(TransactionsPageDTO.self,
                                          url: url)

        return TransactionsPage(items: dto.feedItems.map { TransactionItem(id: $0.feedItemUid,
                                                                           categoryId: $0.categoryUid,
                                                                           amount: $0.amount,
                                                                           direction: $0.direction,
                                                                           transactionTime: $0.transactionTime,
                                                                           roundUp: $0.roundUp) })
    }

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
