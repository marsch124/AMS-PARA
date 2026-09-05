// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AMSPara",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AMSParaCore", targets: ["AMSParaCore"]),
    ],
    targets: [
        .target(
            name: "AMSParaCore",
            path: "Sources/AMSParaCore"
        ),
        .testTarget(
            name: "AMSParaCoreTests",
            dependencies: ["AMSParaCore"],
            path: "Tests/AMSParaCoreTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
