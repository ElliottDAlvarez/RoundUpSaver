//
//  ProductionReadinessTests.swift
//  RoundUpSaverTests
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation
import Testing
@testable import RoundUpSaver

// MARK: - Currency precision

struct CurrencyPrecisionTests {
    private let britishEnglish = Locale(identifier: "en_GB")

    @Test(arguments: [("GBP", 2), ("gbp", 2), ("EUR", 2), ("JPY", 0), ("KRW", 0), ("KWD", 3), ("BHD", 3)])
    func fractionDigitsFollowISO4217(code: String, digits: Int) {
        #expect(CurrencyPrecision.fractionDigits(for: code) == digits)
    }

    @Test(arguments: [("GBP", 115, "£1.15"), ("JPY", 1_500, "JP¥1,500"), ("KWD", 1_250, "KWD 1.250")])
    func displaysWithTheCurrencysOwnPrecision(code: String, minorUnits: Int, expected: String) {
        let display = CurrencyAndAmount(currency: code, amount: minorUnits).displayString(locale: britishEnglish)

        // Normalise the non-breaking spaces some formats use
        #expect(display.replacingOccurrences(of: "\u{00A0}", with: " ") == expected)
    }

    @Test func roundUpUsesTheCurrencysWholeUnit() {
        let calculator = RoundUpCalculator()
        func transaction(_ amount: Int, _ currency: String) -> TransactionItem {
            TransactionItem(id: Fixture.uuid(amount), categoryId: Fixture.uuid(2),
                            amount: CurrencyAndAmount(currency: currency, amount: amount),
                            direction: .outbound, transactionTime: "2026-10-06T10:00:00Z",
                            source: nil, status: nil, roundUp: nil)
        }

        #expect(calculator.calculate(transactions: [transaction(435, "GBP")]) == 65)
        // 1.250 KWD rounds up to 2.000 KWD
        #expect(calculator.calculate(transactions: [transaction(1_250, "KWD")]) == 750)
        // Yen amounts are already whole, so there is nothing to round up
        #expect(calculator.calculate(transactions: [transaction(435, "JPY")]) == 0)
    }

    @Test(arguments: [("12.5", "GBP", 1_250), ("1.25", "KWD", 1_250), ("1.250", "KWD", 1_250), ("1500", "JPY", 1_500)])
    func targetAmountParsingUsesCurrencyPrecision(input: String, currency: String, expected: Int) {
        #expect(CreateSavingsGoalViewModel.minorUnits(from: input, currency: currency) == expected)
    }

    @Test(arguments: [("12.345", "GBP"), ("1.2345", "KWD"), ("15.5", "JPY"), ("12.", "GBP"), (".5", "GBP")])
    func targetAmountParsingRejectsTooManyOrMalformedDecimals(input: String, currency: String) {
        #expect(CreateSavingsGoalViewModel.minorUnits(from: input, currency: currency) == nil)
    }
}

// MARK: - Transactions service

struct TransactionsServiceTests {
    private let baseURL = URL(string: "https://api.test.local")!

    private func feedItem(_ id: Int, amount: Int) -> String {
        """
        {"feedItemUid":"\(Fixture.uuid(id).uuidString)","categoryUid":"\(Fixture.uuid(2).uuidString)",\
        "amount":{"currency":"GBP","minorUnits":\(amount)},"direction":"OUT",\
        "transactionTime":"2026-10-06T10:00:00.000Z","status":"SETTLED"}
        """
    }

    private func makeService(id: String, status: Int = 200, body: String) -> TransactionsService {
        let session = StubURLProtocol.makeSession(id: id) { _ in (status, Data(body.utf8)) }
        return TransactionsService(apiClient: APIClient(session: session),
                                   requestBuilder: APIRequestBuilder(baseURL: baseURL))
    }

    @Test func returnsTheWholeRangeInOneRequest() async throws {
        let body = #"{"feedItems":[\#([feedItem(1, amount: 435), feedItem(2, amount: 520), feedItem(3, amount: 87)].joined(separator: ","))]}"#
        let service = makeService(id: "between", body: body)

        let transactions = try await service.getTransactions(account: Fixture.account,
                                                             from: Fixture.week.start,
                                                             to: Fixture.week.end)

        #expect(transactions.map(\.id) == [Fixture.uuid(1), Fixture.uuid(2), Fixture.uuid(3)])
        #expect(RoundUpCalculator().calculate(transactions: transactions) == 158)
        #expect(StubURLProtocol.recordedRequests(id: "between").count == 1)
    }

