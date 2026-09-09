// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Knock",
    platforms:  [
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Knock",
            targets: ["Knock"]),
    ],
    dependencies: [
        // Pinned to the knocklabs fork for the URLSession teardown-race fix (upstream
        // davidstump/SwiftPhoenixClient#289 and #295). Once that fix ships upstream, replace
        // with: .package(url: "https://github.com/davidstump/SwiftPhoenixClient.git", from: "5.3.6")
        //
        // Pinned by version, not revision: SwiftPM refuses to resolve a version-pinned package
        // whose own dependencies are revision-pinned, so a `revision:` here would break every
        // app that depends on a tagged knock-swift release.
        .package(
            url: "https://github.com/knocklabs/SwiftPhoenixClient.git",
            from: "5.3.6-knock.1"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Knock",
            dependencies: ["SwiftPhoenixClient"],
            path: "Sources",
            resources: [
                .process("Resources/Colors.xcassets"),
                .process("Resources/Media.xcassets")
            ]),
        
        .testTarget(
            name: "KnockTests",
            dependencies: ["Knock", "SwiftPhoenixClient"]),
    ]
)
