//
//  Error+Cancellation.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import Foundation

extension Error {
    /// Whether the error just means the work was cancelled (e.g. the screen went away),
    /// so it shouldn't be shown to the user.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
