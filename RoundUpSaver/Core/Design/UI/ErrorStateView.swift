//
//  ErrorStateView.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

import SwiftUI

/// Full-screen error message with a retry button, so a failed load is never a dead end.
struct ErrorStateView: View {
    let message: String
    let accessibilityPrefix: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Error: \(message)")
                .font(AppTypography.heading)
                .foregroundStyle(Color.darkPurple)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("\(accessibilityPrefix)ErrorMessage")

            Button("Try again", action: onRetry)
                .buttonStyle(.primary)
                .accessibilityIdentifier("\(accessibilityPrefix)RetryButton")
        }
        .padding()
    }
}

#Preview {
    ErrorStateView(message: "Unable to load accounts", accessibilityPrefix: "preview") {}
        .appBackground()
}
