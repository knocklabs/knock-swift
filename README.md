
# Official Knock iOS SDK

[![GitHub Release](https://img.shields.io/github/v/release/knocklabs/knock-swift?style=flat)](https://github.com/knocklabs/knock-swift/releases/latest)
[![CocoaPods](https://img.shields.io/cocoapods/v/Knock.svg?style=flat)](https://cocoapods.org/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)

![min swift version is 5.3](https://img.shields.io/badge/min%20Swift%20version-5.3-orange)
![min ios version is 16](https://img.shields.io/badge/min%20iOS%20version-16-blue)
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat)](https://github.com/knocklabs/ios-example-app/blob/main/LICENSE)



---

Knock is a flexible, reliable notifications infrastructure that's built to scale with you. Use our iOS SDK to engage users with in-app feeds, setup push notifications, and manage notification preferences.

---

## Documentation

See the [documentation](https://docs.knock.app/sdks/ios/overview) for full documentation.

## Migrations

See the [Migration Guide](https://github.com/knocklabs/knock-swift/blob/main/MIGRATIONS.md) if upgrading from a previous version.

## Example App

See the [iOS Example App](https://github.com/knocklabs/ios-example-app) for more examples.

## Installation

### Swift Package Manager

There are two ways to add this as a dependency using the Swift Package Manager: 

1. Using Xcode
2. Manually via `Package.swift`

#### Using Xcode

1. Open your Xcode project and select `File` -> `Add Packages...`

<img width="422" alt="Screenshot 2023-06-27 at 19 41 32" src="https://github.com/knocklabs/knock-swift/assets/952873/31bb67de-5272-445a-a5c4-5df3bcfa3c8b">

2. Search for `https://github.com/knocklabs/knock-swift.git` and then click `Add Package`
*Note: We recommend that you set the Dependency Rule to Up to Next Major Version. While we encourage you to keep your app up to date with the latest SDK, major versions can include breaking changes or new features that require your attention.*

<img width="900" alt="Screenshot 2023-06-27 at 19 42 09" src="https://github.com/knocklabs/knock-swift/assets/952873/d947cc7f-8da6-4814-aa75-3e41ffe72ff4">

#### Manually via `Package.swift`

If you are managing dependencies using the `Package.swift` file, just add this to you dependencies array:

``` swift
dependencies: [
    .package(url: "https://github.com/knocklabs/knock-swift.git", .upToNextMajor(from: "1.2.6"))
]
```

### Cocoapods

Add the dependency to your `Podfile`:

```
platform :ios, '16.0'
use_frameworks!

target 'MyApp' do
  pod 'Knock', '~> 1.2.6'
end
```

### Carthage

1. Add this line to your Cartfile:

```
github "knocklabs/knock-swift" ~> 1.1.0
```

### Manually

As a last option, you could manually copy the files inside the `Sources` folder to your project.

## Import and start using the SDK

You can now start using the SDK:

``` swift
import Knock

/* 
 Setup the shared Knock instance as soon as you can. 
 Note: pushChannelId is required if you want to use our KnockAppDelegate helper. 
 Otherwise, this field is optional.
*/
try? Knock.shared.setup(publishableKey: "your-pk", pushChannelId: "apns-push-channel-id")

// Once you know the Knock UserId, sign the user into the shared Knock instance.
await Knock.shared.signIn(userId: "userid", userToken: nil)

```

## How to Contribute

Community contributions are welcome! If you'd like to contribute, please read our [contribution guide](CONTRIBUTING.md).

## License

This project is licensed under the MIT license.

See [LICENSE](LICENSE) for more information.
