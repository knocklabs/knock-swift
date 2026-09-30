// swift-tools-version: 6.1
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
        // PhoenixNectar is pre-1.0, so pin to the minor version to avoid picking up breaking changes.
        .package(url: "https://github.com/jvdvleuten/PhoenixNectar.git", .upToNextMinor(from: "0.1.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Knock",
            dependencies: [
                .product(name: "PhoenixNectar", package: "PhoenixNectar")
            ],
            path: "Sources",
            resources: [
                .process("Resources/Colors.xcassets"),
                .process("Resources/Media.xcassets")
            ]),
        
        .testTarget(
            name: "KnockTests",
            dependencies: ["Knock"]),
    ],
    swiftLanguageModes: [.v6]
)
