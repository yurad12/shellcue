// swift-tools-version: 6.1

import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .path

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
            dependencies: ["ShellCueCore"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "\(packageDirectory)/Config/ShellCue-Info.plist"
                ])
            ]
        )
    ]
)
