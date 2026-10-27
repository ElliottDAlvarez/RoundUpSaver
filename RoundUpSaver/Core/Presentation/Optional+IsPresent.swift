//
//  Optional+IsPresent.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 27/10/2026.
//

extension Optional {
    /// Lets an optional message drive an alert: `.alert(isPresented: $viewModel.alertMessage.isPresent)`.
    /// Dismissing the alert clears the message.
    var isPresent: Bool {
        get { self != nil }
        set { if !newValue { self = nil } }
    }
}
