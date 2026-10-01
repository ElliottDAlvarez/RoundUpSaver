//
//  CurrencyAndAmount.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

struct CurrencyAndAmount: Codable, Sendable, Equatable, Hashable {
    let currency: String
    let amount: Int // Minor currency i.e. pence

    enum CodingKeys: String, CodingKey {
        case currency
        case amount = "minorUnits"
    }

    // For the sake of this and not writing a whole handler, I'm only supporting currencies / 100.
    var displayString: String {
        (Decimal(amount) / 100).formatted(.currency(code: currency))
    }
}
