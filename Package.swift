// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScrollSplit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ScrollSplit", targets: ["ScrollSplit"])
    ],
    targets: [
        .executableTarget(
            name: "ScrollSplit",
            path: "Sources/ScrollSplit"
        ),
        .testTarget(
            name: "ScrollSplitTests",
            dependencies: ["ScrollSplit"],
            path: "Tests/ScrollSplitTests"
        )
    ]
)
