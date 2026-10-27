//
//  CurrencyAndAmount.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

struct CurrencyAndAmount: Codable, Sendable, Equatable, Hashable {
    let currency: String
    /// Amount in the currency's minor units, e.g. pence for GBP, yen for JPY, fils for KWD.
    let amount: Int

    enum CodingKeys: String, CodingKey {
        case currency
        case amount = "minorUnits"
    }

    /// The amount in major units, e.g. 1.15 for 115 pence.
    var decimalAmount: Decimal {
        Decimal(amount) / Decimal(CurrencyPrecision.minorUnitsPerMajorUnit(for: currency))
    }

    /// Formatted for the user's locale with the currency's own number of decimal places.
    var displayString: String {
        displayString(locale: .current)
    }

    func displayString(locale: Locale) -> String {
        decimalAmount.formatted(
            .currency(code: currency)
                .precision(.fractionLength(CurrencyPrecision.fractionDigits(for: currency)))
                .locale(locale)
        )
    }
}

/// How many decimal places each currency uses, from ISO 4217.
/// Most currencies use 2; the exceptions are listed explicitly so the result never depends on device settings.
enum CurrencyPrecision {
    private static let zeroDecimalCurrencies: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF"
    ]

    private static let threeDecimalCurrencies: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"
    ]

    static func fractionDigits(for currencyCode: String) -> Int {
        let code = currencyCode.uppercased()
        if zeroDecimalCurrencies.contains(code) { return 0 }
        if threeDecimalCurrencies.contains(code) { return 3 }
        return 2
    }

    /// e.g. 100 for GBP, 1 for JPY, 1000 for KWD.
    static func minorUnitsPerMajorUnit(for currencyCode: String) -> Int {
        (0..<fractionDigits(for: currencyCode)).reduce(1) { value, _ in value * 10 }
    }
}
