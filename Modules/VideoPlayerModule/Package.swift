// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoPlayerModule",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "VideoPlayerModule",
            targets: ["VideoPlayerModule"]
        )
    ],
    dependencies: [
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "VideoPlayerModule",
            dependencies: ["SharedUtilities"],
            path: "Sources"
        )
    ]
)
