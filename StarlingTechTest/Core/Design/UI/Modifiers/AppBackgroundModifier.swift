//
//  AppBackgroundModifier.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import SwiftUI

fileprivate struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pastelPurple)
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
