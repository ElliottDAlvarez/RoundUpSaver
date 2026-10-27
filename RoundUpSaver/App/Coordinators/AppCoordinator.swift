//
//  AppCoordinator.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import SwiftUI
import Observation

/// Root coordinator. It owns the navigation state, creates each screen's view model
/// with its dependencies, and handles navigation requests from those view models.
///
/// The coordinator also owns view model lifetimes: each screen's view model is created once,
/// when its route is first shown, and released when the route leaves the stack. SwiftUI can
/// re-evaluate destinations as often as it likes without creating throwaway view models.
@MainActor
@Observable
final class AppCoordinator: Coordinator {
    var path: [AppRoute] = [] {
        didSet { releaseViewModelsForRemovedRoutes() }
    }

    var sheet: AppSheet? {
        didSet {
            if sheet != oldValue { sheetViewModel = nil }
        }
    }

    @ObservationIgnored private let dependencies: AppDependencies
    @ObservationIgnored private let accountsListViewModel: AccountsListViewModel

    /// One view model per route on the stack. A route is a value, so pushing an identical route
    /// twice would share a view model; no flow in the app does that.
    @ObservationIgnored private var routeViewModels: [AppRoute: AnyObject] = [:]
    @ObservationIgnored private var sheetViewModel: AnyObject?

    /// Runs after the create-goal sheet successfully creates a goal (e.g. to refresh the goals list).
    @ObservationIgnored private var onSavingsGoalCreated: (@MainActor () async -> Void)?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.accountsListViewModel = AccountsListViewModel(accountsRepository: dependencies.accountsRepository)
        self.accountsListViewModel.coordinator = self
    }

    func dismissSheet() {
        sheet = nil
        onSavingsGoalCreated = nil
    }

    /// Called by SwiftUI once a sheet has gone, including after a swipe to dismiss.
    /// Only clears state if no other sheet has been presented in the meantime.
    func sheetDidDismiss() {
        guard sheet == nil else { return }
        onSavingsGoalCreated = nil
    }

    // MARK: - Screen factory

    func makeRootView() -> some View {
        AccountsListView(viewModel: accountsListViewModel)
    }

    @ViewBuilder
    func makeView(for route: AppRoute) -> some View {
        switch route {
        case .transactionsFeed(let account):
            TransactionsFeedView(viewModel: transactionsFeedViewModel(account: account))

        case let .savingsGoals(account, week, roundUp):
            SavingsGoalsView(viewModel: savingsGoalsViewModel(account: account, week: week, roundUp: roundUp))
        }
    }

    @ViewBuilder
    func makeView(for sheet: AppSheet) -> some View {
        switch sheet {
        case .createSavingsGoal(let account):
            CreateSavingsGoalView(viewModel: createSavingsGoalViewModel(account: account))
        }
    }

    // MARK: - View models (created once per route)

    func transactionsFeedViewModel(account: Account) -> TransactionsFeedViewModel {
        viewModel(for: .transactionsFeed(account: account)) {
            TransactionsFeedViewModel(transactionsRepository: dependencies.transactionsRepository,
                                      roundUpSavingsUseCase: dependencies.roundUpSavingsUseCase,
                                      account: account,
                                      coordinator: self,
                                      now: dependencies.now)
        }
    }

    func savingsGoalsViewModel(account: Account,
                               week: DateInterval,
                               roundUp: CurrencyAndAmount) -> SavingsGoalsViewModel {
        viewModel(for: .savingsGoals(account: account, week: week, roundUp: roundUp)) {
            SavingsGoalsViewModel(account: account,
                                  week: week,
                                  roundUp: roundUp,
                                  savingsRepository: dependencies.savingsRepository,
                                  roundUpSavingsUseCase: dependencies.roundUpSavingsUseCase,
                                  coordinator: self)
        }
    }

    func createSavingsGoalViewModel(account: Account) -> CreateSavingsGoalViewModel {
        if let existing = sheetViewModel as? CreateSavingsGoalViewModel {
            return existing
        }

        let viewModel = CreateSavingsGoalViewModel(account: account,
                                                   savingsRepository: dependencies.savingsRepository,
                                                   coordinator: self)
        sheetViewModel = viewModel
        return viewModel
    }

    private func viewModel<ViewModel: AnyObject>(for route: AppRoute,
                                                 make: () -> ViewModel) -> ViewModel {
        if let existing = routeViewModels[route] as? ViewModel {
            return existing
        }

        let viewModel = make()
        routeViewModels[route] = viewModel
        return viewModel
    }

    private func releaseViewModelsForRemovedRoutes() {
        let activeRoutes = Set(path)
        routeViewModels = routeViewModels.filter { activeRoutes.contains($0.key) }
    }
}

// MARK: - Feature coordination

extension AppCoordinator: AccountsListCoordinating {
    func showTransactionsFeed(for account: Account) {
        push(.transactionsFeed(account: account))
    }
}

extension AppCoordinator: TransactionsFeedCoordinating {
    func showSavingsGoals(account: Account, week: DateInterval, roundUp: CurrencyAndAmount) {
        push(.savingsGoals(account: account, week: week, roundUp: roundUp))
    }
}

extension AppCoordinator: SavingsGoalsCoordinating {
    func showCreateSavingsGoal(account: Account, onCreated: @escaping @MainActor () async -> Void) {
        onSavingsGoalCreated = onCreated
        sheet = .createSavingsGoal(account: account)
    }
}

extension AppCoordinator: CreateSavingsGoalCoordinating {
    func didCreateSavingsGoal() async {
        let onCreated = onSavingsGoalCreated
        dismissSheet()
        await onCreated?()
    }

    func didCancelCreateSavingsGoal() {
        dismissSheet()
    }
}
