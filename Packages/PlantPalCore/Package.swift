// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlantPalCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PlantPalCore", targets: ["PlantPalCore"]),
    ],
    targets: [
        .target(name: "PlantPalCore"),
        .testTarget(name: "PlantPalCoreTests", dependencies: ["PlantPalCore"]),
    ]
)
