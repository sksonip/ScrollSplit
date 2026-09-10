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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "ScrollSplit",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ScrollSplit",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "ScrollSplitTests",
            dependencies: ["ScrollSplit"],
            path: "Tests/ScrollSplitTests"
        )
    ]
)
