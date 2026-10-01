//
//  ContentView.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import SwiftUI
import CoreData

struct TransactionsFeedView: View {
    let account: Account
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        TransactionsFeedContent(transactionsRepository: dependencies.transactionsRepository,
                                account: account)
        .appBackground()
    }
}

struct TransactionsFeedContent: View {
    @State var viewModel: TransactionsFeedViewModel

    init(transactionsRepository: TransactionsRepositoryProtocol,
         account: Account) {
        _viewModel = State(initialValue: TransactionsFeedViewModel(transactionsRepository: transactionsRepository,
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
                    ForEach(items) { item in
                        NavigationLink {
                            Text("Item at \(item.transactionTime)")
                        } label: {
                            Text(item.transactionTime)
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
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    TransactionsFeedView(account: Account(id: UUID(),
                                          accountType: "DEBUG",
                                          defaultCategory: UUID(),
                                          currency: "GBP",
                                          createdAt: Date(),
                                          name: "DEBUG ACCOUNT"))
    .environment(AppDependencies())
}
