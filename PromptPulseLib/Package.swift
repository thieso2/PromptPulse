// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PromptWatch",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PromptWatchKit",
            targets: ["PromptWatchKit"]
        ),
        .executable(
            name: "promptwatch",
            targets: ["PromptWatchCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        // Domain Layer - Pure business logic, no dependencies
        .target(
            name: "PromptWatchDomain",
            dependencies: []
        ),

        // Platform Layer - Darwin syscalls
        .target(
            name: "PromptWatchPlatform",
            dependencies: ["PromptWatchDomain"]
        ),

        // Data Layer - Parsers, discovery, repositories
        .target(
            name: "PromptWatchData",
            dependencies: [
                "PromptWatchDomain",
                "PromptWatchPlatform",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),

        // Kit Layer - Public API facade
        .target(
            name: "PromptWatchKit",
            dependencies: [
                "PromptWatchDomain",
                "PromptWatchPlatform",
                "PromptWatchData",
            ]
        ),

        // CLI Executable
        .executableTarget(
            name: "PromptWatchCLI",
            dependencies: [
                "PromptWatchKit",
                "PromptWatchDomain",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // Tests
        .testTarget(
            name: "PromptWatchDomainTests",
            dependencies: [
                "PromptWatchDomain",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "PromptWatchPlatformTests",
            dependencies: [
                "PromptWatchPlatform",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "PromptWatchDataTests",
            dependencies: [
                "PromptWatchData",
                .product(name: "Testing", package: "swift-testing"),
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "PromptWatchKitTests",
            dependencies: [
                "PromptWatchKit",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
