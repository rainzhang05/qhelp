// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "qhelp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "QHelpCore",
            path: "Sources/QHelpCore"
        )
    ]
)
