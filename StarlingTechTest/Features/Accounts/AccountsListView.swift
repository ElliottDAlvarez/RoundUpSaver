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
        NavigationStack {
            AccountsListContent(accountsRepository: dependencies.accountsRepository)
                .appBackground()
        }
    }
}

struct AccountsListContent: View {
    @State private var viewModel: AccountsListViewModel
    @State private var selectedAccount: Account?

    init(accountsRepository: AccountsRepositoryProtocol) {
        _viewModel = State(initialValue: AccountsListViewModel(accountsRepository: accountsRepository)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ProgressView()
                    .foregroundColor(.darkPurple)

            case .loading:
                ProgressView()
                    .foregroundColor(.darkPurple)

            case .loaded(let items):
                List {
                    ForEach(items) { account in
                        Button {
                            selectedAccount = account
                        } label: {
                            AccountsCell(account: account)
                        }
                        .accessibilityIdentifier("accountRow_\(account.name)")
                        .listRowBackground(Color.darkPurple)
                    }
                }
                .accessibilityIdentifier("accountsList")
                .navigationDestination(item: $selectedAccount) { account in
                    TransactionsFeedView(account: account)
                }

            case .empty:
                Text("No accounts found")
                    .font(AppTypography.heading)
                    .foregroundStyle(Color.darkPurple)
                    .accessibilityIdentifier("accountsEmptyMessage")

            case .failed(let error):
                Text("Error: \(error)")
                    .font(AppTypography.heading)
                    .foregroundStyle(Color.darkPurple)
                    .accessibilityIdentifier("accountsErrorMessage")
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
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 12) {
                Text(account.name.uppercased())
                    .font(AppTypography.heading)
                    .foregroundStyle(Color.pastelPurple)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(account.accountType)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.pastelPurple)
                    .lineLimit(1)
                    .fixedSize()
            }

            Text(account.currency)
                .font(AppTypography.caption)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    AccountsListView()
        .environment(AppDependencies())
}
