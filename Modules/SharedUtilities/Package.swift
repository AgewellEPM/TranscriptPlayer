// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedUtilities",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "SharedUtilities",
            targets: ["SharedUtilities"]
        )
    ],
    targets: [
        .target(
            name: "SharedUtilities",
            path: "Sources"
        )
    ]
)
