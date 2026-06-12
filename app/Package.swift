// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LTXStudioLocal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LTXStudioLocal",
            targets: ["LTXStudioLocal"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LTXStudioLocal",
            dependencies: [],
            path: "LTXStudioLocal",
            exclude: ["App/LTXStudioLocalApp.swift"]),
        .testTarget(
            name: "LTXStudioLocalTests",
            dependencies: ["LTXStudioLocal"],
            path: "LTXStudioLocalTests"),
    ]
)
