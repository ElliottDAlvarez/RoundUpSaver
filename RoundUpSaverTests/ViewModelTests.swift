//
//  ViewModelTests.swift
//  RoundUpSaverTests
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation
import Testing
@testable import RoundUpSaver

// MARK: - Accounts

@MainActor
struct AccountsListViewModelTests {

    @Test func showsCachedThenRemoteAccounts() async {
        let renamed = Account(id: Fixture.account.id, accountType: "PRIMARY", defaultCategory: Fixture.uuid(2),
                              currency: "GBP", createdAt: Fixture.account.createdAt, name: "Renamed")
        let viewModel = AccountsListViewModel(accountsRepository: MockAccountsRepository(batches: [nil, [Fixture.account], [renamed]]))

        await viewModel.load()

        guard case .loaded(let accounts) = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
        #expect(accounts == [renamed])
    }

    @Test func showsEmptyState() async {
        let viewModel = AccountsListViewModel(accountsRepository: MockAccountsRepository(batches: [[]]))

        await viewModel.load()

        guard case .empty = viewModel.state else {
            Issue.record("Expected empty, got \(viewModel.state)")
            return
        }
    }

    @Test func failureCanBeRetried() async {
        let repository = MockAccountsRepository(batches: [], error: TestError(message: "Offline"))
        let viewModel = AccountsListViewModel(accountsRepository: repository)

        await viewModel.load()
        guard case .failed("Offline") = viewModel.state else {
            Issue.record("Expected failed, got \(viewModel.state)")
            return
        }

        repository.setBatches([[Fixture.account]])
        await viewModel.retry()

        guard case .loaded([Fixture.account]) = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
    }

    @Test func refreshFailureKeepsCachedAccountsAndAlerts() async {
        let viewModel = AccountsListViewModel(accountsRepository: MockAccountsRepository(batches: [[Fixture.account]],
                                                                                          error: TestError(message: "Offline")))

        await viewModel.load()

        guard case .loaded([Fixture.account]) = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
        #expect(viewModel.alertMessage == "Offline")
    }

    @Test func loadOnlyRunsOnce() async {
        let repository = MockAccountsRepository(batches: [[Fixture.account]])
        let viewModel = AccountsListViewModel(accountsRepository: repository)

        await viewModel.load()
        repository.setBatches([[]])
        await viewModel.load()

        guard case .loaded = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
    }
}

// MARK: - Transactions feed

@MainActor
struct TransactionsFeedViewModelTests {

    private func makeViewModel(transactions: MockTransactionsRepository,
                               history: TestHistoryStore = TestHistoryStore()) -> TransactionsFeedViewModel {
        TransactionsFeedViewModel(transactionsRepository: transactions,
                                  roundUpSavingsUseCase: makeUseCase(history: history),
                                  account: Fixture.account,
                                  now: { Fixture.now })
    }

    @Test func requestsTheSevenDaysEndingNow() async {
        let transactions = MockTransactionsRepository(batches: [Fixture.transactions([435])])
        let viewModel = makeViewModel(transactions: transactions)

        await viewModel.load()

        #expect(transactions.requestedRanges == [Fixture.week])
        #expect(viewModel.week == Fixture.week)
        #expect(viewModel.title == "Personal")
    }

    @Test func roundUpUpdatesWhenReturningAfterATransfer() async {
        let transactions = Fixture.transactions([435, 520, 87])
        let history = TestHistoryStore()
        let viewModel = makeViewModel(transactions: MockTransactionsRepository(batches: [transactions]), history: history)

        await viewModel.load()
        #expect(viewModel.roundUp.amount == 158)

        // Round-up saved on the savings screen, then the feed reappears
        await history.markAsRoundedUp(transactions.map(\.id), accountId: Fixture.account.id)
        await viewModel.load()

        #expect(viewModel.roundUp.amount == 0)
    }

    @Test func showsEmptyStateWithNoRoundUp() async {
        let viewModel = makeViewModel(transactions: MockTransactionsRepository(batches: [[]]))

        await viewModel.load()

        guard case .empty = viewModel.state else {
            Issue.record("Expected empty, got \(viewModel.state)")
            return
        }
        #expect(viewModel.roundUp.amount == 0)
    }

