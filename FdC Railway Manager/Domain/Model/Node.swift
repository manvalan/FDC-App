import Foundation
import CoreLocation

public struct Node: Identifiable, Codable, Hashable {
    public enum NodeType: String, Codable {
        case station, interchange, depot, junction
    }
    public enum StationVisualType: String, Codable, CaseIterable, Identifiable {
        case filledStar = "Stella piena"
        case filledSquare = "Quadrato pieno"
        case emptySquare = "Quadrato vuoto"
        case filledCircle = "Cerchio pieno"
        case emptyCircle = "Cerchio vuoto"

        public var id: String { self.rawValue }

        public var localizedName: String {
            switch self {
            case .filledStar: return "filled_star".localized
            case .filledSquare: return "filled_square".localized
            case .emptySquare: return "empty_square".localized
            case .filledCircle: return "filled_circle".localized
            case .emptyCircle: return "empty_circle".localized
            }
        }
    }

    public enum HubOffsetDirection: String, Codable, CaseIterable, Identifiable {
        case topLeft = "In Alto a Sx"
        case topRight = "In Alto a Dx"
        case bottomLeft = "In Basso a Sx"
        case bottomRight = "In Basso a Dx"

        public var id: String { self.rawValue }

        public var localizedName: String {
            switch self {
            case .topLeft: return "top_left_offset".localized
            case .topRight: return "top_right_offset".localized
            case .bottomLeft: return "bottom_left_offset".localized
            case .bottomRight: return "bottom_right_offset".localized
            }
        }
    }

    public let id: String
    public var name: String
    public var type: NodeType
    public var visualType: StationVisualType?
    public var customColor: String?
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    public var capacity: Int?
    public var platforms: Int?
    public var parentHubId: String?
    public var hubOffsetDirection: HubOffsetDirection?
    public var routingConstraints: [RoutingConstraint] = []
    public var electrification: ElectrificationType = .dc3kv
    public var taktMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, type, visualType, customColor, latitude, longitude, altitude, capacity, platforms, electrification
        case platformCount = "platform_count"
        case parentHubId, hubOffsetDirection, routingConstraints, taktMinutes
    }

    public init(
        id: String, name: String, type: NodeType = .station,
        visualType: StationVisualType? = nil, customColor: String? = nil,
        latitude: Double? = nil, longitude: Double? = nil, altitude: Double? = nil,
        capacity: Int? = nil, platforms: Int? = 2, parentHubId: String? = nil,
        hubOffsetDirection: HubOffsetDirection? = nil,
        electrification: ElectrificationType = .dc3kv, taktMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.visualType = visualType
        self.customColor = customColor
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.capacity = capacity
        self.platforms = platforms
        self.parentHubId = parentHubId
        self.hubOffsetDirection = hubOffsetDirection
        self.routingConstraints = []
        self.electrification = electrification
        self.taktMinutes = taktMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        type = try container.decodeIfPresent(NodeType.self, forKey: .type) ?? .station
        visualType = try container.decodeIfPresent(StationVisualType.self, forKey: .visualType)
        customColor = try container.decodeIfPresent(String.self, forKey: .customColor)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        platforms = try container.decodeIfPresent(Int.self, forKey: .platforms)
            ?? container.decodeIfPresent(Int.self, forKey: .platformCount) ?? 2
        parentHubId = try container.decodeIfPresent(String.self, forKey: .parentHubId)
        hubOffsetDirection = try container.decodeIfPresent(HubOffsetDirection.self, forKey: .hubOffsetDirection)
        routingConstraints = try container.decodeIfPresent([RoutingConstraint].self, forKey: .routingConstraints) ?? []
        electrification = try container.decodeIfPresent(ElectrificationType.self, forKey: .electrification) ?? .dc3kv
        taktMinutes = try container.decodeIfPresent(Int.self, forKey: .taktMinutes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(visualType, forKey: .visualType)
        try container.encodeIfPresent(customColor, forKey: .customColor)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(altitude, forKey: .altitude)
        try container.encodeIfPresent(capacity, forKey: .capacity)
        try container.encodeIfPresent(platforms, forKey: .platforms)
        try container.encodeIfPresent(parentHubId, forKey: .parentHubId)
        try container.encodeIfPresent(hubOffsetDirection, forKey: .hubOffsetDirection)
        try container.encode(routingConstraints, forKey: .routingConstraints)
        try container.encode(electrification, forKey: .electrification)
        try container.encodeIfPresent(taktMinutes, forKey: .taktMinutes)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var defaultVisualType: StationVisualType {
        switch type {
        case .interchange, .depot: return .filledSquare
        default: return .filledCircle
        }
    }

    var defaultColor: String {
        switch type {
        case .interchange: return "#FF3B30"
        case .depot: return "#FF9500"
        default: return "#000000"
        }
    }

    func isTrackAllowed(
        track: String?, routeId: String, prevStationId: String?, nextStationId: String?
    ) -> Bool {
        let t = track ?? "1"
        if let max = platforms, let tNum = Int(t), tNum > max { return false }
        let constraints = routingConstraints.filter { $0.routeId == routeId }
        if constraints.isEmpty { return true }
        let matchingConstraint = constraints.first { $0.directionStationId != nil && $0.directionStationId == nextStationId }
            ?? constraints.first { $0.directionStationId != nil && $0.directionStationId == prevStationId }
            ?? constraints.first { $0.directionStationId == nil }
        if let constraint = matchingConstraint {
            if constraint.allowedTracks.isEmpty { return true }
            return constraint.allowedTracks.contains(t)
        }
        return true
    }

    func getTracksByProvenance(
        from prevStationId: String?, nextStationId: String? = nil, forRoute routeId: String?
    ) -> [String] {
        let maxPlatforms = self.platforms ?? 2
        let allTracks = (1...maxPlatforms).map { "\($0)" }
        guard let routeId = routeId, !routeId.isEmpty else { return allTracks }
        let lineConstraints = routingConstraints.filter { $0.routeId == routeId }
        let matchingConstraint = lineConstraints.first { $0.directionStationId != nil && $0.directionStationId == nextStationId }
            ?? lineConstraints.first { $0.directionStationId != nil && $0.directionStationId == prevStationId }
            ?? lineConstraints.first { $0.directionStationId == nil }
        if let preferred = matchingConstraint?.allowedTracks, !preferred.isEmpty {
            return preferred
        }
        return allTracks
    }
}
