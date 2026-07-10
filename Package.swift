// swift-tools-version: 5.10

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
            swiftSettings: []
        )
    ]
)
