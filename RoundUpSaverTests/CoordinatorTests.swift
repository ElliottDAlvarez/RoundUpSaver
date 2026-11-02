//
//  CoordinatorTests.swift
//  RoundUpSaverTests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation
import Testing
@testable import RoundUpSaver

@MainActor
private final class SpyCoordinator: AccountsListCoordinating, TransactionsFeedCoordinating, SavingsGoalsCoordinating {
    var shownAccount: Account?
    var shownSavingsGoals: (account: Account, week: DateInterval, roundUp: CurrencyAndAmount)?
    var createGoalAccount: Account?
    var onCreated: (@MainActor () async -> Void)?

    func showTransactionsFeed(for account: Account) {
        shownAccount = account
    }

    func showSavingsGoals(for account: Account, week: DateInterval, roundUp: CurrencyAndAmount) {
        shownSavingsGoals = (account, week, roundUp)
    }

    func showCreateSavingsGoal(for account: Account, onCreated: @escaping @MainActor () async -> Void) {
        createGoalAccount = account
        self.onCreated = onCreated
    }
}

// MARK: - View models delegate navigation

@MainActor
struct ViewModelNavigationTests {

    @Test func selectingAnAccountAsksCoordinatorToShowTransactions() {
        let coordinator = SpyCoordinator()
        let viewModel = AccountsListViewModel(accountsRepository: MockAccountsRepository(batches: []),
                                              coordinator: coordinator)

        viewModel.didSelect(Fixture.account)

        #expect(coordinator.shownAccount == Fixture.account)
    }

    @Test func savingsGoalsAreShownWithTheFeedsWeekAndRoundUp() async {
        let coordinator = SpyCoordinator()
        let viewModel = TransactionsFeedViewModel(
            transactionsRepository: MockTransactionsRepository(batches: [Fixture.transactions([435])]),
            roundUpSavingsUseCase: makeUseCase(),
            account: Fixture.account,
            coordinator: coordinator,
            now: { Fixture.now }
        )
        await viewModel.load()

        viewModel.showSavingsGoals()

        #expect(coordinator.shownSavingsGoals?.account == Fixture.account)
        #expect(coordinator.shownSavingsGoals?.week == Fixture.week)
        #expect(coordinator.shownSavingsGoals?.roundUp == CurrencyAndAmount(currency: "GBP", amount: 65))
    }

    @Test func creatingAGoalRefreshesTheGoalsList() async {
        let coordinator = SpyCoordinator()
        let savings = MockSavingsRepository()
        let viewModel = SavingsGoalsViewModel(account: Fixture.account,
                                              week: Fixture.week,
                                              roundUp: CurrencyAndAmount(currency: "GBP", amount: 0),
                                              savingsRepository: savings,
                                              roundUpSavingsUseCase: makeUseCase(savings: savings),
                                              coordinator: coordinator)
        await viewModel.load()
        guard case .empty = viewModel.state else {
            Issue.record("Expected empty, got \(viewModel.state)")
            return
        }

        viewModel.showCreateSavingsGoal()
        #expect(coordinator.createGoalAccount == Fixture.account)

        savings.goals = [Fixture.goal]
        await coordinator.onCreated?()

        guard case .loaded([Fixture.goal]) = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
    }
}

// MARK: - AppCoordinator

@MainActor
struct AppCoordinatorTests {

    @Test func startsAtRootWithNoSheet() {
        let coordinator = AppCoordinator(dependencies: makeDependencies())

        #expect(coordinator.path.isEmpty)
        #expect(coordinator.sheet == nil)
    }

