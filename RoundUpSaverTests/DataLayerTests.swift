//
//  DataLayerTests.swift
//  RoundUpSaverTests
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation
import Synchronization
import Testing
@testable import RoundUpSaver

// MARK: - Core Data cache

/// Each test gets its own in-memory store, so tests are isolated and leave nothing on disk.
struct CoreDataCacheTests {

    @Test func accountsCacheIsEmptyUntilSaved() async throws {
        let store = CoreDataAccountsLocalStore(persistenceController: PersistenceController(inMemory: true))

        #expect(try await store.fetchAccounts() == nil)
    }

    @Test func accountsRoundTripInOrderAndReplacePreviousCache() async throws {
        let store = CoreDataAccountsLocalStore(persistenceController: PersistenceController(inMemory: true))
        let second = Account(id: Fixture.uuid(5), accountType: "ADDITIONAL", defaultCategory: Fixture.uuid(6),
                             currency: "EUR", createdAt: Fixture.now, name: "Joint")

        try await store.save([Fixture.account, second])
        #expect(try await store.fetchAccounts() == [Fixture.account, second])

        try await store.save([second])
        #expect(try await store.fetchAccounts() == [second])
    }

    @Test func transactionsRoundTripIncludingRoundUp() async throws {
        let store = CoreDataTransactionsLocalStore(persistenceController: PersistenceController(inMemory: true))
        let roundUp = RoundUp(goalCategoryId: Fixture.uuid(9), amount: CurrencyAndAmount(currency: "GBP", amount: 65))
        let transactions = [
            Fixture.transaction(435, id: Fixture.uuid(1), transactionTime: "2026-10-06T10:00:00.000Z", roundUp: roundUp),
            Fixture.transaction(1_000, id: Fixture.uuid(2), direction: .inbound,
                                transactionTime: "2026-10-05T10:00:00Z", source: nil, status: nil)
        ]

        try await store.save(transactions, accountId: Fixture.account.id, from: Fixture.week.start, to: Fixture.week.end)
        let cached = try await store.fetchTransactions(accountId: Fixture.account.id,
                                                       from: Fixture.week.start,
                                                       to: Fixture.week.end)

        // Newest first
        #expect(cached == transactions)
    }

    @Test func transactionsAreScopedToAccountAndWindow() async throws {
        let store = CoreDataTransactionsLocalStore(persistenceController: PersistenceController(inMemory: true))
        let inWindow = Fixture.transaction(435, id: Fixture.uuid(1), transactionTime: "2026-10-06T10:00:00.000Z")
        let beforeWindow = Fixture.transaction(250, id: Fixture.uuid(2), transactionTime: "2026-09-01T10:00:00.000Z")
        let wideWindow = DateInterval(start: Date(timeIntervalSince1970: 0), end: Fixture.now)

        try await store.save([inWindow, beforeWindow], accountId: Fixture.account.id, from: wideWindow.start, to: wideWindow.end)

        #expect(try await store.fetchTransactions(accountId: Fixture.account.id,
                                                  from: Fixture.week.start, to: Fixture.week.end) == [inWindow])
        #expect(try await store.fetchTransactions(accountId: Fixture.uuid(99),
                                                  from: wideWindow.start, to: wideWindow.end) == nil)
    }

    @Test func savingAWindowReplacesOnlyThatWindow() async throws {
        let store = CoreDataTransactionsLocalStore(persistenceController: PersistenceController(inMemory: true))
        let old = Fixture.transaction(250, id: Fixture.uuid(1), transactionTime: "2026-09-01T10:00:00.000Z")
        let removedRemotely = Fixture.transaction(435, id: Fixture.uuid(2), transactionTime: "2026-10-06T10:00:00.000Z")
        let replacement = Fixture.transaction(520, id: Fixture.uuid(3), transactionTime: "2026-10-06T11:00:00.000Z")
        let wideWindow = DateInterval(start: Date(timeIntervalSince1970: 0), end: Fixture.now)

        try await store.save([old, removedRemotely], accountId: Fixture.account.id, from: wideWindow.start, to: wideWindow.end)
        try await store.save([replacement], accountId: Fixture.account.id, from: Fixture.week.start, to: Fixture.week.end)

        #expect(try await store.fetchTransactions(accountId: Fixture.account.id,
                                                  from: wideWindow.start, to: wideWindow.end) == [replacement, old])
    }
}

// MARK: - Repositories

private final class StubAccountsLocalStore: AccountsLocalStoreProtocol {
    private let state: Mutex<(cached: [Account]?, saved: [[Account]], saveError: Error?)>

