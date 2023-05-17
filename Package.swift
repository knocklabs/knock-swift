// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Knock",
    platforms:  [
        .iOS(.v16),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Knock",
            targets: ["Knock"]),
    ],
    dependencies: [
        .package(url: "https://github.com/davidstump/SwiftPhoenixClient.git", .upToNextMajor(from: "5.3.0")),
        .package(
            url: "https://github.com/Flight-School/AnyCodable",
            from: "0.6.0"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Knock", dependencies: ["SwiftPhoenixClient", "AnyCodable"]),
    ]
)
