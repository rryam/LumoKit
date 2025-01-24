// swift-tools-version: 6.0
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
            targets: ["LumoKit"]),
    ],
    dependencies: [
        // Changed from branch to exact commit
        .package(
            url: "https://github.com/rudrankriyam/PicoDocs.git",
            revision: "HEAD"
        ),
        // Changed from branch to exact commit
        .package(
            url: "https://github.com/rryam/VecturaKit.git",
            revision: "HEAD"
        ),
    ],
    targets: [
        .target(
            name: "LumoKit",
            dependencies: [
                .product(name: "PicoDocs", package: "PicoDocs"),
                .product(name: "VecturaKit", package: "VecturaKit")
            ]),
        .testTarget(
            name: "LumoKitTests",
            dependencies: ["LumoKit"]
        ),
    ]
)
