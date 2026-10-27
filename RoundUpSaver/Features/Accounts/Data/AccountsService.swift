//
//  AccountsService.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

protocol AccountsServiceProtocol: Sendable {
    func getAccounts() async throws -> [Account]
}

struct AccountsService: AccountsServiceProtocol {
    private let apiClient: APIClientProtocol
    private let requestBuilder: APIRequestBuilder

    init(apiClient: APIClientProtocol,
         requestBuilder: APIRequestBuilder) {
        self.apiClient = apiClient
        self.requestBuilder = requestBuilder
    }

    func getAccounts() async throws -> [Account] {
        let url = try requestBuilder.url(path: "api/v2/accounts")

        let accountsList = try await apiClient.get(AccountsList.self, url: url)

        return accountsList.accounts
    }
}
