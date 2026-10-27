//
//  TransactionsFeedCoordinating.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/// Navigation that the transactions feed can request. A coordinator implements it.
@MainActor
protocol TransactionsFeedCoordinating: AnyObject {
    func showSavingsGoals(account: Account, week: DateInterval, roundUp: CurrencyAndAmount)
}
