//
//  APIConfiguration.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

/// Holds the backend settings the app needs at runtime.
/// The values come from the launch environment, so no URLs or credentials are kept in source control.
/// To set them, go to Edit Scheme > Run > Arguments > Environment Variables.
struct APIConfiguration: Sendable, Equatable {
    static let baseURLKey = "API_BASE_URL"
    static let accessTokenKey = "API_ACCESS_TOKEN"

    /// Placeholder host used when no base URL is set.
    static let placeholderBaseURL = URL(string: "https://api.example.com")!

    let baseURL: URL
    let accessToken: String?

    init(baseURL: URL, accessToken: String?) {
        self.baseURL = baseURL
        self.accessToken = accessToken
    }

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> APIConfiguration {
        let baseURL = environment[baseURLKey]
            .flatMap { $0.isEmpty ? nil : URL(string: $0) } ?? placeholderBaseURL

        let token = environment[accessTokenKey].flatMap { $0.isEmpty ? nil : $0 }

        return APIConfiguration(baseURL: baseURL, accessToken: token)
    }
}
