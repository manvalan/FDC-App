// swift-tools-version: 5.9
import PackageDescription

/// Foundation-only railway domain models extracted from `FdC Railway Manager/Domain/Model/`.
/// SwiftUI-dependent types (TrainRoute, Ferrovia, TrainDatabaseModels) remain in the app target.
let package = Package(
    name: "FDCDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FDCDomain", targets: ["FDCDomain"]),
    ],
    targets: [
        .target(
            name: "FDCDomain",
            path: "Sources/FDCDomain"
        ),
        .testTarget(
            name: "FDCDomainTests",
            dependencies: ["FDCDomain"],
            path: "Tests/FDCDomainTests"
        ),
    ]
)
