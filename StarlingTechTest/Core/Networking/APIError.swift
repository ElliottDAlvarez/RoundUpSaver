//
//  APIError.swift
//  StarlingTechTest
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
            return "The URL provided is invalid."
        case .invalidResponse:
            return "Invalid response from the server."
        case .statusCode(let code):
            return "Unexpected status code: \(code)."
        case .encoding(let error):
            return "Failed to encode the request: \(error)"
        case .decoding(let error):
            return "Failed to decode the response: \(error)"
        case .networkError(let error):
            return "Network error: \(error)"
        case .unsuccessful(let message):
            return "The request was not successful: \(message)"
        }
    }
}
