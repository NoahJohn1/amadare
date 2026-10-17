// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Recall",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Recall", targets: ["Recall"])],
    targets: [
        .target(name: "RecallCore"),
        .executableTarget(name: "Recall", dependencies: ["RecallCore"]),
        .testTarget(name: "RecallCoreTests", dependencies: ["RecallCore"]),
    ]
)
