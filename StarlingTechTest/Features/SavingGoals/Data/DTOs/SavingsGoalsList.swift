//
//  SavingsGoalsList.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

struct SavingsGoalsListDTO: Decodable, Sendable {
    let savingsGoalList: [SavingsGoalDTO]
}

struct SavingsGoalDTO: Decodable, Sendable {
    let savingsGoalUid: UUID
    let name: String
    let target: CurrencyAndAmount?
    let totalSaved: CurrencyAndAmount
    let savedPercentage: Int?
    let state: String?
}

extension SavingsGoalDTO {
    func toDomain() -> SavingsGoal {
        SavingsGoal(id: savingsGoalUid,
                    name: name,
                    target: target,
                    totalSaved: totalSaved,
                    savedPercentage: savedPercentage,
                    state: state)
    }
}
