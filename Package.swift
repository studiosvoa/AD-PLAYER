// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ADPlayer",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "ADPlayer",
            path: "Sources/ADPlayer"
        )
    ]
)
