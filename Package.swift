// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ankani",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "Ankani", targets: ["Ankani"])],
    targets: [
        .target(name: "AnkaniCore"),
        .executableTarget(name: "Ankani", dependencies: ["AnkaniCore"]),
        .testTarget(name: "AnkaniCoreTests", dependencies: ["AnkaniCore"]),
    ]
)
