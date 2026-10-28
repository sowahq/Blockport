// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Blockport",
    platforms: [.macOS(.v15), .macCatalyst(.v18)],
    products: [
        .library(name: "BlockportRuntime", type: .dynamic, targets: ["BlockportRuntime", "BlockportInterpose"]),
    ],
    targets: [
        .target(name: "CLegacyKeychain"),
        .target(name: "CMacDisplay"),
        .target(name: "BlockportNative"),
        .target(name: "BlockportShared"),
        .target(name: "BlockportCore", dependencies: ["BlockportShared"]),
        .target(
            name: "BlockportRuntime",
            dependencies: ["BlockportShared", "BlockportNative", "CLegacyKeychain", "CMacDisplay"],
            linkerSettings: [.linkedFramework("Security")]
        ),
        .target(name: "BlockportInterpose", dependencies: ["BlockportRuntime"]),
        .executableTarget(name: "blockport", dependencies: ["BlockportCore", "BlockportShared"]),
        .executableTarget(name: "BlockportLauncher", dependencies: ["BlockportCore", "BlockportShared"]),
        .testTarget(name: "BlockportCoreTests", dependencies: ["BlockportCore"]),
        .testTarget(
            name: "BlockportRuntimeTests",
            dependencies: ["BlockportRuntime", "BlockportShared"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
