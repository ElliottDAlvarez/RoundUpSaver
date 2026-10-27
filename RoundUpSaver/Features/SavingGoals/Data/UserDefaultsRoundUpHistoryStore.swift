//
//  UserDefaultsRoundUpHistoryStore.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/// Round-up history kept in `UserDefaults`, which is enough for a small set of ids per account.
///
/// Each id is stored with the time it was rounded up. A round-up only ever covers the last 7 days,
/// so once an entry is older than `retention` its transaction can't appear in a round-up window
/// again. Those entries are pruned so the store doesn't grow forever.
actor UserDefaultsRoundUpHistoryStore: RoundUpHistoryStoreProtocol {
    static let defaultRetention: TimeInterval = 60 * 60 * 24 * 30

    private let defaults: UserDefaults
    private let keyPrefix = "roundUpHistory.v2."
    private let legacyKeyPrefix = "roundUpHistory."
    private let retention: TimeInterval
    private let now: @Sendable () -> Date

    /// - Parameter suiteName: `nil` for the standard defaults. Tests pass a unique suite so they never share state.
    init(suiteName: String? = nil,
         retention: TimeInterval = defaultRetention,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.retention = retention
        self.now = now
    }

    func roundedUpTransactionIds(accountId: UUID) -> Set<UUID> {
        Set(entries(accountId: accountId).keys.compactMap(UUID.init(uuidString:)))
    }

    func markAsRoundedUp(_ transactionIds: [UUID], accountId: UUID) {
        let timestamp = now().timeIntervalSince1970
        let cutoff = timestamp - retention

        var updated = entries(accountId: accountId).filter { $0.value >= cutoff }
        for id in transactionIds {
            updated[id.uuidString] = timestamp
        }

        defaults.set(updated, forKey: key(for: accountId))
    }

    /// Stored ids mapped to when they were rounded up (seconds since 1970).
    private func entries(accountId: UUID) -> [String: Double] {
        if let stored = defaults.dictionary(forKey: key(for: accountId)) as? [String: Double] {
            return stored
        }

        // Earlier versions stored a plain list of ids. Carry them over, timestamped now.
        let legacyKey = legacyKeyPrefix + accountId.uuidString.lowercased()
        guard let legacy = defaults.stringArray(forKey: legacyKey) else { return [:] }

        let timestamp = now().timeIntervalSince1970
        let migrated = Dictionary(legacy.map { ($0, timestamp) }, uniquingKeysWith: { first, _ in first })
        defaults.set(migrated, forKey: key(for: accountId))
        defaults.removeObject(forKey: legacyKey)
        return migrated
    }

    private func key(for accountId: UUID) -> String {
        keyPrefix + accountId.uuidString.lowercased()
    }
}
