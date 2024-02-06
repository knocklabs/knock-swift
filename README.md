
# Offical Knock iOS SDK

---

Knock is a flexible, reliable notifications infrastructure that's built to scale with you. Use our iOS SDK to engage users with in-app feeds, setup push notifications, and manage notification preferences.

---

## Documentation

See the [documentation](https://docs.knock.app/notification-feeds/bring-your-own-ui) for usage examples.

## Installation
You can include the SDK in a couple of ways:

1. Swift Package Manager
2. Carthage
3. Cocoapods
4. Manually

### Swift Package Manager

There are two ways to add this as a dependency using the Swift Package Manager: 

1. Using Xcode
2. Manually via `Package.swift`

#### Using Xcode

1. Open your Xcode project and select `File` -> `Add Packages...`

<img width="422" alt="Screenshot 2023-06-27 at 19 41 32" src="https://github.com/knocklabs/knock-swift/assets/952873/31bb67de-5272-445a-a5c4-5df3bcfa3c8b">

2. Search for `https://github.com/knocklabs/knock-swift.git` and then click `Add Package`

<img width="900" alt="Screenshot 2023-06-27 at 19 42 09" src="https://github.com/knocklabs/knock-swift/assets/952873/d947cc7f-8da6-4814-aa75-3e41ffe72ff4">

3. Ensure that the Package is selected and click `Add Package`

<img width="900" alt="Screenshot 2023-06-27 at 19 42 23" src="https://github.com/knocklabs/knock-swift/assets/952873/c6053b06-73dc-43c8-8a68-40fbc2298f7c">

4. Wait for Xcode to fetch the dependencies and you should see the SDK on your Package Dependencies on the sidebar

<img width="505" alt="Screenshot 2023-06-27 at 19 42 45" src="https://github.com/knocklabs/knock-swift/assets/952873/9f314c9d-2525-4357-8da0-6ce4508b6db0">

#### Manually via `Package.swift`

If you are managing dependencies using the `Package.swift` file, just add this to you dependencies array:

``` swift
dependencies: [
    .package(url: "https://github.com/knocklabs/knock-swift.git", .upToNextMajor(from: "0.2.0"))
]
```

### Cocoapods

Add the dependency to your `Podfile`:

```
platform :ios, '16.0'
use_frameworks!

target 'MyApp' do
  pod 'Knock', '~> 0.2.0'
end
```

### Carthage

1. Add this line to your Cartfile:

```
github "knocklabs/knock-swift" ~> 0.2.0
```

2. Run `carthage update`. This will fetch dependencies into a Carthage/Checkouts folder, then build each one or download a pre-compiled framework.
3. Open your application targets’ General settings tab. For Xcode 11.0 and higher, in the "Frameworks, Libraries, and Embedded Content" section, drag and drop each framework you want to use from the Carthage/Build folder on disk. Then, in the "Embed" section, select "Do Not Embed" from the pulldown menu for each item added. For Xcode 10.x and lower, in the "Linked Frameworks and Libraries" section, drag and drop each framework you want to use from the Carthage/Build folder on disk.
4. On your application targets’ Build Phases settings tab, click the + icon and choose New Run Script Phase. Create a Run Script in which you specify your shell (ex: /bin/sh), add the following contents to the script area below the shell:
```
/usr/local/bin/carthage copy-frameworks
```
5. Create a file named `input.xcfilelist` and a file named output.xcfilelist
6. Add the paths to the frameworks you want to use to your input.xcfilelist. For example:
```
$(SRCROOT)/Carthage/Build/iOS/Knock.framework
```
7. Add the paths to the copied frameworks to the `output.xcfilelist`. For example:
```
$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/Result.framework
```
8. Add the `input.xcfilelist` to the "Input File Lists" section of the Carthage run script phase
9. Add the `output.xcfilelist` to the "Output File Lists" section of the Carthage run script phase

This script works around an [App Store submission bug](http://www.openradar.me/radar?id=6409498411401216) triggered by universal binaries and ensures that necessary bitcode-related files and dSYMs are copied when archiving.

With the debug information copied into the built products directory, Xcode will be able to symbolicate the stack trace whenever you stop at a breakpoint. This will also enable you to step through third-party code in the debugger.

When archiving your application for submission to the App Store or TestFlight, Xcode will also copy these files into the dSYMs subdirectory of your application’s .xcarchive bundle.

### Manually

As a last option, you could manually copy the files inside the `Sources` folder to your project.

## Import and start using the SDK

You can now start using the SDK:

``` swift
import Knock

// Setup the shared Knock instance as soon as you can. 
try? Knock.shared.setup(publishableKey: "your-pk", pushChannelId: "user-id")

// Once you know the Knock UserId, sign the user into the shared Knock instance.
await Knock.shared.signIn(userId: "userid", userToken: nil)

```

## How to Contribute

Community contributions are welcome! If you'd like to contribute, please read our [contribution guide](CONTRIBUTING.md).

## License

This project is licensed under the MIT license.

See [LICENSE](LICENSE) for more information.
