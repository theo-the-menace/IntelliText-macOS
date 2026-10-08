// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IntelliTextMacOS",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "IntelliTextCore", targets: ["IntelliTextCore"]),
        .executable(name: "IntelliTextInputMethod", targets: ["IntelliTextInputMethod"])
    ],
    targets: [
        .target(name: "IntelliTextCore"),
        .executableTarget(name: "IntelliTextInputMethod", dependencies: ["IntelliTextCore"]),
        .testTarget(name: "IntelliTextCoreTests", dependencies: ["IntelliTextCore"])
    ]
)
