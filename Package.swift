// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipAI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "clip", targets: ["clip"])
    ],
    targets: [
        .target(
            name: "ClipAICore",
            path: "Sources/ClipAICore",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug)),
                .unsafeFlags(["-enable-testing"], .when(configuration: .release))
            ]
        ),
        .executableTarget(
            name: "clip",
            dependencies: ["ClipAICore"],
            path: "Sources/clip"
        ),
        .executableTarget(
            name: "ClipAITests",
            dependencies: ["ClipAICore"],
            path: "Tests",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"], .when(configuration: .debug)),
                .unsafeFlags(["-parse-as-library"], .when(configuration: .release))
            ]
        )
    ]
)
