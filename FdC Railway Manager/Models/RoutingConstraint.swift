import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public struct RoutingConstraint: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var routeId: String
    public var directionStationId: String? // Target station for direction (terminus or next node)
    public var allowedTracks: [String] // List of track names, e.g. ["1", "2"]
    public var transitTracks: [String]? // Prioritari per transito (senza sosta)
    public var stopTracks: [String]?    // Prioritari per sosta/partenza/arrivo
    
    enum CodingKeys: String, CodingKey {
        case id, routeId = "lineId", directionStationId, allowedTracks, transitTracks, stopTracks
    }
    
    public init(id: UUID = UUID(), routeId: String, directionStationId: String? = nil, allowedTracks: [String], transitTracks: [String]? = nil, stopTracks: [String]? = nil) {
        self.id = id
        self.routeId = routeId
        self.directionStationId = directionStationId
        self.allowedTracks = allowedTracks
        self.transitTracks = transitTracks
        self.stopTracks = stopTracks
    }
}
