//
//  AccountsListView.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

import SwiftUI

struct AccountsListView: View {
    /// Owned by the coordinator, which keeps it alive for the lifetime of the root screen.
    @Bindable var viewModel: AccountsListViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .tint(.darkPurple)

            case .loaded(let items):
                List {
                    ForEach(items) { account in
                        Button {
                            viewModel.didSelect(account)
                        } label: {
                            AccountsCell(account: account)
                        }
                        .accessibilityIdentifier("accountRow_\(account.name)")
                        .listRowBackground(Color.darkPurple)
                    }
                }
                .accessibilityIdentifier("accountsList")

            case .empty:
                Text("No accounts found")
                    .font(AppTypography.heading)
                    .foregroundStyle(Color.darkPurple)
                    .accessibilityIdentifier("accountsEmptyMessage")

            case .failed(let error):
                ErrorStateView(message: error, accessibilityPrefix: "accounts") {
                    Task { await viewModel.retry() }
                }
            }
        }
        .appBackground()
        .navigationTitle("Accounts")
        .alert("Accounts", isPresented: $viewModel.alertMessage.isPresent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
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

#if DEBUG
#Preview {
    NavigationStack {
        AccountsListView(viewModel: AccountsListViewModel(
            accountsRepository: UITestAccountsRepository(scenario: .standard)
        ))
    }
}
#endif
