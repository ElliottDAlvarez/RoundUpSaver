//
//  RoundUpHistoryStoreProtocol.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

protocol RoundUpHistoryStoreProtocol: Sendable {
    func roundedUpTransactionIds(accountId: UUID) async -> Set<UUID>
    func markAsRoundedUp(_ transactionIds: [UUID], accountId: UUID) async
}
