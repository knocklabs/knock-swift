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
