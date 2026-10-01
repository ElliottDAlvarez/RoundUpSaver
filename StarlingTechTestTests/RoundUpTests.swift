//
//  RoundUpTests.swift
//  StarlingTechTestTests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation
import Testing
@testable import StarlingTechTest

// MARK: - Helpers

private func makeTransaction(
    _ minorUnits: Int,
    id: UUID = UUID(),
    direction: TransactionDirection = .outbound,
    source: String? = "MASTER_CARD",
    status: String? = "SETTLED",
    roundUp: RoundUp? = nil
) -> TransactionItem {
    TransactionItem(id: id,
                    categoryId: UUID(),
                    amount: CurrencyAndAmount(currency: "GBP", amount: minorUnits),
                    direction: direction,
                    transactionTime: "2026-09-29T10:00:00.000Z",
                    source: source,
                    status: status,
                    roundUp: roundUp)
}

private let testAccount = Account(id: UUID(),
                                  accountType: "PRIMARY",
                                  defaultCategory: UUID(),
                                  currency: "GBP",
                                  createdAt: Date(),
                                  name: "Test")

private let testGoal = SavingsGoal(id: UUID(),
                                   name: "Adventures",
                                   target: nil,
                                   totalSaved: CurrencyAndAmount(currency: "GBP", amount: 0),
                                   savedPercentage: nil,
                                   state: "ACTIVE")

private let testWeek = DateInterval(start: Date().addingTimeInterval(-604_800), end: Date())

private final class MockTransactionsRepository: TransactionsRepositoryProtocol, @unchecked Sendable {
    var batches: [[TransactionItem]?]
    var error: Error?

    init(batches: [[TransactionItem]?], error: Error? = nil) {
        self.batches = batches
        self.error = error
    }

    func fetchTransactions(account: Account, from: Date, to: Date) -> AsyncThrowingStream<[TransactionItem]?, Error> {
        let batches = batches
        let error = error

        return AsyncThrowingStream { continuation in
            batches.forEach { continuation.yield($0) }
            continuation.finish(throwing: error)
        }
    }
}

private final class MockSavingsRepository: SavingsRepositoryProtocol, @unchecked Sendable {
    var goals: [SavingsGoal] = []
    var transfers: [(CurrencyAndAmount, SavingsGoal)] = []
    var transferError: Error?

    func fetchSavingsGoals(account: Account) async throws -> [SavingsGoal] { goals }

    func createSavingsGoal(account: Account, name: String, target: CurrencyAndAmount?) async throws -> UUID {
        UUID()
    }

    func transfer(amount: CurrencyAndAmount, to savingsGoal: SavingsGoal, account: Account) async throws {
        if let transferError { throw transferError }
        transfers.append((amount, savingsGoal))
    }
}

private actor InMemoryRoundUpHistoryStore: RoundUpHistoryStoreProtocol {
    private var ids: [UUID: Set<UUID>] = [:]

    func roundedUpTransactionIds(accountId: UUID) -> Set<UUID> {
        ids[accountId] ?? []
    }

    func markAsRoundedUp(_ transactionIds: [UUID], accountId: UUID) {
        ids[accountId, default: []].formUnion(transactionIds)
    }
}

// MARK: - Calculator

struct RoundUpCalculatorTests {
    private let calculator = RoundUpCalculator()

    @Test func roundsUpTechTestExample() {
        let transactions = [435, 520, 87].map { makeTransaction($0) }

        #expect(calculator.calculate(transactions: transactions) == 158)
    }

    @Test func wholePoundsAddNothing() {
        #expect(calculator.calculate(transactions: [makeTransaction(500)]) == 0)
    }

    @Test func ignoresInboundTransactions() {
        let transactions = [makeTransaction(435), makeTransaction(1_001, direction: .inbound)]

        #expect(calculator.calculate(transactions: transactions) == 65)
    }

    @Test func ignoresInternalTransfersAndDeclinedTransactions() {
        let transactions = [
            makeTransaction(435),
            makeTransaction(158, source: "INTERNAL_TRANSFER"),
            makeTransaction(199, status: "DECLINED")
        ]

        #expect(calculator.calculate(transactions: transactions) == 65)
    }

