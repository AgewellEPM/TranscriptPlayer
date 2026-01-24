// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TranscriptPlayer",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "TranscriptPlayer",
            targets: ["TranscriptPlayer"]
        )
    ],
    dependencies: [
        .package(path: "Modules/SharedUtilities"),
        .package(path: "Modules/VideoPlayerModule"),
        .package(path: "Modules/TranscriptModule")
    ],
    targets: [
        .executableTarget(
            name: "TranscriptPlayer",
            dependencies: [
                "SharedUtilities",
                "VideoPlayerModule",
                "TranscriptModule"
            ],
            path: "TranscriptPlayer/Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
