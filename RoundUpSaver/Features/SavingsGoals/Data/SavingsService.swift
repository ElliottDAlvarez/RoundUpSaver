//
//  SavingsService.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

protocol SavingsServiceProtocol: Sendable {
    func getSavingsGoals(account: Account) async throws -> [SavingsGoal]
    func createSavingsGoal(account: Account,
                           name: String,
                           target: CurrencyAndAmount?) async throws -> UUID
    func addMoney(account: Account,
                  savingsGoalId: UUID,
                  transferId: UUID,
                  amount: CurrencyAndAmount) async throws
}

struct SavingsService: SavingsServiceProtocol {
    private let apiClient: APIClientProtocol
    private let requestBuilder: APIRequestBuilder

    init(apiClient: APIClientProtocol,
         requestBuilder: APIRequestBuilder) {
        self.apiClient = apiClient
        self.requestBuilder = requestBuilder
    }

    func getSavingsGoals(account: Account) async throws -> [SavingsGoal] {
        let url = try requestBuilder.url(path: savingsGoalsPath(account: account))

        let dto = try await apiClient.get(SavingsGoalsListDTO.self, url: url)

        return dto.savingsGoalList.map { $0.toDomain() }
    }

    func createSavingsGoal(account: Account,
                           name: String,
                           target: CurrencyAndAmount?) async throws -> UUID {
        let url = try requestBuilder.url(path: savingsGoalsPath(account: account))

        let request = SavingsGoalRequestDTO(name: name,
                                            currency: account.currency,
                                            target: target)

        let response = try await apiClient.put(CreateOrUpdateSavingsGoalResponseDTO.self,
                                               url: url,
                                               body: request)

        guard response.success else {
            throw APIError.unsuccessful(String(localized: "Unable to create savings goal."))
        }

        return response.savingsGoalUid
    }

    func addMoney(account: Account,
                  savingsGoalId: UUID,
                  transferId: UUID,
                  amount: CurrencyAndAmount) async throws {
        let path = savingsGoalsPath(account: account)
            + "/\(savingsGoalId.uuidString.lowercased())/add-money/\(transferId.uuidString.lowercased())"

        let url = try requestBuilder.url(path: path)

        let response = try await apiClient.put(SavingsGoalTransferResponseDTO.self,
                                               url: url,
                                               body: TopUpRequestDTO(amount: amount))

        guard response.success else {
            throw APIError.unsuccessful(String(localized: "Unable to transfer money to savings goal."))
        }
    }

    private func savingsGoalsPath(account: Account) -> String {
        return "api/v2/account/\(account.id.uuidString.lowercased())/savings-goals"
    }
}
