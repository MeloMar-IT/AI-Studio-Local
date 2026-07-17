// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIStudioLocal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AIStudioLocal",
            targets: ["AIStudioLocal"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIStudioLocal",
            dependencies: [],
            path: "AIStudioLocal",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "AIStudioLocalTests",
            dependencies: ["AIStudioLocal"],
            path: "AIStudioLocalTests"),
    ]
)