    init(cached: [Account]?, saveError: Error? = nil) {
        state = Mutex((cached, [], saveError))
    }

    var saved: [[Account]] { state.withLock { $0.saved } }

    func fetchAccounts() async throws -> [Account]? { state.withLock { $0.cached } }

    func save(_ accounts: [Account]) async throws {
        try state.withLock {
            if let error = $0.saveError { throw error }
            $0.saved.append(accounts)
        }
    }
}

private struct StubAccountsService: AccountsServiceProtocol {
    let result: Result<[Account], Error>
    func getAccounts() async throws -> [Account] { try result.get() }
}

private final class StubTransactionsLocalStore: TransactionsLocalStoreProtocol {
    private let state: Mutex<(cached: [TransactionItem]?, saved: [(items: [TransactionItem], accountId: UUID, range: DateInterval)])>

    init(cached: [TransactionItem]?) {
        state = Mutex((cached, []))
    }

    var savedAccountIds: [UUID] { state.withLock { $0.saved.map(\.accountId) } }
    var savedRanges: [DateInterval] { state.withLock { $0.saved.map(\.range) } }

    func fetchTransactions(accountId: UUID, from: Date, to: Date) async throws -> [TransactionItem]? {
        state.withLock { $0.cached }
    }

    func save(_ transactions: [TransactionItem], accountId: UUID, from: Date, to: Date) async throws {
        state.withLock { $0.saved.append((transactions, accountId, DateInterval(start: from, end: to))) }
    }
}

private struct StubTransactionsService: TransactionsServiceProtocol {
    let result: Result<[TransactionItem], Error>

    func getTransactions(account: Account, from: Date, to: Date) async throws -> [TransactionItem] {
        try result.get()
    }
}

private func collect<T>(_ stream: AsyncThrowingStream<T, Error>) async -> (values: [T], error: Error?) {
    var values: [T] = []
    do {
        for try await value in stream { values.append(value) }
        return (values, nil)
    } catch {
        return (values, error)
    }
}

struct RepositoryTests {

    @Test func accountsYieldsCacheThenRemoteAndCachesRemote() async {
        let localStore = StubAccountsLocalStore(cached: nil)
        let repository = AccountsRepository(localStore: localStore,
                                            accountsService: StubAccountsService(result: .success([Fixture.account])))

        let result = await collect(repository.fetchAccounts())

        #expect(result.values == [nil, [Fixture.account]])
        #expect(result.error == nil)
        #expect(localStore.saved == [[Fixture.account]])
    }

    @Test func accountsCacheWriteFailureStillDeliversRemoteData() async {
        let repository = AccountsRepository(localStore: StubAccountsLocalStore(cached: nil, saveError: TestError(message: "Disk full")),
                                            accountsService: StubAccountsService(result: .success([Fixture.account])))

        let result = await collect(repository.fetchAccounts())

        #expect(result.values.last == [Fixture.account])
        #expect(result.error == nil)
    }

    @Test func accountsRemoteFailureFollowsCachedData() async {
        let repository = AccountsRepository(localStore: StubAccountsLocalStore(cached: [Fixture.account]),
                                            accountsService: StubAccountsService(result: .failure(TestError(message: "Offline"))))

        let result = await collect(repository.fetchAccounts())

        #expect(result.values == [[Fixture.account]])
        #expect((result.error as? TestError)?.message == "Offline")
    }

    @Test func transactionsAreCachedForTheRequestedAccountAndWindow() async {
        let localStore = StubTransactionsLocalStore(cached: nil)
        let remote = Fixture.transactions([435])
        let repository = TransactionsRepository(localStore: localStore,
                                                transactionsService: StubTransactionsService(result: .success(remote)))

        let result = await collect(repository.fetchTransactions(account: Fixture.account,
                                                                from: Fixture.week.start,
                                                                to: Fixture.week.end))

        #expect(result.values == [nil, remote])
        #expect(localStore.savedAccountIds == [Fixture.account.id])
        #expect(localStore.savedRanges == [Fixture.week])
    }
}

// MARK: - API client

