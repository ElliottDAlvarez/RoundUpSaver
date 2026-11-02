//
//  SavingsGoalsView.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 30/09/2026.
//

import SwiftUI

struct SavingsGoalsView: View {
    /// Owned by the coordinator for as long as this screen is presented.
    @Bindable var viewModel: SavingsGoalsViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
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
                            SavingsGoalRow(goal: goal, canTransfer: viewModel.canTransferRoundUp) {
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
                        .foregroundStyle(.darkPurple)
                        .accessibilityIdentifier("savingsGoalsEmptyMessage")

                    Button("Create savings goal") {
                        viewModel.showCreateSavingsGoal()
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("createFirstSavingsGoalButton")
                }
                .padding()

            case .failed(let error):
                ErrorStateView(message: error, accessibilityPrefix: "savingsGoals") {
                    Task { await viewModel.retry() }
                }
            }
        }
        .appBackground()
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
                    viewModel.showCreateSavingsGoal()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create savings goal")
                .accessibilityIdentifier("addSavingsGoalToolbarButton")
                .disabled(viewModel.isProcessing)
            }
        }
        .alert("Savings goals", isPresented: $viewModel.alertMessage.isPresent) {
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
            return String(localized: "Saved \(goal.totalSaved.displayString)")
        }

        return String(localized: "Saved \(goal.totalSaved.displayString) of \(target.displayString)")
    }
}

#if DEBUG
#Preview {
    let dependencies = AppDependencies.uiTesting(scenario: .standard)
    let now = dependencies.now()

    NavigationStack {
        SavingsGoalsView(viewModel: SavingsGoalsViewModel(
            account: UITestFixtures.personalAccount,
            week: DateInterval(start: now.addingTimeInterval(-60 * 60 * 24 * 7), end: now),
            roundUp: CurrencyAndAmount(currency: "GBP", amount: 115),
            savingsRepository: dependencies.savingsRepository,
            roundUpSavingsUseCase: dependencies.roundUpSavingsUseCase
        ))
    }
}
#endif
