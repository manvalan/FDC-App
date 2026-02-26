import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public struct Edge: Identifiable, Codable, Hashable {
    public enum TrackType: String, Codable, CaseIterable, Identifiable {
        case highSpeed, regional, single, double
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .highSpeed: return "AV"
            case .regional: return "Reg"
            case .single: return "Sing"
            case .double: return "Dop"
            }
        }
        
        public var color: Color {
            switch self {
            case .highSpeed: return .red
            case .regional: return .blue
            case .single: return .gray
            case .double: return .gray
            }
        }
    }
    public var id: UUID = UUID()
    public var from: String // id nodo di partenza
    public var to: String   // id nodo di arrivo
    public var distance: Double
    public var trackType: TrackType
    public var maxSpeed: Int
    public var capacity: Int?
    public var segments: [TrackSegment] = [] // Segmenti fisici (blocchi) del binario
    public var geometryPoints: [GeometryPoint]? // Punti intermedi personalizzati per controllare la geometria del binario
    public var electrification: ElectrificationType = .dc3kv

    public var canonicalKey: String {
        let sorted = [from, to].sorted()
        return "\(sorted[0])-\(sorted[1])"
    }
    
    public struct GeometryPoint: Codable, Hashable, Identifiable {
        public var id: UUID = UUID()
        public var latitude: Double
        public var longitude: Double
    }

    enum CodingKeys: String, CodingKey {
        case id, from, to, distance, trackType, maxSpeed, capacity, segments, geometryPoints, electrification
    }

    public init(id: UUID = UUID(), from: String, to: String, distance: Double, trackType: TrackType, maxSpeed: Int, capacity: Int? = nil, electrification: ElectrificationType = .dc3kv) {
        self.id = id
        self.from = from
        self.to = to
        self.distance = distance
        self.trackType = trackType
        self.maxSpeed = maxSpeed
        self.capacity = capacity
        self.electrification = electrification
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 1.0
        trackType = try container.decodeIfPresent(TrackType.self, forKey: .trackType) ?? .regional
        maxSpeed = try container.decodeIfPresent(Int.self, forKey: .maxSpeed) ?? 120
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        segments = try container.decodeIfPresent([TrackSegment].self, forKey: .segments) ?? []
        electrification = try container.decodeIfPresent(ElectrificationType.self, forKey: .electrification) ?? .dc3kv
    }
}
