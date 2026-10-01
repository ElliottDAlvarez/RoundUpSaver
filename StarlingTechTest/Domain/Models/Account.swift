//
//  Account.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

struct Account: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: UUID
    let accountType: String
    let defaultCategory: UUID
    let currency: String
    let createdAt: Date
    let name: String

    enum CodingKeys: String, CodingKey {
        case accountType, defaultCategory, currency, createdAt, name
        case id = "accountUid"
    }
}
