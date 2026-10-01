//
//  SavingsGoalRequest.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

struct SavingsGoalRequestDTO: Encodable, Sendable {
    let name: String
    let currency: String
    let target: CurrencyAndAmount?
    // Ignoring base64EncodedPhoto for this test
}

struct CreateOrUpdateSavingsGoalResponseDTO: Decodable, Sendable {
    let savingsGoalUid: UUID
    let success: Bool
}
