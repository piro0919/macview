// swift-tools-version:6.0
import PackageDescription

// Sparkle is linked from Vendor/, which scripts/build.sh fetches. The path is relative to the
// working directory, so the build has to be started from the package root - which the script does.
let package = Package(
    name: "Macview",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Macview",
            path: "Sources/Macview",
            swiftSettings: [.unsafeFlags(["-F", "Vendor"]), .swiftLanguageMode(.v6)],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "Vendor",
                    "-framework", "Sparkle",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                ])
            ]
        )
    ]
)
