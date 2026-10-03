// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Intent",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Intent", targets: ["Intent"])],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.0")
    ],
    targets: [
        .executableTarget(name: "Intent", dependencies: [
            .product(name: "WhisperKit", package: "argmax-oss-swift")
        ]),
        .testTarget(name: "IntentTests", dependencies: ["Intent"])
    ]
)
