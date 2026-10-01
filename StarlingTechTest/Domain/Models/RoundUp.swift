//
//  RoundUp.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

struct RoundUp: Codable, Sendable, Equatable {
    let goalCategoryId: UUID
    let amount: CurrencyAndAmount

    enum CodingKeys: String, CodingKey {
        case amount
        case goalCategoryId = "goalCategoryUid"
    }
}
