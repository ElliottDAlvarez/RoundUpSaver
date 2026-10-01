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

    init(transactionsRepository: TransactionsRepositoryProtocol,
         roundUpSavingsUseCase: RoundUpSavingsUseCaseProtocol,
         account: Account) {
        _viewModel = State(initialValue: TransactionsFeedViewModel(transactionsRepository: transactionsRepository,
                                                                   roundUpSavingsUseCase: roundUpSavingsUseCase,
                                                                   account: account)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ProgressView()

            case .loading:
                ProgressView()

            case .loaded(let items):
                List {
                    Section {
                        roundUpSummary
                    }

                    Section("Transactions") {
                        ForEach(items) { item in
                            TransactionRow(item: item)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }

            case .empty:
                Text("No transactions found")

            case .failed(let error):
                Text("Error: \(error)")
            }
        }
        .navigationTitle(viewModel.account.name)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("This week's round-up")
                .font(AppTypography.caption)

            Text(viewModel.roundUp.displayString)
                .font(AppTypography.title)

            NavigationLink {
                savingsGoalsDestination
            } label: {
                Text("Save round-up")
            }
            .buttonStyle(.primary)
            .disabled(viewModel.roundUp.amount == 0)
        }
        .padding(.vertical, 8)
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

            Spacer()

            Text("\(item.direction == .outbound ? "-" : "+")\(item.amount.displayString)")
                .font(AppTypography.body)
        }
    }
}

#Preview {
    NavigationStack {
        TransactionsFeedView(account: Account(id: UUID(),
                                              accountType: "DEBUG",
                                              defaultCategory: UUID(),
                                              currency: "GBP",
                                              createdAt: Date(),
                                              name: "DEBUG ACCOUNT"))
    }
    .environment(AppDependencies())
}
