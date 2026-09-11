// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Paragon",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ParagonCore", targets: ["ParagonCore"]),
    ],
    targets: [
        .target(
            name: "ParagonCore",
            path: "Sources/ParagonCore"
        ),
        .testTarget(
            name: "ParagonCoreTests",
            dependencies: ["ParagonCore"],
            path: "Tests/ParagonCoreTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
