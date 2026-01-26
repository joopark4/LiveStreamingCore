// swift-tools-version: 5.9
// Sample iOS App demonstrating LiveStreamingCore usage

import PackageDescription

let package = Package(
    name: "LiveStreamingSampleApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LiveStreamingSampleApp",
            targets: ["LiveStreamingSampleApp"]
        )
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "LiveStreamingSampleApp",
            dependencies: ["LiveStreamingCore"],
            path: "Sources"
        ),
        .testTarget(
            name: "LiveStreamingSampleAppTests",
            dependencies: ["LiveStreamingSampleApp"],
            path: "Tests"
        )
    ]
)
