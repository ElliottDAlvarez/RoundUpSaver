//
//  TopUpRequest.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

struct TopUpRequestDTO: Encodable, Sendable {
    let amount: CurrencyAndAmount
}

struct SavingsGoalTransferResponseDTO: Decodable, Sendable {
    let transferUid: UUID
    let success: Bool
}
