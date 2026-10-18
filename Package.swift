// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-pr-coverage",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "swift-pr-coverage", targets: ["swift-pr-coverage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "swift-pr-coverage",
            dependencies: [
                "PRCoverageCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(name: "PRCoverageCore"),
        .testTarget(
            name: "PRCoverageCoreTests",
            dependencies: ["PRCoverageCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
