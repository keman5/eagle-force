// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EagleCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EagleCore", targets: ["EagleCore"])],
    targets: [
        .target(name: "EagleCore", path: "Sources/Core"),
        .testTarget(name: "EagleCoreTests", dependencies: ["EagleCore"], path: "Tests/Core")
    ]
)
