//
//  KeychainTokenStore.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation
import Security

/// Supplies the bearer token for API requests. Asked on every request, so a token can be rotated or
/// revoked without rebuilding the API client.
protocol AccessTokenProviding: Sendable {
    func accessToken() -> String?
}

/// A fixed token, for tests and previews.
struct StaticAccessTokenProvider: AccessTokenProviding {
    let token: String?
    func accessToken() -> String? { token }
}

enum KeychainError: LocalizedError, Equatable {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return String(localized: "Keychain error: \(message)")
        }
    }
}

/// Stores the API access token in the Keychain as a generic password.
///
/// The item is only readable on this device after first unlock, and is never synced or backed up.
struct KeychainTokenStore: AccessTokenProviding {
    static let defaultService = "com.ejd.RoundUpSaver.api"

    let service: String
    let account: String

    init(service: String = defaultService, account: String = "accessToken") {
        self.service = service
        self.account = account
    }

    func accessToken() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }

        return token
    }

    func save(_ token: String) throws {
        let data = Data(token.utf8)

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary,
                                         [kSecValueData as String: data] as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
