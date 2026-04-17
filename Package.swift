// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnipKey",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SnipKeyCore",
            path: "Sources/SnipKeyCore"
        ),
        .executableTarget(
            name: "SnipKeyApp",
            dependencies: ["SnipKeyCore"],
            path: "Sources/SnipKeyApp",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "SnipKeyCoreTests",
            dependencies: ["SnipKeyCore"],
            path: "Tests/SnipKeyCoreTests"
        ),
    ]
)