    @Test func ignoresTransactionsAlreadyRoundedUpByStarling() {
        let starlingRoundUp = RoundUp(goalCategoryId: UUID(),
                                      amount: CurrencyAndAmount(currency: "GBP", amount: 80))
        let transactions = [makeTransaction(435), makeTransaction(520, roundUp: starlingRoundUp)]

        #expect(calculator.calculate(transactions: transactions) == 65)
    }

    @Test func emptyTransactionsReturnZero() {
        #expect(calculator.calculate(transactions: []) == 0)
    }
}

// MARK: - Use case

struct RoundUpSavingsUseCaseTests {

    @Test func transfersRoundUpUsingLatestTransactions() async throws {
        let cached = [makeTransaction(450)]
        let remote = [435, 520, 87].map { makeTransaction($0) }
        let savingsRepository = MockSavingsRepository()

        let useCase = RoundUpSavingsUseCase(
            transactionsRepository: MockTransactionsRepository(batches: [cached, remote]),
            savingsRepository: savingsRepository,
            historyStore: InMemoryRoundUpHistoryStore()
        )

        let transferred = try await useCase.roundUpWeek(account: testAccount,
                                                        week: testWeek,
                                                        savingsGoal: testGoal)

        #expect(transferred == CurrencyAndAmount(currency: "GBP", amount: 158))
        #expect(savingsRepository.transfers.count == 1)
        #expect(savingsRepository.transfers.first?.1 == testGoal)
    }

    @Test func sameTransactionsAreNeverRoundedUpTwice() async throws {
        let savingsRepository = MockSavingsRepository()

        let useCase = RoundUpSavingsUseCase(
            transactionsRepository: MockTransactionsRepository(batches: [[435, 520, 87].map { makeTransaction($0) }]),
            savingsRepository: savingsRepository,
            historyStore: InMemoryRoundUpHistoryStore()
        )

        _ = try await useCase.roundUpWeek(account: testAccount, week: testWeek, savingsGoal: testGoal)

        await #expect(throws: RoundUpSavingsError.nothingToRoundUp) {
            try await useCase.roundUpWeek(account: testAccount, week: testWeek, savingsGoal: testGoal)
        }
        #expect(savingsRepository.transfers.count == 1)
    }

    @Test func onlyNewTransactionsAreRoundedUpLaterInTheWeek() async throws {
        let original = [435, 520, 87].map { makeTransaction($0) }
        let transactionsRepository = MockTransactionsRepository(batches: [original])
        let savingsRepository = MockSavingsRepository()

        let useCase = RoundUpSavingsUseCase(
            transactionsRepository: transactionsRepository,
            savingsRepository: savingsRepository,
            historyStore: InMemoryRoundUpHistoryStore()
        )

        _ = try await useCase.roundUpWeek(account: testAccount, week: testWeek, savingsGoal: testGoal)

        // Customer spends £2.10 more later in the week
        transactionsRepository.batches = [original + [makeTransaction(210)]]

        let second = try await useCase.roundUpWeek(account: testAccount, week: testWeek, savingsGoal: testGoal)

        #expect(second.amount == 90)
        #expect(savingsRepository.transfers.map(\.0.amount) == [158, 90])
    }

    @Test func failedTransferCanBeRetried() async throws {
        let savingsRepository = MockSavingsRepository()
        savingsRepository.transferError = APIError.statusCode(500)

        let useCase = RoundUpSavingsUseCase(
            transactionsRepository: MockTransactionsRepository(batches: [[makeTransaction(435)]]),
            savingsRepository: savingsRepository,
            historyStore: InMemoryRoundUpHistoryStore()
        )

        await #expect(throws: APIError.statusCode(500)) {
            try await useCase.roundUpWeek(account: testAccount, week: testWeek, savingsGoal: testGoal)
        }

        savingsRepository.transferError = nil
        let transferred = try await useCase.roundUpWeek(account: testAccount, week: testWeek, savingsGoal: testGoal)

        #expect(transferred.amount == 65)
    }

    @Test func pendingRoundUpExcludesPreviouslyRoundedUpTransactions() async {
        let alreadyRounded = makeTransaction(435)
        let historyStore = InMemoryRoundUpHistoryStore()
        await historyStore.markAsRoundedUp([alreadyRounded.id], accountId: testAccount.id)

        let useCase = RoundUpSavingsUseCase(
            transactionsRepository: MockTransactionsRepository(batches: []),
            savingsRepository: MockSavingsRepository(),
            historyStore: historyStore
        )

        let pending = await useCase.pendingRoundUp(account: testAccount,
                                                   transactions: [alreadyRounded, makeTransaction(520)])

        #expect(pending.amount == 80)
    }

    @Test func doesNotTransferWhenFetchingTransactionsFails() async {
        let savingsRepository = MockSavingsRepository()

        let useCase = RoundUpSavingsUseCase(
            transactionsRepository: MockTransactionsRepository(batches: [[makeTransaction(435)]],
                                                               error: APIError.statusCode(500)),
            savingsRepository: savingsRepository,
            historyStore: InMemoryRoundUpHistoryStore()
        )

        await #expect(throws: APIError.statusCode(500)) {
            try await useCase.roundUpWeek(account: testAccount, week: testWeek, savingsGoal: testGoal)
        }
        #expect(savingsRepository.transfers.isEmpty)
    }
}

