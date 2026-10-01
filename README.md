# Starling Tech Test

An iOS app (SwiftUI) that works out round-ups on the last 7 days of transactions and moves them into a savings goal, using the Starling Bank sandbox API.

Note: Given the time constraints of building the app, along with the simplified UI, I decided to use SwiftUI for convenience and speed. In a production app, I would likely use UIKit for more control over the UI and to avoid some of the limitations of SwiftUI where elements and designs needed it. I can do this, if needed, but I wanted to focus on the core functionality first.

## ⚠️ Before running: update the auth token

The Starling sandbox access token is **hardcoded** and expires after a short time. To run the app against the API, replace it with your own token first.

**Where:** [`StarlingTechTest/Core/Networking/APIClient.swift`](StarlingTechTest/Core/Networking/APIClient.swift), in `makeRequest(url:method:)`:

```swift
urlRequest.setValue("Bearer <YOUR_ACCESS_TOKEN>", forHTTPHeaderField: "Authorization")
```

Replace everything after `Bearer ` with a valid sandbox access token.

## Configuration

- **Base URL:** `https://api-sandbox.starlingbank.com`, set in [`StarlingTechTest/App/DependencyInjection/AppDependencies.swift`](StarlingTechTest/App/DependencyInjection/AppDependencies.swift).

## Running

1. Open `StarlingTechTest.xcodeproj` in Xcode.
2. Update the auth token (see above).
3. Select the `StarlingTechTest` scheme and run on a simulator or device.

## Tests

- **Unit tests:** `StarlingTechTestTests`
- **UI tests:** `StarlingTechTestUITests`. These use `UITestingDependencies`, so they don't need a valid token.

Run all tests with `⌘U` in Xcode.
