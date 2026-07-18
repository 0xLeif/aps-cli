// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "aps",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "aps",
            targets: ["aps"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/0xLeif/AppState", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "aps",
            dependencies: [
                .product(name: "AppState", package: "AppState"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "apsTests",
            dependencies: ["aps"]
        )
    ],
    swiftLanguageModes: [.v6]
)
