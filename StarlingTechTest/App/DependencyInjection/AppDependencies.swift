//
//  AppDependencies.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation
import Observation
import CoreData

@MainActor
@Observable
final class AppDependencies {
    let transactionsRepository: TransactionsRepositoryProtocol
    let accountsRepository: AccountsRepositoryProtocol
    let savingsRepository: SavingsRepositoryProtocol
    let roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol

    init() {
        let apiClient = APIClient()

        // Wouldn't normally force unwrap this, but for the sake of the test, I want to keep it simple.
        let baseURL = URL(string: "https://api-sandbox.starlingbank.com")!
        let requestBuilder = APIRequestBuilder(baseURL: baseURL)

        let persistenceController = PersistenceController.shared
        let context = persistenceController.container.viewContext

        // MARK: - Transactions

        let transactionsService = TransactionsService(
            apiClient: apiClient,
            requestBuilder: requestBuilder
        )

        let transactionsLocalStore = CoreDataTransactionsLocalStore(
            context: context
        )

        transactionsRepository = TransactionsRepository(
            localStore: transactionsLocalStore,
            transactionsService: transactionsService
        )

        // MARK: - Accounts

        let accountsService = AccountsService(
            apiClient: apiClient,
            requestBuilder: requestBuilder
        )

        let accountsLocalStore = CoreDataAccountsLocalStore(
            context: context
        )

        accountsRepository = AccountsRepository(
            localStore: accountsLocalStore,
            accountsService: accountsService
        )

        // MARK: - Savings Goals

        let savingsService = SavingsService(
            apiClient: apiClient,
            requestBuilder: requestBuilder
        )

        savingsRepository = SavingsRepository(
            savingsService: savingsService
        )

        // MARK: - Use Cases

        roundUpSavingsUseCase = RoundUpSavingsUseCase(
            transactionsRepository: transactionsRepository,
            savingsRepository: savingsRepository,
            historyStore: UserDefaultsRoundUpHistoryStore()
        )
    }
}
