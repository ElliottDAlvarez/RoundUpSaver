//
//  ISO8601DateParser.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation

/// Parses the API's ISO 8601 timestamps, which may or may not include fractional seconds.
enum ISO8601DateParser {
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let whole = Date.ISO8601FormatStyle()

    static func date(from string: String) -> Date? {
        (try? fractional.parse(string)) ?? (try? whole.parse(string))
    }
}