    @Test func rejectsRangesLongerThanTheAPIAllowsWithoutCallingIt() async {
        let service = makeService(id: "tooLong", body: #"{"feedItems":[]}"#)
        let start = Fixture.now.addingTimeInterval(-TransactionsService.maximumRange - 1)

        await #expect(throws: APIError.self) {
            try await service.getTransactions(account: Fixture.account, from: start, to: Fixture.now)
        }
        #expect(StubURLProtocol.recordedRequests(id: "tooLong").isEmpty)
    }

    @Test func rejectsReversedRanges() async {
        let service = makeService(id: "reversed", body: #"{"feedItems":[]}"#)

        await #expect(throws: APIError.self) {
            try await service.getTransactions(account: Fixture.account, from: Fixture.week.end, to: Fixture.week.start)
        }
    }

    @Test func surfacesServerErrors() async {
        let service = makeService(id: "serverError", status: 400, body: "")

        await #expect(throws: APIError.statusCode(400)) {
            try await service.getTransactions(account: Fixture.account, from: Fixture.week.start, to: Fixture.week.end)
        }
    }

    @Test func toleratesFeedItemsWithoutUnusedFields() throws {
        // No sourceAmount, updatedAt, source, roundUp etc. The spec marks no FeedItem field as required.
        let json = Data(#"{"feedItems":[\#(feedItem(1, amount: 435))]}"#.utf8)

        let decoded = try APIClient.makeDefaultDecoder().decode(FeedItemsDTO.self, from: json)

        #expect(decoded.feedItems.map(\.feedItemUid) == [Fixture.uuid(1)])
    }
}


// MARK: - Keychain

/// Each test uses its own Keychain service name and deletes it afterwards.
struct KeychainTokenStoreTests {

    private func makeStore() -> KeychainTokenStore {
        KeychainTokenStore(service: "RoundUpSaverTests.\(UUID().uuidString)")
    }

    @Test func savesReadsUpdatesAndDeletes() throws {
        let store = makeStore()
        defer { try? store.delete() }

        #expect(store.accessToken() == nil)

        try store.save("first")
        #expect(store.accessToken() == "first")

        try store.save("rotated")
        #expect(store.accessToken() == "rotated")

        try store.delete()
        #expect(store.accessToken() == nil)
    }

    @MainActor
    @Test func liveDependenciesSeedTheKeychainFromConfiguration() throws {
        let store = makeStore()
        defer { try? store.delete() }

        _ = AppDependencies.live(configuration: APIConfiguration(baseURL: URL(string: "https://api.test.local")!,
                                                                 accessToken: "from-environment"),
                                 persistenceController: PersistenceController(inMemory: true),
                                 historySuiteName: "RoundUpSaverTests.\(UUID().uuidString)",
                                 tokenStore: store)

        #expect(store.accessToken() == "from-environment")
    }
}

// MARK: - View model lifetime

@MainActor
struct CoordinatorViewModelLifetimeTests {

    @Test func sameRouteReusesItsViewModel() {
        let coordinator = AppCoordinator(dependencies: makeDependencies())
        coordinator.showTransactionsFeed(for: Fixture.account)

        let first = coordinator.transactionsFeedViewModel(account: Fixture.account)
        let second = coordinator.transactionsFeedViewModel(account: Fixture.account)

        #expect(first === second)
    }

    @Test func poppingReleasesTheViewModel() {
        let coordinator = AppCoordinator(dependencies: makeDependencies())
        coordinator.showTransactionsFeed(for: Fixture.account)

        weak let released = coordinator.transactionsFeedViewModel(account: Fixture.account)
        #expect(released != nil)

        coordinator.pop()

        #expect(released == nil)
    }

    @Test func eachSheetPresentationStartsWithAFreshForm() {
        let coordinator = AppCoordinator(dependencies: makeDependencies())

        coordinator.showCreateSavingsGoal(for: Fixture.account) {}
        let first = coordinator.createSavingsGoalViewModel(account: Fixture.account)
        first.name = "Draft"
        #expect(coordinator.createSavingsGoalViewModel(account: Fixture.account) === first)

        coordinator.didCancelCreateSavingsGoal()
        coordinator.showCreateSavingsGoal(for: Fixture.account) {}

        #expect(coordinator.createSavingsGoalViewModel(account: Fixture.account).name == "")
    }
}
