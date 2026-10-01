//
//  AccountsListView.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import SwiftUI
import CoreData

struct AccountsListView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        AccountsListContent(accountsRepository: dependencies.accountsRepository)
            .appBackground()
    }
}

struct AccountsListContent: View {
    @State private var viewModel: AccountsListViewModel

    init(accountsRepository: AccountsRepositoryProtocol) {
        _viewModel = State(initialValue: AccountsListViewModel(accountsRepository: accountsRepository)
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
                NavigationStack {
                    List {
                        ForEach(items) { account in
                            NavigationLink {
                                TransactionsFeedView(account: account)
                            } label: {
                                AccountsCell(account: account)
                            }
                        }
                    }
                }

            case .empty:
                Text("No accounts found")

            case .failed(let error):
                Text("Error: \(error)")
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct AccountsCell: View {
    let account: Account
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(account.name)
                .font(AppTypography.body)

            Text(
                account.createdAt,
                formatter: itemFormatter
            )
            .font(AppTypography.caption)
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    AccountsListView()
        .environment(AppDependencies())
}
