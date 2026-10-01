//
//  APIRequestBuilder.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

struct APIRequestBuilder {
    let baseURL: URL

    func url(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }
}
