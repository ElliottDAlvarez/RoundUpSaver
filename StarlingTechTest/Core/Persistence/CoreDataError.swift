//
//  CoreDataError.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import Foundation

enum CoreDataError: LocalizedError, Equatable  {
    case saveError(String)
    case fetchError(String)
    case deleteError(String)
    case updateError(String)
    case unknownError
}
