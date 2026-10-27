//
//  APIClient.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import Foundation

protocol APIClientProtocol: Sendable {
    func get<T: Decodable & Sendable>(_ type: T.Type,
                                      url: URL) async throws -> T

    func put<Body: Encodable & Sendable, T: Decodable & Sendable>(_ type: T.Type,
                                                                  url: URL,
                                                                  body: Body) async throws -> T
}

actor APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    /// Asked for the token on every request. Never hard-code credentials in source.
    private let tokenProvider: AccessTokenProviding

    init(tokenProvider: AccessTokenProviding = StaticAccessTokenProvider(token: nil),
         session: URLSession = .shared,
         decoder: JSONDecoder = makeDefaultDecoder(),
         encoder: JSONEncoder = JSONEncoder()) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func get<T: Decodable & Sendable>(_ type: T.Type,
                                      url: URL) async throws -> T {
        let urlRequest = makeRequest(url: url, method: "GET")
        return try await perform(urlRequest)
    }

    func put<Body: Encodable & Sendable, T: Decodable & Sendable>(_ type: T.Type,
                                                                  url: URL,
                                                                  body: Body) async throws -> T {
        var urlRequest = makeRequest(url: url, method: "PUT")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try encoder.encode(body)
        } catch {
            throw APIError.encoding(error.localizedDescription)
        }

        return try await perform(urlRequest)
    }
}

private extension APIClient {
    func makeRequest(url: URL,
                     method: String) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken = tokenProvider.accessToken(), !accessToken.isEmpty {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        return urlRequest
    }

    func perform<T: Decodable & Sendable>(_ urlRequest: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.statusCode(httpResponse.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }

        } catch let error as APIError {
            throw error
        } catch let error where error.isCancellation {
            // Surface cancellation as-is so callers can ignore it rather than show an error
            throw CancellationError()
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
}

extension APIClient {
    static func makeDefaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        // The API returns ISO 8601 timestamps, with or without fractional seconds
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = ISO8601DateParser.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(string)"
            )
        }

        return decoder
    }
}
