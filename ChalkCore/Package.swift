// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ChalkCore",
    // macOS is included so the engine tests run with `swift test`, no simulator needed.
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "ChalkCore", targets: ["ChalkCore"]),
    ],
    targets: [
        .target(name: "ChalkCore"),
        .testTarget(name: "ChalkCoreTests", dependencies: ["ChalkCore"]),
    ]
)
