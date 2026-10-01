//
//  SavingsGoalsView.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import SwiftUI

struct SavingsGoalsView: View {
    let account: Account
    let week: DateInterval
    let roundUp: CurrencyAndAmount
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        SavingsGoalsContent(account: account,
                            week: week,
                            roundUp: roundUp,
                            savingsRepository: dependencies.savingsRepository,
                            roundUpSavingsUseCase: dependencies.roundUpSavingsUseCase)
        .appBackground()
    }
}

struct SavingsGoalsContent: View {
    @State private var viewModel: SavingsGoalsViewModel
    @State private var isCreatingGoal = false

    init(account: Account,
         week: DateInterval,
         roundUp: CurrencyAndAmount,
         savingsRepository: SavingsRepositoryProtocol,
         roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol) {
        _viewModel = State(initialValue: SavingsGoalsViewModel(account: account,
                                                               week: week,
                                                               roundUp: roundUp,
                                                               savingsRepository: savingsRepository,
                                                               roundUpSavingsUseCase: roundUpSavingsUseCase)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ProgressView()
                    .tint(.darkPurple)

            case .loading:
                ProgressView()
                    .tint(.darkPurple)

            case .loaded(let goals):
                List {
                    Section {
                        HStack(spacing: 8) {
                            Text("Round-up to save:")
                                .font(AppTypography.heading)
                                .foregroundStyle(.pastelPurple)

                            Text(viewModel.roundUp.displayString)
                                .font(AppTypography.heading)
                                .foregroundStyle(.white)
                                .accessibilityIdentifier("savingsRoundUpAmount")
                        }
                        .padding(.vertical, 8)
                    } footer: {
                        Text("Choose a savings goal to transfer this week's round-up into.")
                            .font(AppTypography.caption)
                            .foregroundStyle(.darkPurple)
                    }
                    .listRowBackground(Color.darkPurple)

                    Section("Savings goals") {
                        ForEach(goals) { goal in
                            SavingsGoalRow(goal: goal,
                                           canTransfer: viewModel.canTransferRoundUp) {
                                Task { await viewModel.transferRoundUp(to: goal) }
                            }
                                           .listRowBackground(Color.darkPurple)
                        }
                    }
                    .foregroundStyle(.darkPurple)
                }
                .accessibilityIdentifier("savingsGoalsList")
                .refreshable {
                    await viewModel.refresh()
                }

            case .empty:
                VStack(spacing: 16) {
                    Text("No savings goals yet")
                        .font(AppTypography.heading)
                        .accessibilityIdentifier("savingsGoalsEmptyMessage")

                    Button("Create savings goal") {
                        isCreatingGoal = true
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("createFirstSavingsGoalButton")
                }
                .padding()

            case .failed(let error):
                Text("Error: \(error)")
                    .accessibilityIdentifier("savingsGoalsErrorMessage")
            }
        }
        .overlay {
            if viewModel.isProcessing {
                ProgressView()
                    .tint(.darkPurple)
            }
        }
        .navigationTitle("Savings goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatingGoal = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create savings goal")
                .accessibilityIdentifier("addSavingsGoalToolbarButton")
                .disabled(viewModel.isProcessing)
            }
        }
        .sheet(isPresented: $isCreatingGoal) {
            CreateSavingsGoalView { name, target in
                await viewModel.createSavingsGoal(name: name, targetAmount: target)
            }
        }
        .alert(
            "Savings goals",
            isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct SavingsGoalRow: View {
    let goal: SavingsGoal
    let canTransfer: Bool
    let onTransfer: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(AppTypography.title)
                    .foregroundStyle(.pastelPurple)

                Text(progressText)
                    .font(AppTypography.caption)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("savingsGoalProgress_\(goal.name)")
            }

            Spacer()

            Button("Add", action: onTransfer)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.darkPurple)
                .tint(.pastelPurple)
                .disabled(!canTransfer)
                .accessibilityIdentifier("addRoundUpButton_\(goal.name)")
        }
    }

    private var progressText: String {
        guard let target = goal.target else {
            return "Saved \(goal.totalSaved.displayString)"
        }

        return "Saved \(goal.totalSaved.displayString) of \(target.displayString)"
    }
}

private struct CreateSavingsGoalView: View {
    let onCreate: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("savingsGoalNameField")

                TextField("Target amount (optional)", text: $target)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("savingsGoalTargetField")
            }
            .navigationTitle("New savings goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelCreateSavingsGoalButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            isSaving = true
                            await onCreate(name, target)
                            isSaving = false

                            // Errors are surfaced by the parent's alert
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .accessibilityIdentifier("confirmCreateSavingsGoalButton")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SavingsGoalsView(account: Account(id: UUID(),
                                          accountType: "DEBUG",
                                          defaultCategory: UUID(),
                                          currency: "GBP",
                                          createdAt: Date(),
                                          name: "DEBUG ACCOUNT"),
                         week: DateInterval(start: Date().addingTimeInterval(-60 * 60 * 24 * 7), end: Date()),
                         roundUp: CurrencyAndAmount(currency: "GBP", amount: 158))
    }
    .environment(AppDependencies())
}
