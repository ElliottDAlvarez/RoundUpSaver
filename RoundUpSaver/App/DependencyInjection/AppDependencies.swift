//
//  AppDependencies.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

/// Composition root. Builds the dependency graph that `AppCoordinator` uses to create its view models.
@MainActor
final class AppDependencies {
    let transactionsRepository: TransactionsRepositoryProtocol
    let accountsRepository: AccountsRepositoryProtocol
    let savingsRepository: SavingsRepositoryProtocol
    let roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol

    /// Source of the current time. Injected so tests can pin "now" and get the same results every run.
    let now: @Sendable () -> Date

    init(transactionsRepository: TransactionsRepositoryProtocol,
         accountsRepository: AccountsRepositoryProtocol,
         savingsRepository: SavingsRepositoryProtocol,
         roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.transactionsRepository = transactionsRepository
        self.accountsRepository = accountsRepository
        self.savingsRepository = savingsRepository
        self.roundUpSavingsUseCase = roundUpSavingsUseCase
        self.now = now
    }

    /// The live dependency graph, talking to the real API and caching to disk.
    static func live(configuration: APIConfiguration = .fromEnvironment(),
                     persistenceController: PersistenceController = PersistenceController(),
                     historySuiteName: String? = nil,
                     tokenStore: KeychainTokenStore = KeychainTokenStore()) -> AppDependencies {
        // A token in the launch environment is a development convenience only: it is moved into the
        // Keychain, and from then on requests always read it from there.
        if let seededToken = configuration.accessToken {
            try? tokenStore.save(seededToken)
        }

        let apiClient = APIClient(tokenProvider: tokenStore)
        let requestBuilder = APIRequestBuilder(baseURL: configuration.baseURL)

        let transactionsRepository = TransactionsRepository(
            localStore: CoreDataTransactionsLocalStore(persistenceController: persistenceController),
            transactionsService: TransactionsService(apiClient: apiClient, requestBuilder: requestBuilder)
        )

        let accountsRepository = AccountsRepository(
            localStore: CoreDataAccountsLocalStore(persistenceController: persistenceController),
            accountsService: AccountsService(apiClient: apiClient, requestBuilder: requestBuilder)
        )

        let savingsRepository = SavingsRepository(
            savingsService: SavingsService(apiClient: apiClient, requestBuilder: requestBuilder)
        )

        let roundUpSavingsUseCase = RoundUpSavingsUseCase(
            transactionsRepository: transactionsRepository,
            savingsRepository: savingsRepository,
            historyStore: UserDefaultsRoundUpHistoryStore(suiteName: historySuiteName)
        )

        return AppDependencies(transactionsRepository: transactionsRepository,
                               accountsRepository: accountsRepository,
                               savingsRepository: savingsRepository,
                               roundUpSavingsUseCase: roundUpSavingsUseCase)
    }
}