// MARK: - View models

@MainActor
struct SavingsGoalsViewModelTests {
    @Test func navigatingBackAndForthDoesNotRoundUpTwice() async {
        let savingsRepository = MockSavingsRepository()
        savingsRepository.goals = [testGoal]

        let useCase = RoundUpSavingsUseCase(
            transactionsRepository: MockTransactionsRepository(batches: [[435, 520, 87].map { makeTransaction($0) }]),
            savingsRepository: savingsRepository,
            historyStore: InMemoryRoundUpHistoryStore()
        )

        func makeViewModel() -> SavingsGoalsViewModel {
            SavingsGoalsViewModel(account: testAccount,
                                  week: testWeek,
                                  roundUp: CurrencyAndAmount(currency: "GBP", amount: 158),
                                  savingsRepository: savingsRepository,
                                  roundUpSavingsUseCase: useCase)
        }

        let firstVisit = makeViewModel()
        await firstVisit.load()
        await firstVisit.transferRoundUp(to: testGoal)

        #expect(firstVisit.roundUp.amount == 0)
        #expect(firstVisit.canTransferRoundUp == false)

        let secondVisit = makeViewModel()
        await secondVisit.load()
        await secondVisit.transferRoundUp(to: testGoal)

        #expect(savingsRepository.transfers.count == 1)
        #expect(secondVisit.roundUp.amount == 0)
    }

    @Test func rejectsInvalidTargetAmount() async {
        let viewModel = SavingsGoalsViewModel(
            account: testAccount,
            week: testWeek,
            roundUp: CurrencyAndAmount(currency: "GBP", amount: 0),
            savingsRepository: MockSavingsRepository(),
            roundUpSavingsUseCase: RoundUpSavingsUseCase(
                transactionsRepository: MockTransactionsRepository(batches: []),
                savingsRepository: MockSavingsRepository(),
                historyStore: InMemoryRoundUpHistoryStore()
            )
        )

        let created = await viewModel.createSavingsGoal(name: "Trip", targetAmount: "abc")

        #expect(created == false)
        #expect(viewModel.alertMessage != nil)
    }
}

@MainActor
struct TransactionsFeedViewModelTests {

    @Test func roundUpUpdatesWhenReturningAfterATransfer() async throws {
        let transactions = [435, 520, 87].map { makeTransaction($0) }
        let historyStore = InMemoryRoundUpHistoryStore()

        let viewModel = TransactionsFeedViewModel(
            transactionsRepository: MockTransactionsRepository(batches: [transactions]),
            roundUpSavingsUseCase: RoundUpSavingsUseCase(
                transactionsRepository: MockTransactionsRepository(batches: []),
                savingsRepository: MockSavingsRepository(),
                historyStore: historyStore
            ),
            account: testAccount
        )

        await viewModel.load()
        #expect(viewModel.roundUp.amount == 158)

        // Round-up saved on the savings screen, then the feed reappears
        await historyStore.markAsRoundedUp(transactions.map(\.id), accountId: testAccount.id)
        await viewModel.load()

        #expect(viewModel.roundUp.amount == 0)
    }
}
