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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        // Cap swift-asn1 below 1.7: 1.7+ requires Swift tools 6.1, and the 6.1/6.2
        // Linux toolchains ship an Observation linker bug (swift::threading::fatal).
        .package(url: "https://github.com/apple/swift-asn1", "1.1.0"..<"1.7.0")
    ],
    targets: [
        .executableTarget(
            name: "aps",
            dependencies: [
                .product(name: "AppState", package: "AppState"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),
        .testTarget(
            name: "apsTests",
            dependencies: ["aps"]
        )
    ],
    swiftLanguageModes: [.v6]
)
