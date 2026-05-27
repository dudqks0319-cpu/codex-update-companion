// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexUpdateCompanion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexUpdateCompanion", targets: ["CodexUpdateCompanion"])
    ],
    targets: [
        .target(
            name: "CodexUpdateCompanionCore",
            path: "Sources/CodexUpdateCompanionCore"
        ),
        .executableTarget(
            name: "CodexUpdateCompanion",
            dependencies: ["CodexUpdateCompanionCore"],
            path: "Sources/CodexUpdateCompanion"
        ),
        .testTarget(
            name: "CodexUpdateCompanionTests",
            dependencies: ["CodexUpdateCompanionCore"],
            path: "Tests/CodexUpdateCompanionTests"
        )
    ]
)
