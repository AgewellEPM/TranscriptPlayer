// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TranscriptModule",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "TranscriptModule",
            targets: ["TranscriptModule"]
        )
    ],
    dependencies: [
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "TranscriptModule",
            dependencies: ["SharedUtilities"],
            path: "Sources"
        )
    ]
)
