// swift-tools-version: 6.0

import PackageDescription

// Pure Swift puzzle logic (no SwiftUI). Test on Linux with `swift test` inside this folder.
let package = Package(
    name: "SudokuCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
    ],
    targets: [
        .target(name: "SudokuCore"),
        // Developer tool: builds the technique trainer's bundled practice pool.
        .executableTarget(name: "PoolGen", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
    ]
)
