// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HP12C",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HP12CCore", targets: ["HP12CCore"]),
        .executable(name: "HP12C", targets: ["HP12C"])
    ],
    targets: [
        .target(
            name: "HP12CCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "HP12C",
            dependencies: ["HP12CCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HP12CCoreTests",
            dependencies: ["HP12CCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
