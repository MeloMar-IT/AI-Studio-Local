// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LTXStudioLocal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LTXStudioLocal",
            targets: ["LTXStudioLocal"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LTXStudioLocal",
            dependencies: [],
            path: "LTXStudioLocal"),
        .testTarget(
            name: "LTXStudioLocalTests",
            dependencies: ["LTXStudioLocal"],
            path: "LTXStudioLocalTests"),
    ]
)
