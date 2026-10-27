//
//  AppTypography.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import SwiftUI

/// The app's type scale. Built on semantic text styles so every font follows the
/// user's Dynamic Type setting, while keeping the design's weights.
enum AppTypography {
    /// 28pt bold at the default size.
    static let title = Font.system(.title, weight: .bold)

    /// 20pt semibold at the default size.
    static let heading = Font.system(.title3, weight: .semibold)

    /// 17pt bold at the default size.
    static let button = Font.system(.headline, weight: .bold)

    /// 16pt regular at the default size.
    static let body = Font.system(.callout)

    /// 13pt regular at the default size.
    static let caption = Font.system(.footnote)
}
