//
//  CurrencyAndAmount.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

struct CurrencyAndAmount: Codable, Sendable, Equatable {
    let currency: String
    let amount: Int
    let displayString: String

    enum CodingKeys: String, CodingKey {
        case currency
        case amount = "minorUnits"
    }

    init(currency: String, amount: Int) {
        self.currency = currency
        self.amount = amount
        self.displayString = "\(Double(amount) / 100.0)\(currency)"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currency = try container.decode(String.self, forKey: .currency)

        // For the sake of this and not writing a whole handler, I'm only supporting currencies / 100.
        // Also just doing the bare minimum string handling of currencies
        self.amount = try container.decode(Int.self, forKey: .amount)
        self.displayString = "\(Double(amount) / 100.0)\(currency)"
    }
}
