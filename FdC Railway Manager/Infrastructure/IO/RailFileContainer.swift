import Foundation

/// Defines the file format for .rail files (FdC Railway Manager Native Format)
/// Includes a qualifier field to qualify the format.
struct RailFileContainer: Codable {
    let formatVersion: String // e.g., "1.0"
    let qualifier: String // e.g., "FDC_RAIL_V1" - mandatory qualifier
    let network: RailwayNetworkDTO
    let metadata: RailMetadata?
}

struct RailMetadata: Codable {
    let createdBy: String?
    let createdAt: Date?
    let lastModified: Date?
    let description: String?
}
