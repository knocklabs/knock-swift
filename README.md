# Swift SDK

## Features

* Preferences
    * getAllUserPreferences
    * getUserPreferences
    * setUserPreferences
* Channels
* Messages
* Users

## Installation

### Swift Package Manager

There are two ways to add this as a dependency using the Swift Package Manager: 

1. Using Xcode
2. Manually via `Package.swift`

#### Using Xcode

1. Open your Xcode project and select `File` -> `Add Packages...`

<img width="511" alt="Screenshot 2023-05-17 at 9 57 26" src="https://github.com/knocklabs/knock-swift/assets/952873/d4ae690b-2b00-4af2-a2cf-1f2d9cae928d">

2. Search for `git@github.com:knocklabs/knock-swift.git` and then click `Add Package`

<img width="1207" alt="Screenshot 2023-05-17 at 9 58 08" src="https://github.com/knocklabs/knock-swift/assets/952873/420307e8-1e41-4260-9970-bb683f18c1cc">

3. Ensure that the Package is selected and click `Add Package`

<img width="1120" alt="Screenshot 2023-05-17 at 9 58 34" src="https://github.com/knocklabs/knock-swift/assets/952873/3d4c826c-8d17-4e17-b701-a3d291095319">

4. Wait for Xcode to fetch the dependencies and you should see the SDK on your Package Dependencies on the sidebar

<img width="791" alt="Screenshot 2023-05-17 at 9 59 38" src="https://github.com/knocklabs/knock-swift/assets/952873/9803dfbf-5b2f-43ab-8121-3777a461dac9">

#### Manually via `Package.swift`

If you are managing dependencies using the `Package.swift` file, just add this to you dependencies array:

``` swift
dependencies: [
    .package(url: "git@github.com:knocklabs/knock-swift.git", .upToNextMajor(from: "0.0.1"))
]
```

## Import and start using the SDK

You can now start using the SDK:

``` swift
import Knock

knockClient = try! Knock(publishableKey: "your-pk", userId: "user-id")

knockClient.updateMessageStatus(messageId: "message-id", status: .seen) { result in
    switch result {
    case .success(_):
        print("message marked as seen")
    case .failure(let error):
        print("error marking message as seen")
        print(error)
    }
}
```

## Using the SDK

The functions of the sdk are encapsulated and managed in a client object. You first have to instantiate a client with your public key and a user id. If you are running on production with enhanced security turned on (recommended) you have to also pass the signed user token to the client constructor.

``` swift
import Knock

knockClient = try! Knock(publishableKey: "your-pk", userId: "user-id")

// on prod with enhanced security turned on:
knockClient = try! Knock(publishableKey: "your-pk", userId: "user-id", userToken: "signed-user-token")
```











