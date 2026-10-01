//
//  TransactionsFeedView.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import SwiftUI

struct TransactionsFeedView: View {
    let account: Account
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        TransactionsFeedContent(transactionsRepository: dependencies.transactionsRepository,
                                roundUpSavingsUseCase: dependencies.roundUpSavingsUseCase,
                                account: account)
        .appBackground()
    }
}

struct TransactionsFeedContent: View {
    @State private var viewModel: TransactionsFeedViewModel
    @State private var isShowingSavingsGoals = false

    init(transactionsRepository: TransactionsRepositoryProtocol,
         roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol,
         account: Account) {
        _viewModel = State(initialValue: TransactionsFeedViewModel(transactionsRepository: transactionsRepository,
                                                                   roundUpSavingsUseCase: roundUpSavingsUseCase,
                                                                   account: account))
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
                .refreshable {
                    await viewModel.refresh()
                }

            case .empty:
                Text("No transactions found")
                    .foregroundStyle(.darkPurple)

            case .failed(let error):
                Text("Error: \(error)")
                    .foregroundStyle(.darkPurple)
            }
        }
        .navigationTitle(viewModel.account.name)
        .navigationDestination(isPresented: $isShowingSavingsGoals) {
            savingsGoalsDestination
        }
        .sensoryFeedback(.selection, trigger: isShowingSavingsGoals) { _, newValue in
            newValue
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Savings") {
                    savingsGoalsDestination
                }
            }
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

            Button {
                isShowingSavingsGoals = true
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
            .disabled(viewModel.roundUp.amount == 0)
        }
    }

    private var savingsGoalsDestination: some View {
        SavingsGoalsView(account: viewModel.account,
                         week: viewModel.week,
                         roundUp: viewModel.roundUp)
    }
}

private struct TransactionRow: View {
    let item: TransactionItem

    var body: some View {
        HStack {
            Text(item.transactionTime)
                .font(AppTypography.caption)
                .foregroundStyle(.pastelPurple)

            Spacer()

            Text("\(item.direction == .outbound ? "-" : "+")\(item.amount.displayString)")
                .font(AppTypography.body)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TransactionsFeedView(account: Account(id: UUID(),
                                              accountType: "DEBUG",
                                              defaultCategory: UUID(),
                                              currency: "GBP",
                                              createdAt: Date(),
                                              name: "Test Account"))
    }
    .environment(AppDependencies())
}