    @Test func failureCanBeRetried() async {
        let transactions = MockTransactionsRepository(batches: [], error: TestError(message: "Offline"))
        let viewModel = makeViewModel(transactions: transactions)

        await viewModel.load()
        guard case .failed("Offline") = viewModel.state else {
            Issue.record("Expected failed, got \(viewModel.state)")
            return
        }

        transactions.setBatches([Fixture.transactions([435])])
        await viewModel.retry()

        guard case .loaded = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
        #expect(viewModel.roundUp.amount == 65)
    }

    @Test func refreshFailureKeepsTransactionsOnScreen() async {
        let transactions = MockTransactionsRepository(batches: [Fixture.transactions([435])])
        let viewModel = makeViewModel(transactions: transactions)
        await viewModel.load()

        transactions.setBatches([], error: TestError(message: "Offline"))
        await viewModel.refresh()

        guard case .loaded = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
        #expect(viewModel.alertMessage == "Offline")
    }

    @Test func cancellationIsNotShownAsAnError() async {
        let viewModel = makeViewModel(transactions: MockTransactionsRepository(batches: [], error: CancellationError()))

        await viewModel.load()

        guard case .idle = viewModel.state else {
            Issue.record("Expected idle, got \(viewModel.state)")
            return
        }
    }
}

// MARK: - Savings goals

@MainActor
struct SavingsGoalsViewModelTests {

    private func makeViewModel(roundUp: Int,
                               savings: MockSavingsRepository,
                               useCase: RoundUpSavingsUseCase) -> SavingsGoalsViewModel {
        SavingsGoalsViewModel(account: Fixture.account,
                              week: Fixture.week,
                              roundUp: CurrencyAndAmount(currency: "GBP", amount: roundUp),
                              savingsRepository: savings,
                              roundUpSavingsUseCase: useCase)
    }

    @Test func navigatingBackAndForthDoesNotRoundUpTwice() async {
        let savings = MockSavingsRepository()
        savings.goals = [Fixture.goal]
        let useCase = makeUseCase(transactions: MockTransactionsRepository(batches: [Fixture.transactions([435, 520, 87])]),
                                  savings: savings)

        let firstVisit = makeViewModel(roundUp: 158, savings: savings, useCase: useCase)
        await firstVisit.load()
        await firstVisit.transferRoundUp(to: Fixture.goal)

        #expect(firstVisit.roundUp.amount == 0)
        #expect(firstVisit.canTransferRoundUp == false)
        #expect(firstVisit.alertMessage == "\(CurrencyAndAmount(currency: "GBP", amount: 158).displayString) has been added to Adventures.")

        let secondVisit = makeViewModel(roundUp: 158, savings: savings, useCase: useCase)
        await secondVisit.load()
        await secondVisit.transferRoundUp(to: Fixture.goal)

        #expect(savings.transfers.count == 1)
        #expect(secondVisit.roundUp.amount == 0)
        #expect(secondVisit.alertMessage == RoundUpSavingsError.nothingToRoundUp.localizedDescription)
    }

    @Test func failedTransferKeepsRoundUpAvailable() async {
        let savings = MockSavingsRepository()
        savings.goals = [Fixture.goal]
        savings.transferError = TestError(message: "Transfer failed")
        let useCase = makeUseCase(transactions: MockTransactionsRepository(batches: [Fixture.transactions([435])]),
                                  savings: savings)
        let viewModel = makeViewModel(roundUp: 65, savings: savings, useCase: useCase)

        await viewModel.load()
        await viewModel.transferRoundUp(to: Fixture.goal)

        #expect(viewModel.alertMessage == "Transfer failed")
        #expect(viewModel.roundUp.amount == 65)
        #expect(viewModel.canTransferRoundUp)
    }

    @Test func loadFailureCanBeRetried() async {
        let savings = MockSavingsRepository()
        savings.fetchError = TestError(message: "Offline")
        let viewModel = makeViewModel(roundUp: 0, savings: savings, useCase: makeUseCase(savings: savings))

        await viewModel.load()
        guard case .failed("Offline") = viewModel.state else {
            Issue.record("Expected failed, got \(viewModel.state)")
            return
        }

        savings.fetchError = nil
        savings.goals = [Fixture.goal]
        await viewModel.retry()

        guard case .loaded([Fixture.goal]) = viewModel.state else {
            Issue.record("Expected loaded, got \(viewModel.state)")
            return
        }
    }
}

