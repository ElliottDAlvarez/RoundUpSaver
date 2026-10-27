//
//  AccountsListCoordinating.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/// Navigation that the accounts list can request. A coordinator implements it.
@MainActor
protocol AccountsListCoordinating: AnyObject {
    func showTransactionsFeed(for account: Account)
}
