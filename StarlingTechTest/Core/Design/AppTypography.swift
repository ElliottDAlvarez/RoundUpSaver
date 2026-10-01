//
//  AppTypography.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation
import SwiftUI

enum AppTypography {
    static let title = Font.system(
        size: 28,
        weight: .bold
    )

    static let heading = Font.system(
        size: 20,
        weight: .semibold
    )

    static let button = Font.system(
        size: 18,
        weight: .bold
    )

    static let body = Font.system(
        size: 16,
        weight: .regular
    )

    static let caption = Font.system(
        size: 13,
        weight: .regular
    )
}
