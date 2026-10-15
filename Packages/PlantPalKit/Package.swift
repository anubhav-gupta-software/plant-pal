// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlantPalKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "PlantPalKit", targets: ["PlantPalKit"]),
    ],
    dependencies: [
        .package(path: "../PlantPalCore"),
    ],
    targets: [
        .target(
            name: "PlantPalKit",
            dependencies: ["PlantPalCore"]
        ),
    ]
)
