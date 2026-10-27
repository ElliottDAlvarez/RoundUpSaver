//
//  CoreDataError.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

enum CoreDataError: LocalizedError, Equatable {
    case fetchError(String)
    case saveError(String)

    var errorDescription: String? {
        switch self {
        case .fetchError(let message), .saveError(let message):
            return message
        }
    }
}
