//
//  APIRequestBuilder.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

struct APIRequestBuilder: Sendable {
    let baseURL: URL

    func url(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        // Avoid a trailing ? when there are no query items
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }

    /// Resolves a HATEOAS link from a response (absolute, or relative to the API host).
    ///
    /// Requests carry the bearer token, so a link pointing at any other scheme, host or port
    /// is rejected rather than followed.
    func url(resolvingLink link: String) throws -> URL {
        guard let resolved = URL(string: link, relativeTo: baseURL)?.absoluteURL,
              resolved.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              resolved.host?.lowercased() == baseURL.host?.lowercased(),
              resolved.port == baseURL.port else {
            throw APIError.invalidURL
        }

        return resolved
    }
}
