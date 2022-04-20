// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "TimeIntervalFormatter",
    products: [
        .library(
            name: "TimeIntervalFormatter",
            targets: ["TimeIntervalFormatter"]),
    ],
    targets: [
        .target(
            name: "TimeIntervalFormatter",
            dependencies: []),
        .testTarget(
            name: "TimeIntervalFormatterTests",
            dependencies: ["TimeIntervalFormatter"]),
    ]
)
