// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IntelliTextMacOS",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "IntelliTextCore", targets: ["IntelliTextCore"])
    ],
    targets: [
        .target(name: "IntelliTextCore"),
        .testTarget(name: "IntelliTextCoreTests", dependencies: ["IntelliTextCore"])
    ]
)
