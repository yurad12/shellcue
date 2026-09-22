// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ShellCue",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ShellCue", targets: ["ShellCueApp"]),
        .library(name: "ShellCueCore", targets: ["ShellCueCore"])
    ],
    targets: [
        .target(name: "ShellCueCore"),
        .executableTarget(
            name: "ShellCueApp",
            dependencies: ["ShellCueCore"]
        ),
        .testTarget(
            name: "ShellCueCoreTests",
            dependencies: ["ShellCueCore"]
        )
    ]
)

