// swift-tools-version: 5.9
import PackageDescription

/// Scheduling services scaffold. Not yet linked to the Xcode target:
/// depends on ConflictManager, GeneticOptimizer, RailwayAIService, FDCSchedulerEngine.
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
    ]
)
