// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "droidy",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "Droidy", targets: ["Droidy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwifDroid/manifest.git", from: "0.0.1"),
    ],
    targets: [
        .target(name: "Droidy", dependencies: [
            .product(name: "Manifest", package: "manifest")
        ]),
        .testTarget(name: "DroidyTests", dependencies: ["Droidy"]),
    ]
)
