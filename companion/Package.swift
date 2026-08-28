// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexWatchCompanion",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "codex-watch-companion", targets: ["CodexWatchCompanion"]),
    ],
    targets: [
        .executableTarget(name: "CodexWatchCompanion"),
        .testTarget(
            name: "CodexWatchCompanionTests",
            dependencies: ["CodexWatchCompanion"]
        ),
    ]
)
