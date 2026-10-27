//
//  TestSupport.swift
//  RoundUpSaverTests
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation
import Synchronization
@testable import RoundUpSaver

// MARK: - Fixtures

/// Fixed values only, so every run builds exactly the same inputs.
enum Fixture {
    static let now = Date(timeIntervalSince1970: 1_791_374_400) // Wed 7 Oct 2026, 12:00 UTC
    static let week = DateInterval(start: now.addingTimeInterval(-604_800), end: now)

    static let account = Account(id: uuid(1),
                                 accountType: "PRIMARY",
                                 defaultCategory: uuid(2),
                                 currency: "GBP",
                                 createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                                 name: "Personal")

    static let goal = SavingsGoal(id: uuid(3),
                                  name: "Adventures",
                                  target: nil,
                                  totalSaved: CurrencyAndAmount(currency: "GBP", amount: 0),
                                  savedPercentage: nil,
                                  state: "ACTIVE")

    /// A deterministic UUID, e.g. `uuid(7)` is `00000000-0000-0000-0000-000000000007`.
    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    /// Builds transactions with sequential ids starting at `firstId`.
    static func transactions(_ amounts: [Int], firstId: Int = 100) -> [TransactionItem] {
        amounts.enumerated().map { index, amount in
            transaction(amount, id: uuid(firstId + index))
        }
    }

    static func transaction(_ minorUnits: Int,
                            id: UUID = uuid(100),
                            direction: TransactionDirection = .outbound,
                            transactionTime: String = "2026-10-06T10:00:00.000Z",
                            source: String? = "MASTER_CARD",
                            status: String? = "SETTLED",
                            roundUp: RoundUp? = nil) -> TransactionItem {
        TransactionItem(id: id,
                        categoryId: uuid(2),
                        amount: CurrencyAndAmount(currency: "GBP", amount: minorUnits),
                        direction: direction,
                        transactionTime: transactionTime,
                        source: source,
                        status: status,
                        roundUp: roundUp)
    }
}

struct TestError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Mocks
// Mutable state is guarded by a Mutex, so the mocks are genuinely Sendable and race free
// when called from the use case actor while the test reads them.

final class MockTransactionsRepository: TransactionsRepositoryProtocol {
    private struct State {
        var batches: [[TransactionItem]?]
        var error: Error?
        var requestedRanges: [DateInterval] = []
    }

    private let state: Mutex<State>

    init(batches: [[TransactionItem]?], error: Error? = nil) {
        state = Mutex(State(batches: batches, error: error))
    }

    func setBatches(_ batches: [[TransactionItem]?], error: Error? = nil) {
        state.withLock {
            $0.batches = batches
            $0.error = error
        }
    }

    var requestedRanges: [DateInterval] { state.withLock { $0.requestedRanges } }

    func fetchTransactions(account: Account, from: Date, to: Date) -> AsyncThrowingStream<[TransactionItem]?, Error> {
        let (batches, error) = state.withLock {
            $0.requestedRanges.append(DateInterval(start: from, end: to))
            return ($0.batches, $0.error)
        }

        return AsyncThrowingStream { continuation in
            batches.forEach { continuation.yield($0) }
            continuation.finish(throwing: error)
        }
    }
}

final class MockAccountsRepository: AccountsRepositoryProtocol {
    private let state: Mutex<(batches: [[Account]?], error: Error?)>

    init(batches: [[Account]?], error: Error? = nil) {
        state = Mutex((batches, error))
    }

    func setBatches(_ batches: [[Account]?], error: Error? = nil) {
        state.withLock { $0 = (batches, error) }
    }

    func fetchAccounts() -> AsyncThrowingStream<[Account]?, Error> {
        let (batches, error) = state.withLock { $0 }

        return AsyncThrowingStream { continuation in
            batches.forEach { continuation.yield($0) }
            continuation.finish(throwing: error)
        }
    }
}

final class MockSavingsRepository: SavingsRepositoryProtocol {
    struct Transfer: Equatable {
        let amount: CurrencyAndAmount
        let goal: SavingsGoal
        let transferId: UUID
    }

    private struct State {
        var goals: [SavingsGoal] = []
        var transfers: [Transfer] = []
        var createdGoals: [(name: String, target: CurrencyAndAmount?)] = []
        var transferError: Error?
        var fetchError: Error?
        var createError: Error?
    }

    private let state = Mutex(State())

    var goals: [SavingsGoal] {
        get { state.withLock { $0.goals } }
        set { state.withLock { $0.goals = newValue } }
    }

    var transferError: Error? {
        get { state.withLock { $0.transferError } }
        set { state.withLock { $0.transferError = newValue } }
    }

    var fetchError: Error? {
        get { state.withLock { $0.fetchError } }
        set { state.withLock { $0.fetchError = newValue } }
    }

    var createError: Error? {
        get { state.withLock { $0.createError } }
        set { state.withLock { $0.createError = newValue } }
    }

    var transfers: [Transfer] { state.withLock { $0.transfers } }
    var createdGoalNames: [String] { state.withLock { $0.createdGoals.map(\.name) } }
    var createdGoalTargets: [CurrencyAndAmount?] { state.withLock { $0.createdGoals.map(\.target) } }

    func fetchSavingsGoals(account: Account) async throws -> [SavingsGoal] {
        try state.withLock {
            if let error = $0.fetchError { throw error }
            return $0.goals
        }
    }

    func createSavingsGoal(account: Account, name: String, target: CurrencyAndAmount?) async throws -> UUID {
        try state.withLock {
            if let error = $0.createError { throw error }
            $0.createdGoals.append((name, target))
            return Fixture.uuid(900 + $0.createdGoals.count)
        }
    }

    func transfer(amount: CurrencyAndAmount, to savingsGoal: SavingsGoal, account: Account, transferId: UUID) async throws {
        try state.withLock {
            if let error = $0.transferError { throw error }
            $0.transfers.append(Transfer(amount: amount, goal: savingsGoal, transferId: transferId))
        }
    }
}

actor TestHistoryStore: RoundUpHistoryStoreProtocol {
    private var ids: [UUID: Set<UUID>] = [:]

    func roundedUpTransactionIds(accountId: UUID) -> Set<UUID> {
        ids[accountId] ?? []
    }

    func markAsRoundedUp(_ transactionIds: [UUID], accountId: UUID) {
        ids[accountId, default: []].formUnion(transactionIds)
    }
}

// MARK: - Builders

func makeUseCase(transactions: MockTransactionsRepository = MockTransactionsRepository(batches: []),
                 savings: MockSavingsRepository = MockSavingsRepository(),
                 history: TestHistoryStore = TestHistoryStore()) -> RoundUpSavingsUseCase {
    RoundUpSavingsUseCase(transactionsRepository: transactions,
                          savingsRepository: savings,
                          historyStore: history)
}

@MainActor
func makeDependencies(transactions: MockTransactionsRepository = MockTransactionsRepository(batches: []),
                      accounts: MockAccountsRepository = MockAccountsRepository(batches: []),
                      savings: MockSavingsRepository = MockSavingsRepository()) -> AppDependencies {
    AppDependencies(transactionsRepository: transactions,
                    accountsRepository: accounts,
                    savingsRepository: savings,
                    roundUpSavingsUseCase: makeUseCase(transactions: transactions, savings: savings),
                    now: { Fixture.now })
}
