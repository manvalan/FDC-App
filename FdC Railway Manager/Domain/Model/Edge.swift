import Foundation

public struct Edge: Identifiable, Codable, Hashable {
    public enum TrackType: String, Codable, CaseIterable, Identifiable {
        case highSpeed, regional, single
        public var id: String { rawValue }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if raw == "double" { self = .single; return }
            guard let value = TrackType(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown TrackType: \(raw)")
            }
            self = value
        }

        public var displayName: String {
            switch self {
            case .highSpeed: return "AV"
            case .regional: return "Reg"
            case .single: return "Sing"
            }
        }
    }

    public var id: UUID = UUID()
    public var from: String
    public var to: String
    public var pairedEdgeId: UUID? = nil
    public var distance: Double
    public var trackType: TrackType
    public var maxSpeed: Int
    public var capacity: Int?
    public var hasManualDistance: Bool = false
    public var segments: [TrackSegment] = []
    public var controlPoints: [TrackControlPoint] = []
    public var electrification: ElectrificationType = .dc3kv
    public var needsPairedMigration: Bool = false

    public var canonicalKey: String {
        Edge.canonicalKey(from: from, to: to)
    }

    public static func canonicalKey(from: String, to: String) -> String {
        let sorted = [from, to].sorted()
        return "\(sorted[0])-\(sorted[1])"
    }

    public struct GeometryPoint: Codable, Hashable, Identifiable {
        public var id: UUID = UUID()
        public var latitude: Double
        public var longitude: Double
    }

    enum CodingKeys: String, CodingKey {
        case id, from, to, distance, trackType, maxSpeed, capacity
        case segments, geometryPoints, controlPoints
        case electrification, hasManualDistance, pairedEdgeId
    }

    public init(
        id: UUID = UUID(), from: String, to: String, distance: Double,
        trackType: TrackType, maxSpeed: Int, capacity: Int? = nil,
        electrification: ElectrificationType = .dc3kv,
        hasManualDistance: Bool = false, pairedEdgeId: UUID? = nil
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.distance = distance
        self.trackType = trackType
        self.maxSpeed = maxSpeed
        self.capacity = capacity
        self.electrification = electrification
        self.hasManualDistance = hasManualDistance
        self.pairedEdgeId = pairedEdgeId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 1.0
        let rawTrackType = try container.decodeIfPresent(String.self, forKey: .trackType) ?? "regional"
        if rawTrackType == "double" {
            trackType = .single
            needsPairedMigration = true
        } else {
            trackType = TrackType(rawValue: rawTrackType) ?? .regional
        }
        maxSpeed = try container.decodeIfPresent(Int.self, forKey: .maxSpeed) ?? 120
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        segments = try container.decodeIfPresent([TrackSegment].self, forKey: .segments) ?? []
        let legacyPoints = try container.decodeIfPresent([GeometryPoint].self, forKey: .geometryPoints) ?? []
        let decoded = try container.decodeIfPresent([TrackControlPoint].self, forKey: .controlPoints) ?? []
        if decoded.isEmpty && !legacyPoints.isEmpty {
            controlPoints = legacyPoints.map {
                TrackControlPoint(id: $0.id, latitude: $0.latitude, longitude: $0.longitude)
            }
        } else {
            controlPoints = decoded
        }
        electrification = try container.decodeIfPresent(ElectrificationType.self, forKey: .electrification) ?? .dc3kv
        hasManualDistance = try container.decodeIfPresent(Bool.self, forKey: .hasManualDistance) ?? false
        pairedEdgeId = try container.decodeIfPresent(UUID.self, forKey: .pairedEdgeId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(distance, forKey: .distance)
        try container.encode(trackType, forKey: .trackType)
        try container.encode(maxSpeed, forKey: .maxSpeed)
        try container.encodeIfPresent(capacity, forKey: .capacity)
        try container.encode(segments, forKey: .segments)
        try container.encode(controlPoints, forKey: .controlPoints)
        try container.encode(electrification, forKey: .electrification)
        try container.encode(hasManualDistance, forKey: .hasManualDistance)
        try container.encodeIfPresent(pairedEdgeId, forKey: .pairedEdgeId)
    }
}
