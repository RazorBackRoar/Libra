// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Libra",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "Libra",
            targets: ["Libra"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Libra",
            path: "Sources/Libra",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LibraTests",
            dependencies: ["Libra"],
            path: "Tests/LibraTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
