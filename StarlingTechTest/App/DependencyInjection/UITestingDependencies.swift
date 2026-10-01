//
//  UITestingDependencies.swift
//  StarlingTechTest
//
//  Created by Elliott D'Alvarez on 01/10/2026.
//

#if DEBUG
import Foundation

/// Launch configuration shared with the UI test target.
/// UI tests launch the app with `-UITesting` and optionally set `UITEST_SCENARIO` in the launch environment.
enum UITestConfiguration {
    static let launchArgument = "-UITesting"
    static let scenarioEnvironmentKey = "UITEST_SCENARIO"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static var scenario: UITestScenario {
        let raw = ProcessInfo.processInfo.environment[scenarioEnvironmentKey] ?? ""
        return UITestScenario(rawValue: raw) ?? .standard
    }
}

enum UITestScenario: String {
    case standard
    case emptyAccounts
    case accountsError
    case emptyTransactions
    case transactionsError
    case emptySavingsGoals
    case transferError
}

struct UITestStubError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Fixtures

enum UITestFixtures {
    static let currency = "GBP"

    static let personalAccount = Account(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        accountType: "PRIMARY",
        defaultCategory: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        currency: currency,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        name: "Personal"
    )

    // Round-up: 435 -> 65, 250 -> 50, inbound ignored = 115 (£1.15)
    static func transactions() -> [TransactionItem] {
        let now = Date()
        let formatter = ISO8601DateFormatter()

        return [
            TransactionItem(id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
                            categoryId: personalAccount.defaultCategory,
                            amount: CurrencyAndAmount(currency: currency, amount: 435),
                            direction: .outbound,
                            transactionTime: formatter.string(from: now.addingTimeInterval(-3_600)),
                            source: "MASTER_CARD",
                            status: "SETTLED",
                            roundUp: nil),
            TransactionItem(id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!,
                            categoryId: personalAccount.defaultCategory,
                            amount: CurrencyAndAmount(currency: currency, amount: 250),
                            direction: .outbound,
                            transactionTime: formatter.string(from: now.addingTimeInterval(-7_200)),
                            source: "MASTER_CARD",
                            status: "SETTLED",
                            roundUp: nil),
            TransactionItem(id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003")!,
                            categoryId: personalAccount.defaultCategory,
                            amount: CurrencyAndAmount(currency: currency, amount: 10_000),
                            direction: .inbound,
                            transactionTime: formatter.string(from: now.addingTimeInterval(-10_800)),
                            source: "FASTER_PAYMENTS_IN",
                            status: "SETTLED",
                            roundUp: nil)
        ]
    }

    static let holidayGoal = SavingsGoal(
        id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!,
        name: "Holiday",
        target: CurrencyAndAmount(currency: currency, amount: 50_000),
        totalSaved: CurrencyAndAmount(currency: currency, amount: 1_000),
        savedPercentage: 2,
        state: "ACTIVE"
    )
}

// MARK: - Stub repositories

struct UITestAccountsRepository: AccountsRepositoryProtocol {
    let scenario: UITestScenario

    func fetchAccounts() -> AsyncThrowingStream<[Account]?, Error> {
        AsyncThrowingStream { continuation in
            switch scenario {
            case .emptyAccounts:
                continuation.yield([])
                continuation.finish()
            case .accountsError:
                continuation.finish(throwing: UITestStubError(message: "Unable to load accounts"))
            default:
                continuation.yield([UITestFixtures.personalAccount])
                continuation.finish()
            }
        }
    }
}

struct UITestTransactionsRepository: TransactionsRepositoryProtocol {
    let scenario: UITestScenario

    func fetchTransactions(account: Account,
                           from: Date,
                           to: Date) -> AsyncThrowingStream<[TransactionItem]?, Error> {
        AsyncThrowingStream { continuation in
            switch scenario {
            case .emptyTransactions:
                continuation.yield([])
                continuation.finish()
            case .transactionsError:
                continuation.finish(throwing: UITestStubError(message: "Unable to load transactions"))
            default:
                continuation.yield(UITestFixtures.transactions())
                continuation.finish()
            }
        }
    }
}

actor UITestSavingsRepository: SavingsRepositoryProtocol {
    private let scenario: UITestScenario
    private var goals: [SavingsGoal]

    init(scenario: UITestScenario) {
        self.scenario = scenario
        self.goals = scenario == .emptySavingsGoals ? [] : [UITestFixtures.holidayGoal]
    }

    func fetchSavingsGoals(account: Account) async throws -> [SavingsGoal] {
        goals
    }

    func createSavingsGoal(account: Account,
                           name: String,
                           target: CurrencyAndAmount?) async throws -> UUID {
        let goal = SavingsGoal(id: UUID(),
                               name: name,
                               target: target,
                               totalSaved: CurrencyAndAmount(currency: account.currency, amount: 0),
                               savedPercentage: 0,
                               state: "ACTIVE")
        goals.append(goal)
        return goal.id
    }

    func transfer(amount: CurrencyAndAmount,
                  to savingsGoal: SavingsGoal,
                  account: Account) async throws {
        if scenario == .transferError {
            throw UITestStubError(message: "Transfer failed")
        }

        guard let index = goals.firstIndex(where: { $0.id == savingsGoal.id }) else { return }
        let existing = goals[index]
        goals[index] = SavingsGoal(id: existing.id,
                                   name: existing.name,
                                   target: existing.target,
                                   totalSaved: CurrencyAndAmount(currency: existing.totalSaved.currency,
                                                                 amount: existing.totalSaved.amount + amount.amount),
                                   savedPercentage: existing.savedPercentage,
                                   state: existing.state)
    }
}

/// In-memory history so UI test runs never leak state between launches.
actor InMemoryRoundUpHistoryStore: RoundUpHistoryStoreProtocol {
    private var storage: [UUID: Set<UUID>] = [:]

    func roundedUpTransactionIds(accountId: UUID) -> Set<UUID> {
        storage[accountId] ?? []
    }

    func markAsRoundedUp(_ transactionIds: [UUID], accountId: UUID) {
        storage[accountId, default: []].formUnion(transactionIds)
    }
}

// MARK: - Factory

extension AppDependencies {
    static func uiTesting(scenario: UITestScenario) -> AppDependencies {
        let transactionsRepository = UITestTransactionsRepository(scenario: scenario)
        let savingsRepository = UITestSavingsRepository(scenario: scenario)

        return AppDependencies(
            transactionsRepository: transactionsRepository,
            accountsRepository: UITestAccountsRepository(scenario: scenario),
            savingsRepository: savingsRepository,
            roundUpSavingsUseCase: RoundUpSavingsUseCase(transactionsRepository: transactionsRepository,
                                                         savingsRepository: savingsRepository,
                                                         historyStore: InMemoryRoundUpHistoryStore())
        )
    }
}
#endif
