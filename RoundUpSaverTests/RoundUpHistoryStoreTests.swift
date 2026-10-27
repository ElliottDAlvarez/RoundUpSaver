//
//  RoundUpHistoryStoreTests.swift
//  RoundUpSaverTests
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation
import Synchronization
import Testing
@testable import RoundUpSaver

/// A clock the test can move forward.
private final class TestClock: Sendable {
    private let current: Mutex<Date>

    init(_ start: Date) { current = Mutex(start) }

    var now: @Sendable () -> Date { { self.current.withLock { $0 } } }

    func advance(by interval: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}

/// Each test gets a fresh, uniquely named `UserDefaults` suite that is deleted afterwards.
private struct IsolatedDefaults: ~Copyable {
    let suiteName = "RoundUpSaverTests.\(UUID().uuidString)"

    var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    deinit { UserDefaults().removePersistentDomain(forName: suiteName) }
}

struct UserDefaultsRoundUpHistoryStoreTests {
    private let day: TimeInterval = 60 * 60 * 24

    @Test func remembersIdsPerAccount() async {
        let suite = IsolatedDefaults()
        let store = UserDefaultsRoundUpHistoryStore(suiteName: suite.suiteName, now: { Fixture.now })

        await store.markAsRoundedUp([Fixture.uuid(1), Fixture.uuid(2)], accountId: Fixture.account.id)

        #expect(await store.roundedUpTransactionIds(accountId: Fixture.account.id) == [Fixture.uuid(1), Fixture.uuid(2)])
        #expect(await store.roundedUpTransactionIds(accountId: Fixture.uuid(99)).isEmpty)
    }

    @Test func persistsAcrossInstances() async {
        let suite = IsolatedDefaults()

        await UserDefaultsRoundUpHistoryStore(suiteName: suite.suiteName, now: { Fixture.now })
            .markAsRoundedUp([Fixture.uuid(1)], accountId: Fixture.account.id)

        let reopened = UserDefaultsRoundUpHistoryStore(suiteName: suite.suiteName, now: { Fixture.now })
        #expect(await reopened.roundedUpTransactionIds(accountId: Fixture.account.id) == [Fixture.uuid(1)])
    }

    @Test func prunesEntriesOlderThanRetention() async {
        let suite = IsolatedDefaults()
        let clock = TestClock(Fixture.now)
        let store = UserDefaultsRoundUpHistoryStore(suiteName: suite.suiteName, retention: 30 * day, now: clock.now)

        await store.markAsRoundedUp([Fixture.uuid(1)], accountId: Fixture.account.id)
        clock.advance(by: 20 * day)
        await store.markAsRoundedUp([Fixture.uuid(2)], accountId: Fixture.account.id)
        clock.advance(by: 11 * day)
        await store.markAsRoundedUp([Fixture.uuid(3)], accountId: Fixture.account.id)

        // The first entry is now 31 days old and can no longer fall inside a 7 day window
        #expect(await store.roundedUpTransactionIds(accountId: Fixture.account.id) == [Fixture.uuid(2), Fixture.uuid(3)])
    }

    @Test func migratesLegacyIdList() async {
        let suite = IsolatedDefaults()
        let legacyKey = "roundUpHistory." + Fixture.account.id.uuidString.lowercased()
        suite.defaults.set([Fixture.uuid(1).uuidString], forKey: legacyKey)

        let store = UserDefaultsRoundUpHistoryStore(suiteName: suite.suiteName, now: { Fixture.now })

        #expect(await store.roundedUpTransactionIds(accountId: Fixture.account.id) == [Fixture.uuid(1)])
        #expect(suite.defaults.object(forKey: legacyKey) == nil)
    }
}
