//
//  UserDefaultsRoundUpHistoryStore.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

// Just for the sake of the test to avoid CoreData setup etc.
actor UserDefaultsRoundUpHistoryStore: RoundUpHistoryStoreProtocol {
    private let defaults: UserDefaults
    private let keyPrefix = "roundUpHistory."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func roundedUpTransactionIds(accountId: UUID) -> Set<UUID> {
        let stored = defaults.stringArray(forKey: key(for: accountId)) ?? []
        return Set(stored.compactMap(UUID.init(uuidString:)))
    }

    func markAsRoundedUp(_ transactionIds: [UUID], accountId: UUID) {
        let updated = roundedUpTransactionIds(accountId: accountId).union(transactionIds)
        defaults.set(updated.map(\.uuidString), forKey: key(for: accountId))
    }

    private func key(for accountId: UUID) -> String {
        keyPrefix + accountId.uuidString.lowercased()
    }
}