/// Serves canned responses and records requests. Each test uses its own session and handler id,
/// so the suite is safe to run in parallel with everything else.
final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)

    private static let handlers = Mutex<[String: Handler]>([:])
    private static let requests = Mutex<[String: [URLRequest]]>([:])
    static let headerKey = "X-Stub-Id"

    /// Registers `handler` for `id` and clears anything recorded under that id before, so a test
    /// repeated in the same process (e.g. `-test-iterations`) starts from a clean slate.
    static func makeSession(id: String, handler: @escaping Handler) -> URLSession {
        handlers.withLock { $0[id] = handler }
        requests.withLock { $0[id] = [] }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [headerKey: id]
        return URLSession(configuration: configuration)
    }

    static func recordedRequests(id: String) -> [URLRequest] {
        requests.withLock { $0[id] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.headerKey),
              let handler = Self.handlers.withLock({ $0[id] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        Self.requests.withLock { $0[id, default: []].append(request) }

        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

struct APIClientTests {
    private struct Payload: Codable, Sendable, Equatable { let value: String }
    private let url = URL(string: "https://api.test.local/thing")!

    @Test func sendsBearerTokenWhenConfigured() async throws {
        let id = "token"
        let client = APIClient(tokenProvider: StaticAccessTokenProvider(token: "abc123"),
                               session: StubURLProtocol.makeSession(id: id) { _ in (200, Data(#"{"value":"ok"}"#.utf8)) })

        let payload = try await client.get(Payload.self, url: url)

        #expect(payload == Payload(value: "ok"))
        let request = try #require(StubURLProtocol.recordedRequests(id: id).first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func omitsAuthorizationWithoutToken() async throws {
        let id = "noToken"
        let client = APIClient(session: StubURLProtocol.makeSession(id: id) { _ in (200, Data(#"{"value":"ok"}"#.utf8)) })

        _ = try await client.get(Payload.self, url: url)

        let request = try #require(StubURLProtocol.recordedRequests(id: id).first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func mapsNonSuccessStatusCodes() async {
        let client = APIClient(session: StubURLProtocol.makeSession(id: "status") { _ in (403, Data()) })

        await #expect(throws: APIError.statusCode(403)) {
            try await client.get(Payload.self, url: url)
        }
    }

    @Test func mapsDecodingFailures() async {
        let client = APIClient(session: StubURLProtocol.makeSession(id: "decoding") { _ in (200, Data("nope".utf8)) })

        await #expect {
            try await client.get(Payload.self, url: url)
        } throws: { error in
            if case .decoding = error as? APIError { return true }
            return false
        }
    }

    @Test func putSendsJSONBody() async throws {
        let id = "put"
        let client = APIClient(session: StubURLProtocol.makeSession(id: id) { _ in (200, Data(#"{"value":"done"}"#.utf8)) })

        _ = try await client.put(Payload.self, url: url, body: Payload(value: "sent"))

        let request = try #require(StubURLProtocol.recordedRequests(id: id).first)
        #expect(request.httpMethod == "PUT")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test(arguments: ["2026-10-07T12:00:00.000Z", "2026-10-07T12:00:00Z"])
    func decodesISO8601DatesWithOrWithoutFractionalSeconds(_ timestamp: String) throws {
        struct Dated: Decodable { let date: Date }

        let decoded = try APIClient.makeDefaultDecoder().decode(Dated.self, from: Data(#"{"date":"\#(timestamp)"}"#.utf8))

        #expect(decoded.date == Fixture.now)
    }
}

// MARK: - Request building

struct APIRequestBuilderTests {

    @Test func buildsURLWithoutTrailingQuestionMark() throws {
        let url = try APIRequestBuilder(baseURL: URL(string: "https://api.test.local")!).url(path: "api/v2/accounts")

        #expect(url.absoluteString == "https://api.test.local/api/v2/accounts")
    }

    @Test func transactionsRequestUsesLowercasedIdsAndWindow() async throws {
        let id = "feed"
        let session = StubURLProtocol.makeSession(id: id) { _ in (200, Data(#"{"feedItems":[]}"#.utf8)) }
        let service = TransactionsService(apiClient: APIClient(session: session),
                                          requestBuilder: APIRequestBuilder(baseURL: URL(string: "https://api.test.local")!))

        _ = try await service.getTransactions(account: Fixture.account, from: Fixture.week.start, to: Fixture.week.end)

        let url = try #require(StubURLProtocol.recordedRequests(id: id).first?.url)
        #expect(url.path == "/api/v2/feed/account/00000000-0000-0000-0000-000000000001/category/00000000-0000-0000-0000-000000000002/paginated-transactions")
        #expect(url.query?.contains("minTransactionTimestamp=2026-09-30T12:00:00.000Z") == true)
        #expect(url.query?.contains("maxTransactionTimestamp=2026-10-07T12:00:00.000Z") == true)
    }
}
