// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BetterFinder",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "BetterFinder", targets: ["BetterFinder"])],
    targets: [
        .target(name: "BetterFinderCore"),
        .executableTarget(name: "BetterFinder", dependencies: ["BetterFinderCore"]),
        .testTarget(name: "BetterFinderCoreTests", dependencies: ["BetterFinderCore"])
    ]
)
