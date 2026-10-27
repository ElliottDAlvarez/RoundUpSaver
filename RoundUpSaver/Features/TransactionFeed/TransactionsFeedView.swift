//
//  TransactionsFeedView.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import SwiftUI

struct TransactionsFeedView: View {
    /// Owned by the coordinator for as long as this screen is presented.
    @Bindable var viewModel: TransactionsFeedViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .tint(.darkPurple)

            case .loaded(let items):
                List {
                    if viewModel.roundUp.amount > 0 {
                        Section {
                            roundUpSummary
                                .listRowBackground(Color.darkPurple)
                        }
                    }

                    Section("Transactions") {
                        ForEach(items) { item in
                            TransactionRow(item: item)
                                .listRowBackground(Color.darkPurple)
                        }
                    }
                    .foregroundStyle(.darkPurple)
                }
                .accessibilityIdentifier("transactionsList")
                .refreshable {
                    await viewModel.refresh()
                }

            case .empty:
                Text("No transactions found")
                    .font(AppTypography.heading)
                    .foregroundStyle(.darkPurple)
                    .accessibilityIdentifier("transactionsEmptyMessage")

            case .failed(let error):
                ErrorStateView(message: error, accessibilityPrefix: "transactions") {
                    Task { await viewModel.retry() }
                }
            }
        }
        .appBackground()
        .navigationTitle(viewModel.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Savings") {
                    viewModel.showSavingsGoals()
                }
                .accessibilityIdentifier("savingsToolbarButton")
            }
        }
        .alert("Transactions", isPresented: $viewModel.alertMessage.isPresent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .task {
            await viewModel.load()
        }
    }

    private var roundUpSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week's round-up")
                .font(AppTypography.caption)
                .foregroundStyle(.pastelPurple)

            Text(viewModel.roundUp.displayString)
                .font(AppTypography.title)
                .foregroundStyle(.white)
                .accessibilityIdentifier("roundUpAmount")

            Button {
                viewModel.showSavingsGoals()
            } label: {
                HStack(spacing: 8) {
                    Text("Save round-up?")
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption)
                }
                .font(AppTypography.button)
                .foregroundStyle(.pastelPurple)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saveRoundUpButton")
        }
    }
}

private struct TransactionRow: View {
    let item: TransactionItem

    var body: some View {
        HStack {
            Text(timeText)
                .font(AppTypography.caption)
                .foregroundStyle(.pastelPurple)

            Spacer()

            Text("\(item.direction == .outbound ? "-" : "+")\(item.amount.displayString)")
                .font(AppTypography.body)
                .foregroundStyle(.white)
                .accessibilityIdentifier("transactionAmount")
        }
        .padding(.vertical, 4)
    }

    private var timeText: String {
        item.transactionDate?.formatted(date: .abbreviated, time: .shortened) ?? item.transactionTime
    }
}

#if DEBUG
#Preview {
    let dependencies = AppDependencies.uiTesting(scenario: .standard)

    NavigationStack {
        TransactionsFeedView(viewModel: TransactionsFeedViewModel(
            transactionsRepository: dependencies.transactionsRepository,
            roundUpSavingsUseCase: dependencies.roundUpSavingsUseCase,
            account: UITestFixtures.personalAccount,
            now: dependencies.now
        ))
    }
}
#endif
