// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Amadare",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .executable(name: "Amadare", targets: ["Amadare"]),
        // The iPhone app (iOS/) links this.
        .library(name: "AmadareCore", targets: ["AmadareCore"]),
    ],
    targets: [
        .target(name: "AmadareCore"),
        .executableTarget(name: "Amadare", dependencies: ["AmadareCore"]),
        .testTarget(name: "AmadareCoreTests", dependencies: ["AmadareCore"]),
    ]
)
