// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LyricCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "LyricCore", targets: ["LyricCore"]),
    ],
    targets: [
        .target(name: "LyricCore"),
        .testTarget(name: "LyricCoreTests", dependencies: ["LyricCore"]),
    ]
)
