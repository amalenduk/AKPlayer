// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AKPlayer",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "AKPlayer",
            targets: ["AKPlayer"]
        )
    ],
    targets: [
        .target(
            name: "AKPlayer",
            dependencies: [],
            path: "Sources/AKPlayer",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AKPlayerTests",
            dependencies: ["AKPlayer"],
            path: "Tests/AKPlayerTests"
        )
    ],
    swiftLanguageModes: [.v6]
)

