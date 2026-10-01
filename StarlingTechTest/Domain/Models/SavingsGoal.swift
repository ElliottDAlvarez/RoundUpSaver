//
//  SavingsGoal.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

struct SavingsGoal: Identifiable, Sendable, Equatable, Hashable {
    let id: UUID
    let name: String
    let target: CurrencyAndAmount?
    let totalSaved: CurrencyAndAmount
    let savedPercentage: Int?
    let state: String?
}
