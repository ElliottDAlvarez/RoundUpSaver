//
//  RoundUpTransferID.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import CryptoKit
import Foundation

/// Builds a stable, name-based UUID for a round-up transfer.
///
/// The API treats the transfer id as an idempotency key. Deriving it from the transactions being
/// rounded up (rather than using a random UUID) means a retried request can't move the money twice.
enum RoundUpTransferID {
    static func make(from transactionIds: [UUID]) -> UUID {
        let key = transactionIds
            .map { $0.uuidString.lowercased() }
            .sorted()
            .joined(separator: ",")

        var bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))

        // Mark as an RFC 4122 name-based (version 5 style) UUID
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
