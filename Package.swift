// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Amadare",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "Amadare", targets: ["Amadare"])],
    targets: [
        .target(name: "AmadareCore"),
        .executableTarget(name: "Amadare", dependencies: ["AmadareCore"]),
        .testTarget(name: "AmadareCoreTests", dependencies: ["AmadareCore"]),
    ]
)