    @Test func pushesTransactionsFeedThenSavingsGoals() {
        let coordinator = AppCoordinator(dependencies: makeDependencies())
        let roundUp = CurrencyAndAmount(currency: "GBP", amount: 115)

        coordinator.showTransactionsFeed(for: Fixture.account)
        coordinator.showSavingsGoals(for: Fixture.account, week: Fixture.week, roundUp: roundUp)

        #expect(coordinator.path == [
            .transactionsFeed(account: Fixture.account),
            .savingsGoals(account: Fixture.account, week: Fixture.week, roundUp: roundUp)
        ])
    }

    @Test func popAndPopToRoot() {
        let coordinator = AppCoordinator(dependencies: makeDependencies())
        coordinator.showTransactionsFeed(for: Fixture.account)
        coordinator.showSavingsGoals(for: Fixture.account,
                                     week: Fixture.week,
                                     roundUp: CurrencyAndAmount(currency: "GBP", amount: 0))

        coordinator.pop()
        #expect(coordinator.path == [.transactionsFeed(account: Fixture.account)])

        coordinator.popToRoot()
        #expect(coordinator.path.isEmpty)

        // Popping an empty stack is a no-op
        coordinator.pop()
        #expect(coordinator.path.isEmpty)
    }

    @Test func feedViewModelUsesTheInjectedClock() {
        let coordinator = AppCoordinator(dependencies: makeDependencies())

        let viewModel = coordinator.transactionsFeedViewModel(account: Fixture.account)

        #expect(viewModel.week == Fixture.week)
        #expect(viewModel.coordinator === coordinator)
    }

    @Test func createdGoalDismissesSheetThenRunsCompletion() async {
        let coordinator = AppCoordinator(dependencies: makeDependencies())
        var completionSawSheet: AppSheet?? = .none

        coordinator.showCreateSavingsGoal(for: Fixture.account) {
            completionSawSheet = .some(coordinator.sheet)
        }
        #expect(coordinator.sheet == .createSavingsGoal(account: Fixture.account))

        await coordinator.didCreateSavingsGoal()

        #expect(coordinator.sheet == nil)
        #expect(completionSawSheet == .some(nil))
    }

    @Test func cancellingDismissesWithoutRunningCompletion() async {
        let coordinator = AppCoordinator(dependencies: makeDependencies())
        var completionRan = false

        coordinator.showCreateSavingsGoal(for: Fixture.account) { completionRan = true }
        coordinator.didCancelCreateSavingsGoal()
        await coordinator.didCreateSavingsGoal()

        #expect(coordinator.sheet == nil)
        #expect(completionRan == false)
    }

    @Test func createFormSubmitsThroughTheCoordinator() async {
        let savings = MockSavingsRepository()
        let coordinator = AppCoordinator(dependencies: makeDependencies(savings: savings))
        var completionRan = false

        coordinator.showCreateSavingsGoal(for: Fixture.account) { completionRan = true }
        let form = coordinator.createSavingsGoalViewModel(account: Fixture.account)
        form.name = "Holiday"
        await form.submit()

        #expect(savings.createdGoalNames == ["Holiday"])
        #expect(coordinator.sheet == nil)
        #expect(completionRan)
    }

    @Test func lateSheetDismissCallbackDoesNotClearANewSheet() async {
        let coordinator = AppCoordinator(dependencies: makeDependencies())
        var secondCompletionRan = false

        coordinator.showCreateSavingsGoal(for: Fixture.account) {}
        coordinator.didCancelCreateSavingsGoal()
        coordinator.showCreateSavingsGoal(for: Fixture.account) { secondCompletionRan = true }

        // SwiftUI's onDismiss for the first sheet arrives after the second was presented
        coordinator.sheetDidDismiss()
        await coordinator.didCreateSavingsGoal()

        #expect(secondCompletionRan)
    }
}

// MARK: - Launch environment

struct AppLaunchEnvironmentTests {

    @Test func unitTestHostIsDetected() {
        // This test itself runs inside the unit test host
        #expect(AppLaunchEnvironment.current() == .unitTests)
    }
}

// MARK: - Configuration

struct APIConfigurationTests {

    @Test func readsValuesFromEnvironment() {
        let configuration = APIConfiguration.fromEnvironment([
            APIConfiguration.baseURLKey: "https://api.test.local",
            APIConfiguration.accessTokenKey: "token"
        ])

        #expect(configuration.baseURL == URL(string: "https://api.test.local"))
        #expect(configuration.accessToken == "token")
    }

    @Test func fallsBackToPlaceholderWhenUnset() {
        let configuration = APIConfiguration.fromEnvironment([:])

        #expect(configuration.baseURL == APIConfiguration.placeholderBaseURL)
        #expect(configuration.accessToken == nil)
    }

    @Test func emptyValuesAreTreatedAsUnset() {
        let configuration = APIConfiguration.fromEnvironment([
            APIConfiguration.baseURLKey: "",
            APIConfiguration.accessTokenKey: ""
        ])

        #expect(configuration.baseURL == APIConfiguration.placeholderBaseURL)
        #expect(configuration.accessToken == nil)
    }
}
