//
//  CreateSavingsGoalView.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import SwiftUI

/// Modal form for creating a savings goal. The coordinator presents and dismisses it.
struct CreateSavingsGoalView: View {
    /// Owned by the coordinator for as long as this screen is presented.
    @Bindable var viewModel: CreateSavingsGoalViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $viewModel.name)
                        .accessibilityIdentifier("savingsGoalNameField")

                    TextField("Target amount (optional)", text: $viewModel.targetAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("savingsGoalTargetField")
                } footer: {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("createSavingsGoalErrorMessage")
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .navigationTitle("New savings goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                    .accessibilityIdentifier("cancelCreateSavingsGoalButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await viewModel.submit() }
                    }
                    .disabled(!viewModel.canSubmit)
                    .accessibilityIdentifier("confirmCreateSavingsGoalButton")
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }
}

#if DEBUG
#Preview {
    CreateSavingsGoalView(viewModel: CreateSavingsGoalViewModel(
        account: UITestFixtures.personalAccount,
        savingsRepository: UITestSavingsRepository(scenario: .standard)
    ))
}
#endif
