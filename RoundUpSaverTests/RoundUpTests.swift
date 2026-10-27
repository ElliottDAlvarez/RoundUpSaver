//
//  RoundUpTests.swift
//  RoundUpSaverTests
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation
import Testing
@testable import RoundUpSaver

// MARK: - Calculator

struct RoundUpCalculatorTests {
    private let calculator = RoundUpCalculator()

    @Test func roundsUpSpecificationExample() {
        #expect(calculator.calculate(transactions: Fixture.transactions([435, 520, 87])) == 158)
    }

    @Test(arguments: [(500, 0), (1, 99), (99, 1), (100, 0), (101, 99)])
    func roundsEachAmountToTheNextPound(amount: Int, expected: Int) {
        #expect(calculator.calculate(transactions: [Fixture.transaction(amount)]) == expected)
    }

    @Test func ignoresInboundTransactions() {
        let transactions = [Fixture.transaction(435, id: Fixture.uuid(1)),
                            Fixture.transaction(1_001, id: Fixture.uuid(2), direction: .inbound)]

        #expect(calculator.calculate(transactions: transactions) == 65)
    }

    @Test func ignoresInternalTransfersAndDeclinedTransactions() {
        let transactions = [
            Fixture.transaction(435, id: Fixture.uuid(1)),
            Fixture.transaction(158, id: Fixture.uuid(2), source: "INTERNAL_TRANSFER"),
            Fixture.transaction(199, id: Fixture.uuid(3), status: "DECLINED"),
            Fixture.transaction(199, id: Fixture.uuid(4), status: "REVERSED"),
            Fixture.transaction(199, id: Fixture.uuid(5), status: "REFUNDED")
        ]

        #expect(calculator.calculate(transactions: transactions) == 65)
    }

    @Test func ignoresTransactionsAlreadyRoundedUpByTheBackend() {
        let existingRoundUp = RoundUp(goalCategoryId: Fixture.uuid(9),
                                      amount: CurrencyAndAmount(currency: "GBP", amount: 80))
        let transactions = [Fixture.transaction(435, id: Fixture.uuid(1)),
                            Fixture.transaction(520, id: Fixture.uuid(2), roundUp: existingRoundUp)]

        #expect(calculator.calculate(transactions: transactions) == 65)
    }

    @Test func emptyTransactionsReturnZero() {
        #expect(calculator.calculate(transactions: []) == 0)
    }
}

// MARK: - Use case

struct RoundUpSavingsUseCaseTests {

    @Test func transfersRoundUpUsingLatestTransactions() async throws {
        let cached = Fixture.transactions([450], firstId: 50)
        let remote = Fixture.transactions([435, 520, 87])
        let savings = MockSavingsRepository()
        let transactions = MockTransactionsRepository(batches: [cached, remote])

        let useCase = makeUseCase(transactions: transactions, savings: savings)

        let transferred = try await useCase.roundUpWeek(account: Fixture.account,
                                                        week: Fixture.week,
                                                        savingsGoal: Fixture.goal)

        #expect(transferred == CurrencyAndAmount(currency: "GBP", amount: 158))
        #expect(savings.transfers.count == 1)
        #expect(savings.transfers.first?.goal == Fixture.goal)
        #expect(transactions.requestedRanges == [Fixture.week])
    }

    @Test func sameTransactionsAreNeverRoundedUpTwice() async throws {
        let savings = MockSavingsRepository()
        let useCase = makeUseCase(transactions: MockTransactionsRepository(batches: [Fixture.transactions([435, 520, 87])]),
                                  savings: savings)

        _ = try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)

        await #expect(throws: RoundUpSavingsError.nothingToRoundUp) {
            try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)
        }
        #expect(savings.transfers.count == 1)
    }

    @Test func onlyNewTransactionsAreRoundedUpLaterInTheWeek() async throws {
        let original = Fixture.transactions([435, 520, 87])
        let transactions = MockTransactionsRepository(batches: [original])
        let savings = MockSavingsRepository()
        let useCase = makeUseCase(transactions: transactions, savings: savings)

        _ = try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)

        // Customer spends £2.10 more later in the week
        transactions.setBatches([original + Fixture.transactions([210], firstId: 200)])

        let second = try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)

        #expect(second.amount == 90)
        #expect(savings.transfers.map(\.amount.amount) == [158, 90])
        #expect(savings.transfers[0].transferId != savings.transfers[1].transferId)
    }

    @Test func failedTransferCanBeRetriedWithTheSameTransferId() async throws {
        let savings = MockSavingsRepository()
        savings.transferError = APIError.networkError("timed out")

        let useCase = makeUseCase(transactions: MockTransactionsRepository(batches: [Fixture.transactions([435])]),
                                  savings: savings)

        await #expect(throws: APIError.networkError("timed out")) {
            try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)
        }

        savings.transferError = nil
        let transferred = try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)

        #expect(transferred.amount == 65)
        // Idempotency key matches what the first (possibly applied) attempt would have sent
        #expect(savings.transfers.first?.transferId == RoundUpTransferID.make(from: [Fixture.uuid(100)]))
    }

    @Test func pendingRoundUpExcludesPreviouslyRoundedUpTransactions() async {
        let alreadyRounded = Fixture.transaction(435, id: Fixture.uuid(1))
        let history = TestHistoryStore()
        await history.markAsRoundedUp([alreadyRounded.id], accountId: Fixture.account.id)

        let useCase = makeUseCase(history: history)

        let pending = await useCase.pendingRoundUp(account: Fixture.account,
                                                   transactions: [alreadyRounded,
                                                                  Fixture.transaction(520, id: Fixture.uuid(2))])

        #expect(pending == CurrencyAndAmount(currency: "GBP", amount: 80))
    }

    @Test func doesNotTransferWhenFetchingTransactionsFails() async {
        let savings = MockSavingsRepository()
        let useCase = makeUseCase(transactions: MockTransactionsRepository(batches: [Fixture.transactions([435])],
                                                                           error: APIError.statusCode(500)),
                                  savings: savings)

        await #expect(throws: APIError.statusCode(500)) {
            try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)
        }
        #expect(savings.transfers.isEmpty)
    }

    @Test func lockIsReleasedAfterAFailedRoundUp() async throws {
        let useCase = makeUseCase(transactions: MockTransactionsRepository(batches: [Fixture.transactions([500])]))

        // If the lock leaked, the second call would throw `transferInProgress` instead
        for _ in 0..<2 {
            await #expect(throws: RoundUpSavingsError.nothingToRoundUp) {
                try await useCase.roundUpWeek(account: Fixture.account, week: Fixture.week, savingsGoal: Fixture.goal)
            }
        }
    }
}

// MARK: - Transfer id

struct RoundUpTransferIDTests {

    @Test func isStableRegardlessOfOrder() {
        let ids = [Fixture.uuid(1), Fixture.uuid(2), Fixture.uuid(3)]

        #expect(RoundUpTransferID.make(from: ids) == RoundUpTransferID.make(from: ids.reversed()))
    }

    @Test func differsForDifferentTransactions() {
        #expect(RoundUpTransferID.make(from: [Fixture.uuid(1)]) != RoundUpTransferID.make(from: [Fixture.uuid(2)]))
    }

    @Test func isAVersion5UUID() {
        let uuid = RoundUpTransferID.make(from: [Fixture.uuid(1)]).uuid

        #expect(uuid.6 >> 4 == 5)
        #expect(uuid.8 & 0xC0 == 0x80)
    }
}
