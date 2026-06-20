// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LumoKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "LumoKit",
            targets: ["LumoKit"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/rudrankriyam/PicoDocs.git",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/rryam/VecturaKit.git",
            from: "6.0.0"
        ),
        .package(
            url: "https://github.com/rryam/VecturaEmbeddingsKit.git",
            from: "1.1.0"
        )
    ],
    targets: [
        .target(
            name: "LumoKit",
            dependencies: [
                .product(name: "PicoDocs", package: "PicoDocs"),
                .product(name: "VecturaKit", package: "VecturaKit"),
                .product(name: "VecturaEmbeddingsKit", package: "VecturaEmbeddingsKit")
            ]),
        .testTarget(
            name: "LumoKitTests",
            dependencies: ["LumoKit"]
        )
    ]
)
