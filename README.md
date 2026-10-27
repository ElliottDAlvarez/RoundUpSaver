# RoundUp Saver

A SwiftUI iOS app that calculates round-ups on the last 7 days of card transactions and transfers them into a savings goal.

It shows a modular **MVVM-C** (Model–View–ViewModel–Coordinator) architecture with a separate domain layer, repositories that combine offline cache and network data, Swift Concurrency, and unit and UI tests.

## Architecture

```
RoundUpSaver/
├── App/
│   ├── Coordinators/          # MVVM-C navigation layer
│   │   ├── Coordinator.swift      # Base protocol (push / pop / popToRoot)
│   │   ├── AppRoute.swift         # Typed routes and sheets
│   │   ├── AppCoordinator.swift   # Owns navigation state and builds screens and view models
│   │   └── AppCoordinatorView.swift # Connects coordinator state to NavigationStack and sheets
│   └── DependencyInjection/   # Composition root (live and UI-test dependency graphs)
├── Core/                      # Networking, persistence, design system, shared presentation types
├── Domain/                    # Models and use cases (round-up calculation and transfer)
└── Features/                  # Accounts, TransactionFeed, SavingGoals
    └── <Feature>/
        ├── <Feature>View.swift          # Renders state and passes user actions to the view model
        ├── <Feature>ViewModel.swift     # Presentation logic; asks its coordinator to navigate
        ├── <Feature>Coordinating.swift  # Navigation protocol the feature needs
        └── Data/                        # Service (API), repository, local store, DTOs
```

### How MVVM-C is applied

- **Views** don't know about navigation or dependencies. They receive a view model and call it when the user does something.
- **View models** depend on repositories and use cases through protocols. They request navigation through a small feature-owned protocol (e.g. `TransactionsFeedCoordinating`), which they hold as a `weak` reference.
- **`AppCoordinator`** implements every feature's coordinating protocol. It owns the `NavigationStack` path and the presented sheet, and acts as the factory that builds each view model from `AppDependencies`.
- Modal flows follow the same pattern: `CreateSavingsGoalViewModel` reports back through `CreateSavingsGoalCoordinating`, and the coordinator dismisses the sheet and tells the presenting screen to refresh. Sheets are plain `Hashable` values (`AppSheet`), not closures.
- Every dependency is injected, including the clock (`AppDependencies.now`), so view models behave the same way every time they are tested.
- Because navigation goes through protocols, it can be unit tested without SwiftUI (see `CoordinatorTests.swift`).

### Data and offline behaviour

- Transactions come from `transactions-between`, which returns the whole date range in a single response with no pagination to follow. The API limits it to 1 year per request (the round-up only needs 7 days); `TransactionsService` rejects longer ranges before making a request. `paginated-transactions` is only needed for history longer than a year.
- Repositories return an `AsyncThrowingStream` that yields the Core Data cache first (if there is one) and then the API response, which replaces the cache for that account and date window. A failed cache write never hides fresh data.
- If a refresh fails while content is already on screen, the content stays and an alert explains the problem. If there is nothing to show, an error state with **Try again** is shown instead.
- Round-up transfers use an idempotency key derived from the transactions being rounded up (`RoundUpTransferID`), so retrying after a timeout can't move the money twice. Rounded-up transactions are recorded only after the transfer succeeds. That history is pruned after 30 days (well beyond the 7 day window), so it never grows without limit.

### Platform standards

- **Swift 6 language mode** on every target, so data-race safety is checked at compile time. The few `@unchecked Sendable` and `nonisolated(unsafe)` uses are each documented.
- **Dynamic Type**: `AppTypography` uses semantic text styles, so all text scales with the user's text-size setting.
- **Currencies**: amounts use each currency's ISO 4217 precision (`CurrencyPrecision`) for display, round-ups (to the next whole unit) and parsing goal targets, so JPY (0 decimals) and KWD (3 decimals) are handled correctly.
- **Localisation**: all user-facing text is in `Resources/Localizable.xcstrings`. Strings built in code use `String(localized:)`. `scripts/generate_string_catalog.py` regenerates the catalog from the compiler's extracted strings for CI.
- **View model lifetime**: `AppCoordinator` creates each screen's view model once per route and releases it when the route leaves the stack; views hold them as `@Bindable`.

## Configuration

The app works with a REST banking-style API (accounts, transaction feed, savings goals). No base URL or credentials are kept in the repository. You supply them at runtime as environment variables:

| Variable           | Purpose                     |
| ------------------ | --------------------------- |
| `API_BASE_URL`     | Base URL of the backend API |
| `API_ACCESS_TOKEN` | Bearer token for requests   |

To set them in Xcode, go to **Product › Scheme › Edit Scheme… › Run › Arguments › Environment Variables**. If they're not set, the app uses the placeholder `https://api.example.com`.

The token is stored in the **Keychain** (`KeychainTokenStore`, this device only, available after first unlock). Setting `API_ACCESS_TOKEN` is just a development convenience: on launch it is written to the Keychain, and every request reads the token from there. You can remove the variable once it has been stored. A production app would put the token there through a sign-in flow instead.

> Tip: put your token in a private (non-shared) scheme so it never gets committed.

## Running

1. Open `RoundUpSaver.xcodeproj` in Xcode.
2. Set `API_BASE_URL` and `API_ACCESS_TOKEN` (see above).
3. Select the `RoundUpSaver` scheme and run on a simulator or device.

## Tests

- **Unit tests** (`RoundUpSaverTests`, Swift Testing): round-up calculator and use case, transfer ids, every view model, coordinator navigation and sheet lifecycle, the Core Data cache (in-memory stores), repositories, the API client (stubbed `URLProtocol`), and configuration.
- **UI tests** (`RoundUpSaverUITests`, XCTest): end-to-end flows using stubbed dependencies (`UITestingDependencies.swift`), so they need no network or token.

### Deterministic by design

The tests give the same result on every run:

- Fixtures use fixed ids and dates, and the clock is injected. UI tests pin "now" to 7 Oct 2026 12:00 UTC, with locale `en_GB` and time zone `Europe/London`.
- When the app hosts the unit tests it builds no dependencies (`AppLaunchEnvironment.unitTests`), so tests never trigger network calls or touch the on-disk store.
- Each Core Data test uses its own in-memory store; history stores are in memory, never `UserDefaults`.
- Mocks guard their state with `Mutex`, so they are free of data races under parallel Swift Testing.
- UI tests wait for conditions instead of sleeping, reset device orientation before each test, and run serially.

Run all tests with `⌘U` in Xcode.
