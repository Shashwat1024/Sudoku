// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sudoku",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "Sudoku",
            targets: ["Sudoku"]
        ),
    ],
    dependencies: [
        .package(path: "Core"),
    ],
    targets: [
        .target(
            name: "Sudoku",
            dependencies: [
                .product(name: "SudokuCore", package: "Core"),
            ]
        ),
    ]
)