// MARK: - Create savings goal

@MainActor
private final class SpyCreateGoalCoordinator: CreateSavingsGoalCoordinating {
    var created = 0
    var cancelled = 0

    func didCreateSavingsGoal() async { created += 1 }
    func didCancelCreateSavingsGoal() { cancelled += 1 }
}

@MainActor
struct CreateSavingsGoalViewModelTests {

    private func makeViewModel(savings: MockSavingsRepository = MockSavingsRepository(),
                               coordinator: SpyCreateGoalCoordinator) -> CreateSavingsGoalViewModel {
        CreateSavingsGoalViewModel(account: Fixture.account, savingsRepository: savings, coordinator: coordinator)
    }

    @Test func createsGoalAndNotifiesCoordinator() async {
        let savings = MockSavingsRepository()
        let coordinator = SpyCreateGoalCoordinator()
        let viewModel = makeViewModel(savings: savings, coordinator: coordinator)
        viewModel.name = "  Holiday  "
        viewModel.targetAmount = "12.50"

        await viewModel.submit()

        #expect(savings.createdGoalNames == ["Holiday"])
        #expect(savings.createdGoalTargets == [CurrencyAndAmount(currency: "GBP", amount: 1_250)])
        #expect(coordinator.created == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func targetIsOptional() async {
        let savings = MockSavingsRepository()
        let viewModel = makeViewModel(savings: savings, coordinator: SpyCreateGoalCoordinator())
        viewModel.name = "Holiday"

        await viewModel.submit()

        #expect(savings.createdGoalTargets == [nil])
    }

    @Test func cannotSubmitWithoutAName() async {
        let savings = MockSavingsRepository()
        let coordinator = SpyCreateGoalCoordinator()
        let viewModel = makeViewModel(savings: savings, coordinator: coordinator)
        viewModel.name = "   "

        #expect(viewModel.canSubmit == false)
        await viewModel.submit()

        #expect(savings.createdGoalNames.isEmpty)
        #expect(coordinator.created == 0)
        #expect(viewModel.errorMessage == "Please enter a name for your savings goal.")
    }

    @Test(arguments: ["abc", "0", "0.00", "12abc", "1.2.3", "-5", "12.345", "1e3"])
    func rejectsInvalidTargetAmount(_ input: String) async {
        let savings = MockSavingsRepository()
        let coordinator = SpyCreateGoalCoordinator()
        let viewModel = makeViewModel(savings: savings, coordinator: coordinator)
        viewModel.name = "Trip"
        viewModel.targetAmount = input

        await viewModel.submit()

        #expect(viewModel.errorMessage == "Please enter a valid target amount.")
        #expect(savings.createdGoalNames.isEmpty)
        #expect(coordinator.created == 0)
    }

    @Test(arguments: [("250", 25_000), ("12.5", 1_250), ("12,50", 1_250), ("0.01", 1), (" 7 ", 700)])
    func parsesTargetAmountIntoMinorUnits(_ input: String, expected: Int) async {
        let savings = MockSavingsRepository()
        let viewModel = makeViewModel(savings: savings, coordinator: SpyCreateGoalCoordinator())
        viewModel.name = "Trip"
        viewModel.targetAmount = input

        await viewModel.submit()

        #expect(savings.createdGoalTargets == [CurrencyAndAmount(currency: "GBP", amount: expected)])
    }

    @Test func apiFailureStaysOnFormWithError() async {
        let savings = MockSavingsRepository()
        savings.createError = TestError(message: "Server unavailable")
        let coordinator = SpyCreateGoalCoordinator()
        let viewModel = makeViewModel(savings: savings, coordinator: coordinator)
        viewModel.name = "Trip"

        await viewModel.submit()

        #expect(viewModel.errorMessage == "Server unavailable")
        #expect(coordinator.created == 0)
        #expect(viewModel.isSaving == false)
    }

    @Test func cancelNotifiesCoordinator() {
        let coordinator = SpyCreateGoalCoordinator()
        let viewModel = makeViewModel(coordinator: coordinator)

        viewModel.cancel()

        #expect(coordinator.cancelled == 1)
    }
}
