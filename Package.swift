// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectivityAndInternetAccess",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "ConnectivityAndInternetAccess",
            targets: ["ConnectivityAndInternetAccess"]
        ),
    ],
    targets: [
        .target(
            name: "ConnectivityAndInternetAccess",
            dependencies: [],
            path: "Sources/ConnectivityAndInternetAccess"
        ),
        .testTarget(
            name: "ConnectivityAndInternetAccessTests",
            dependencies: ["ConnectivityAndInternetAccess"],
            path: "Tests/ConnectivityAndInternetAccessTests"
        ),
    ]
)
