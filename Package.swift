// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "tuidotapp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "tuidotapp", targets: ["TuiDotApp"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Lakr233/libghostty-spm.git",
            exact: "1.3.2"
        ),
        .package(
            url: "https://github.com/sparkle-project/Sparkle.git",
            exact: "2.9.5"
        ),
    ],
    targets: [
        .executableTarget(
            name: "TuiDotApp",
            dependencies: [
                .product(name: "GhosttyTerminal", package: "libghostty-spm"),
                .product(name: "GhosttyTheme", package: "libghostty-spm"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TuiDotAppTests",
            dependencies: ["TuiDotApp"]
        ),
    ]
)
