//
//  AppRoute.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/// Screens that can be pushed onto the app's navigation stack.
enum AppRoute: Hashable {
    case transactionsFeed(account: Account)
    case savingsGoals(account: Account, week: DateInterval, roundUp: CurrencyAndAmount)
}

/// Screens that are shown modally. Plain values, so they can be compared in tests.
enum AppSheet: Hashable, Identifiable {
    case createSavingsGoal(account: Account)

    var id: Self { self }
}
