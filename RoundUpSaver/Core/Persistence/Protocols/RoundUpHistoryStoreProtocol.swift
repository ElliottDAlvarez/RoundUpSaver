//
//  RoundUpHistoryStoreProtocol.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/// Remembers which transactions have already been rounded up, so they're never saved twice.
protocol RoundUpHistoryStoreProtocol: Sendable {
    func roundedUpTransactionIds(accountId: UUID) async -> Set<UUID>
    func markAsRoundedUp(_ transactionIds: [UUID], accountId: UUID) async
}
