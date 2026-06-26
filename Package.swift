// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CloakShot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CloakShot", targets: ["CloakShot"]),
        .executable(name: "cloakshot-mcp", targets: ["CloakShotMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "CloakShot",
            dependencies: ["ScreenShield", "FileShield", "TextRedactor", "Shared"],
            path: "Sources/CloakShot"
        ),
        .executableTarget(
            name: "CloakShotMCP",
            dependencies: ["ScreenShield", "FileShield", "TextRedactor", "Shared"],
            path: "Sources/CloakShotMCP"
        ),
        .target(
            name: "ScreenShield",
            dependencies: ["Shared"],
            path: "Sources/ScreenShield"
        ),
        .target(
            name: "FileShield",
            dependencies: ["Shared"],
            path: "Sources/FileShield"
        ),
        .target(
            name: "TextRedactor",
            dependencies: ["Shared"],
            path: "Sources/TextRedactor"
        ),
        .target(
            name: "Shared",
            dependencies: ["Yams"],
            path: "Sources/Shared",
            resources: [.copy("../../Resources/AppRules")]
        ),
        .testTarget(name: "ScreenShieldTests", dependencies: ["ScreenShield"], path: "Tests/ScreenShieldTests"),
        .testTarget(name: "FileShieldTests", dependencies: ["FileShield"], path: "Tests/FileShieldTests"),
        .testTarget(name: "TextRedactorTests", dependencies: ["TextRedactor"], path: "Tests/TextRedactorTests"),
    ]
)
