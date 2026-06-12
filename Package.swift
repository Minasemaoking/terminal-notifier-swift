// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "warp-notify",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "warp-notify", targets: ["WarpNotify"])
    ],
    targets: [
        .executableTarget(name: "WarpNotify"),
        .testTarget(name: "WarpNotifyTests", dependencies: ["WarpNotify"]),
    ]
)
