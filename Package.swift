// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PerfLens",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "PerfLens", targets: ["PerfLens"])
    ],
    targets: [
        .target(
            name: "PerfLensBootstrap",
            path: "Sources/PerfLensBootstrap",
            publicHeadersPath: "include"
        ),
        .target(
            name: "PerfLens",
            dependencies: ["PerfLensBootstrap"],
            path: "Sources/PerfLens"
        ),
        .testTarget(
            name: "PerfLensTests",
            dependencies: ["PerfLens"],
            path: "Tests/PerfLensTests"
        )
    ]
)
