// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AKPlayer",
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
            path: "Sources/AKPlayer"
        ),
        .testTarget(
            name: "AKPlayerTests",
            dependencies: ["AKPlayer"],
            path: "Tests/AKPlayerTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
