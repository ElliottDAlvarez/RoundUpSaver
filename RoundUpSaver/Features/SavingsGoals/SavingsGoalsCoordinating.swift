//
//  SavingsGoalsCoordinating.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

import Foundation

/// Navigation that the savings goals screen can request. A coordinator implements it.
@MainActor
protocol SavingsGoalsCoordinating: AnyObject {
    /// Presents the create-goal form. `onCreated` runs after a goal is created and the form is dismissed.
    func showCreateSavingsGoal(for account: Account, onCreated: @escaping @MainActor () async -> Void)
}

/// Navigation that the create savings goal form can request. A coordinator implements it.
@MainActor
protocol CreateSavingsGoalCoordinating: AnyObject {
    func didCreateSavingsGoal() async
    func didCancelCreateSavingsGoal()
}
