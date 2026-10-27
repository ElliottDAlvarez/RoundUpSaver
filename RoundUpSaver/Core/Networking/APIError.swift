//
//  APIError.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case encoding(String)
    case decoding(String)
    case networkError(String)
    case unsuccessful(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "The URL provided is invalid.")
        case .invalidResponse:
            return String(localized: "Invalid response from the server.")
        case .statusCode(let code):
            return String(localized: "Unexpected status code: \(code).")
        case .encoding(let error):
            return String(localized: "Failed to encode the request: \(error)")
        case .decoding(let error):
            return String(localized: "Failed to decode the response: \(error)")
        case .networkError(let error):
            return String(localized: "Network error: \(error)")
        case .unsuccessful(let message):
            return String(localized: "The request was not successful: \(message)")
        }
    }
}
