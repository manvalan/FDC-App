import Foundation

public struct RoutingConstraint: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var routeId: String
    public var directionStationId: String?
    public var allowedTracks: [String]
    public var transitTracks: [String]?
    public var stopTracks: [String]?

    enum CodingKeys: String, CodingKey {
        case id, routeId = "lineId", directionStationId, allowedTracks, transitTracks, stopTracks
    }

    public init(
        id: UUID = UUID(), routeId: String, directionStationId: String? = nil,
        allowedTracks: [String], transitTracks: [String]? = nil, stopTracks: [String]? = nil
    ) {
        self.id = id
        self.routeId = routeId
        self.directionStationId = directionStationId
        self.allowedTracks = allowedTracks
        self.transitTracks = transitTracks
        self.stopTracks = stopTracks
    }
}
