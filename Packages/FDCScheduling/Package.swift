// swift-tools-version: 5.9
import PackageDescription

/// Scheduling pipeline extracted from `FdC Railway Manager/Services/Scheduling/`.
/// App-specific adapters (ConflictManager, GA, AI) conform to FDCDomain protocols.
let package = Package(
    name: "FDCScheduling",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FDCScheduling", targets: ["FDCScheduling"]),
    ],
    dependencies: [
        .package(path: "../FDCDomain"),
    ],
    targets: [
        .target(
            name: "FDCScheduling",
            dependencies: ["FDCDomain"],
            path: "Sources/FDCScheduling"
        ),
        .testTarget(
            name: "FDCSchedulingTests",
            dependencies: ["FDCScheduling", "FDCDomain"],
            path: "Tests/FDCSchedulingTests"
        ),
    ]
)
