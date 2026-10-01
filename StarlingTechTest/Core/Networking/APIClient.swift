//
//  APIClient.swift
//  StarlingTechTest
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

    init(session: URLSession = .shared,
         decoder: JSONDecoder = makeDefaultDecoder(),
         encoder: JSONEncoder = JSONEncoder()) {
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

        // Purely for dev purposes, obviously would not have the string hardcoded in a production app, would be stored in a secure location and retrieved at runtime
        urlRequest.setValue("Bearer eyJhbGciOiJQUzI1NiIsInppcCI6IkdaSVAifQ.H4sIAAAAAAAA_21Uy46jMBD8lRHn6REhDsS5zW1_YD-gcbcTa8BGtsnsaLX_viaGEKLcqKp-ulr8LUwIxanAwQBx7z5CRN8Ze27Rfn0o1xfvRRjbFFFjVTeiOkJDtQSBtIejViVIqmhfl1XbNJiC-c9QnHaNLKXYy0P5XhiMmTgemsNEoFJutPGX64j9b0NzbUUkoakIQciGoJVMoIVqj4kvq90u1Y7ui23OaEoh-dC0wHVKE1XdwrFBCRXVmluxQ1IiZaS1PpXiENYsFHUFeDwIELU6gJSqAl2KshIstKz308LKDTw9Sp4ULrdRwWLPJ89Ib09C_BmeBENso9GG_ZbvTIgbZgZEPg15YjLxDrISI6pLz_fIFX97E_kNx3hx3oRkGRhL5mpoxC4Ht9ihVfNoCj2BcjZ61-VGEzNrzmrje4zGWXAa9GhpHkCNIbp-2YN7NHO25mRQctv5CCpcs96jJYx8Iu44DbfArHHEhPCkEpzEBd_KDfjDvEgZzEUyWIPA9Hiea2Zt_YTo0QZU0yJ3Gjqn0pOstTMBbnqbZ3bO8k6bbmmVe2-oW5RnxWaIGxC2UjYp4DX5E-Ds1jk23LzqhrvVeWTycjp58aLEKr6otYq5qLowjV3yL6293lbgGNOC4zDDAZfbST-FdFrpwpynh_Zbdum7ZV_kg_u2dz7yNMB6QSs1kM7Uo6c3K55NLv79B1huaAHHBAAA.glrcQdUmbleruLCWeS-PZPTGQFaGK6OAMYLm0StqUtsud8szOr4GUHnyquSxrJR8Mn68CL9T0ARAoZKhz4hMzJTLzc1G8GwxEkl5jiBbKDsunYwX22_onLmXHBwWDoDUXRIdxeM_NklhVLjBiolefRguNGkkDH-qwAUWX0hbl0UNZeuFVH4NraGBCaxljSZJNlrSIzhn4zCP1-SPoPoYx9NI-eqncNGsfwWOfdDRvuIhBU8te-Gh1gV-gfrl94uUAfvI1FJ5NUfkHtrUAc2E_bP_Rk0uPeJpdZPP4FguvXPHEuduZYQqv_OJxOZRsZv1HLf_1bzcfunddlpcZBvwnYTDt0rTXApVPNds7ixDEPRmUt0C1NWkz1QPSccenQ0gxvsXpPgNUvHgY1IFLxbRD03C31zBBZzJWlfvE--AXgM5GRBGW51an8DPDD3KrjKg2mjs2_IPNmdR5B6xS30teIddl_f_JSucOl-LD5HEStha0EpHL_hIBIqiQVxRKeBlaUNSOdqtwW7vE5COQniYJLN9q4eFrQYocTnL19KqN4RlPpCMlwnCdSfcvxtJAPtekj-fmmUUEHDuH5y_KxQ4oMRbghE2Akegf-xOWhzp0_l7U9uujZHwd3V8VRzC7Zjxpc5BrLV-uNP3BkA_lk1x1Vhi7AvdPULmBC3Wd5j2FPk", forHTTPHeaderField: "Authorization")

        return urlRequest
    }

    func perform<T: Decodable & Sendable>(_ urlRequest: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Appreciate we may want slightly granular here
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
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }

    static func makeDefaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        // Starling returns timestamps with fractional seconds
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Just to cover fractional and non
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) {
                return date
            }

            if let date = try? Date.ISO8601FormatStyle().parse(string) {
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
