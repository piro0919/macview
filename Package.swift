// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Macview",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Macview", path: "Sources/Macview")
    ]
)
