# Migration Guide

## Upgrading to Version 1.0.0

Version 1.0.0 of our Swift SDK introduces significant improvements and modernizations, including the adoption of Async/Await patterns for more concise and readable asynchronous code. While maintaining backward compatibility with completion handlers for all our APIs, we've also introduced several enhancements to optimize and streamline the SDK's usability.

### Key Enhancements:

- **Refined Initialization Process**: We've redesigned the initialization process for the Knock instance, dividing it into two distinct phases. This change offers greater flexibility in integrating our SDK into your projects.

#### Previous Initialization Approach:
```swift
let client = try! Knock(publishableKey: publishableKey, "your-pk": "user-id", hostname: "hostname")
```

#### New in Version 1.0.0:
```swift
// Step 1: Early initialization. Ideal place: AppDelegate.
try? Knock.shared.setup(publishableKey: "your-pk", pushChannelId: "apns-channel-id", options: nil)

// Step 2: Sign in the user. Ideal timing: as soon as you have the userId.
await Knock.shared.signIn(userId: "userid", userToken: nil)
```

- **KnockAppDelegate for Simplified Notification Management**: The introduction of `KnockAppDelegate` allows for effortless integration of push notification handling and token management, reducing boilerplate code and simplifying implementation.

- **Enhanced User Session Management**: New functionalities to sign users out and unregister device tokens have been added, providing more control over user sessions and device management.

- **Centralized Access with Shared Instance**: The SDK now utilizes a shared instance for the Knock client, facilitating easier access and interaction within your app's codebase.

## Upgrading to Version 1.2.0

Version 1.2.0 of our Swift SDK introduces our first pre-built component, the In-App Feed. You can see the updated documentation to learn how to use this component in your own app. We have also combined our Knock.KnockMessageStatusBatchUpdateType into Knock.KnockMessageStatusUpdateType.

### Key Enhancements:

- **In-App Feed pre-built component**
- **Knock.KnockMessageStatusBatchUpdateType is now just Knock.KnockMessageStatusUpdateType**

## Upgrading to Version 2.0.0

Version 2.0.0 builds the SDK in the Swift 6 language mode with complete concurrency checking, and replaces `SwiftPhoenixClient` with [PhoenixNectar](https://github.com/jvdvleuten/PhoenixNectar) for the realtime feed connection.

### Requirements

- iOS 16 or later.
- Xcode 16.3 or later (Swift tools 6.1).
- Swift Package Manager. Carthage is no longer supported, because PhoenixNectar is distributed as a Swift package only.

### Realtime feed

Realtime operations on `FeedManager` are processed in order, and the connection is suspended while the app is in the background and resumed when it becomes active.

- `on(eventName:completionHandler:)` now calls its handler on the main actor with a `Knock.FeedEvent` (instead of a `SwiftPhoenixClient.Message`), and returns a `Knock.FeedEventSubscription` that you can `cancel()`. Read the event payload with `event.payload` or decode it with `event.decodePayload(as:)`.
- `events(named:)` returns an `AsyncStream<Knock.FeedEvent>`. Subscriptions can be created before connecting and keep receiving events across reconnects.
- `connect(options:)` connects and waits until the feed channel is joined, throwing a `Knock.RealtimeError` if it can't be. `connectToFeed(options:)` still returns immediately.
- `disconnect()` disconnects and waits for the socket to close. `disconnectFromFeed()` still returns immediately.
- `connectionState` and `connectionStates()` expose the connection as a `Knock.FeedConnectionState`.
- Once connected, a dropped connection is retried indefinitely, and each reconnect sends the latest user token from `signIn`. Before the first successful connection, the feed gives up after about 30 seconds and moves to `.failed`. A failed connection is retried when the app becomes active or the network becomes available again; you can also call `connect()` again yourself.

#### Previously:
```swift
feedManager.connectToFeed()
feedManager.on(eventName: "new-message") { message in
    print(message.payload)
}
```

#### New in Version 2.0.0:
```swift
try await feedManager.connect()

let task = Task {
    for await event in await feedManager.events(named: "new-message") {
        print(event.payload)
    }
}

// Or, with a callback on the main actor:
let subscription = feedManager.on(eventName: "new-message") { event in
    print(event.payload)
}
subscription.cancel()
```

### Concurrency

- `Knock`, `Knock.FeedManager` and the public models are `Sendable`. Completion handlers are `@Sendable`.
- Types conforming to `ContentBlockBase` must be `Sendable`.
- `Knock.InAppFeedViewModel` is `@MainActor` and `final`. Calling `connectFeedAndObserveNewMessages()` again replaces the previous observation, and `stopObservingNewMessages()` stops it. Feed requests no longer write `before`/`after` cursors back into `feedClientOptions`. They also no longer overwrite `feedClientOptions.archived`: the archived filter still requests `archived: only`, but other filters now send the `archived` value you configured instead of clearing it.
- `KnockAppDelegate`'s `UNUserNotificationCenterDelegate` methods, `getMessageId(userInfo:)`, `pushNotificationDeliveredInForeground(notification:)` and `pushNotificationTapped(userInfo:)` are `nonisolated`, because the system doesn't guarantee they're called on the main actor. Mark your overrides `nonisolated` too.
