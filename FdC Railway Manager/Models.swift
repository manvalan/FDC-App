//
//  Created by Michele Bigi
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

// Bridge for refactoring compatibility
typealias RailwayNetwork = NetworkModel
typealias TrainManager = LinesManager
typealias RailwayEdge = Edge // Disambiguation from SwiftUI.Edge
typealias RailwayTrackSegment = TrackSegment
typealias RailwayNode = Node

// MARK: - Ferrovia (Infrastruttura Fisica)
/// Una Ferrovia rappresenta un percorso fisico dell'infrastruttura ferroviaria:
/// un segmento della rete composto da una sequenza ordinata di stazioni/nodi collegati da binari.
/// NON contiene informazioni di servizio (treni, orari, cadenzamento).
struct Ferrovia: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: String? // Colore per visualizzazione (hex)
    var stationIds: [String] // Sequenza ordinata di stazioni/nodi
    
    var uiColor: Color {
        if let hex = color, let c = Color(hex: hex) {
            return c
        }
        return .gray
    }
    
    init(id: String = UUID().uuidString, name: String, color: String? = nil, stationIds: [String] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.stationIds = stationIds
    }
}

struct RailwayNetworkDTO: Codable {
    var name: String?
    let nodes: [Node]
    let edges: [Edge]
    var ferrovie: [Ferrovia]?
    var lines: [RailwayLine]?
    var trains: [Train]?
    var vehicles: [Vehicle]?
}

extension NetworkModel {
    func toDTO() -> RailwayNetworkDTO {
        return RailwayNetworkDTO(name: name, nodes: nodes, edges: edges, ferrovie: ferrovie, lines: nil, trains: nil)
    }
    
    func apply(dto: RailwayNetworkDTO) {
        self.name = dto.name ?? "Network"
        self.nodes = dto.nodes
        self.edges = dto.edges
        self.ferrovie = dto.ferrovie ?? []
    }
}

struct AIScheduleSuggestion: Identifiable, Codable {
    var id: UUID = UUID()
    let trainId: UUID
    let newDepartureTime: String // HH:mm
    let stopAdjustments: [StopAdjustment]?
    
    struct StopAdjustment: Codable {
        let stationId: String
        let newMinDwellTime: Int
    }
}

// Routing Constraint for a station: defines which tracks are allowed for a specific line/direction
// Routing Constraint for a station: defines which tracks are allowed for a specific line/direction
public struct RoutingConstraint: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var lineId: String
    public var directionStationId: String? // Target station for direction (terminus or next node)
    public var allowedTracks: [String] // List of track names, e.g. ["1", "2"]
    
    enum CodingKeys: String, CodingKey {
        case id, lineId, directionStationId, allowedTracks
    }
    
    public init(id: UUID = UUID(), lineId: String, directionStationId: String? = nil, allowedTracks: [String]) {
        self.id = id
        self.lineId = lineId
        self.directionStationId = directionStationId
        self.allowedTracks = allowedTracks
    }
}

// Nodo della rete ferroviaria (stazione o interscambio)
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
    
    public let id: String // es: "MI"
    public var name: String
    public var type: NodeType
    public var visualType: StationVisualType?
    public var customColor: String?
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double? // Altezza sul livello del mare (m)
    public var capacity: Int?
    public var platforms: Int?
    public var parentHubId: String? // ID of parent hub station for linked stations
    public var hubOffsetDirection: HubOffsetDirection? // Position offset for hub visualization
    public var routingConstraints: [RoutingConstraint] = []
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, visualType, customColor, latitude, longitude, altitude, capacity, platforms
        case platformCount = "platform_count"
        case parentHubId, hubOffsetDirection, routingConstraints
    }

    public init(id: String, name: String, type: NodeType = .station, visualType: StationVisualType? = nil, customColor: String? = nil, latitude: Double? = nil, longitude: Double? = nil, altitude: Double? = nil, capacity: Int? = nil, platforms: Int? = 2, parentHubId: String? = nil, hubOffsetDirection: HubOffsetDirection? = nil) {
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
        platforms = try container.decodeIfPresent(Int.self, forKey: .platforms) ?? 
                    container.decodeIfPresent(Int.self, forKey: .platformCount) ?? 2
        parentHubId = try container.decodeIfPresent(String.self, forKey: .parentHubId)
        hubOffsetDirection = try container.decodeIfPresent(HubOffsetDirection.self, forKey: .hubOffsetDirection)
        routingConstraints = try container.decodeIfPresent([RoutingConstraint].self, forKey: .routingConstraints) ?? []
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
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // UI Helpers for consistent defaults
    var defaultVisualType: StationVisualType {
        switch type {
        case .interchange, .depot: return .filledSquare
        default: return .filledCircle
        }
    }
    
    var defaultColor: String {
        switch type {
        case .interchange: return "#FF3B30" // Red
        case .depot: return "#FF9500" // Orange
        default: return "#000000" // Black
        }
    }
    
    func isTrackAllowed(track: String?, lineId: String, prevStationId: String?, nextStationId: String?) -> Bool {
        let t = track ?? "1"
        
        // --- 1. Bounds Check ---
        if let max = platforms, let tNum = Int(t), tNum > max {
            return false
        }
        
        // --- 2. Routing Check ---
        let constraints = routingConstraints.filter { $0.lineId == lineId }
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

    /// Restituisce i binari preferiti in base alla provenienza.
    /// Se non ci sono vincoli specifici, restituisce tutti i binari disponibili (da cui scegliere a caso).
    func getTracksByProvenance(from prevStationId: String?, nextStationId: String? = nil, forLine lineId: String?) -> [String] {
        let maxPlatforms = self.platforms ?? 2
        let allTracks = (1...maxPlatforms).map { "\($0)" }
        
        guard let lineId = lineId, !lineId.isEmpty else { return allTracks }
        let lineConstraints = routingConstraints.filter { $0.lineId == lineId }
        
        // Priority for matching direction (where we are going next)
        // Secondary priority for matching provenance (where we came from)
        // Tertiary priority for a global constraint for this line
        let matchingConstraint = lineConstraints.first { $0.directionStationId != nil && $0.directionStationId == nextStationId }
                              ?? lineConstraints.first { $0.directionStationId != nil && $0.directionStationId == prevStationId }
                              ?? lineConstraints.first { $0.directionStationId == nil }

        if let preferred = matchingConstraint?.allowedTracks, !preferred.isEmpty {
            return preferred
        }
        
        return allTracks
    }
}

// Categorie Treni con parametri predefiniti
enum TrainCategory: String, CaseIterable, Identifiable {
    case regional = "Regionale"
    case direct = "Diretto"
    case highSpeed = "Alta Velocità"
    case freight = "Merci"
    case support = "Supporto"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .regional: return "regional_train".localized
        case .direct: return "intercity_train".localized
        case .highSpeed: return "highspeed_train".localized
        case .freight: return "freight_train".localized
        case .support: return "support_train".localized
        }
    }
    
    var defaultMaxSpeed: Int {
        switch self {
        case .highSpeed: return 300
        case .regional: return 140
        case .direct: return 160
        case .freight: return 100
        case .support: return 80
        }
    }
    
    var defaultPriority: Int {
        switch self {
        case .highSpeed: return 10
        case .direct: return 7
        case .regional: return 5
        case .freight: return 3
        case .support: return 1
        }
    }
    
    var color: Color {
        switch self {
        case .highSpeed: return .red
        case .direct: return .orange
        case .regional: return .green
        case .freight: return .indigo
        case .support: return .brown
        }
    }
}

// Binario (arco del grafo)
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
        case id, from, to, distance, trackType, maxSpeed, capacity, segments, geometryPoints
    }

    public init(id: UUID = UUID(), from: String, to: String, distance: Double, trackType: TrackType, maxSpeed: Int, capacity: Int? = nil) {
        self.id = id
        self.from = from
        self.to = to
        self.distance = distance
        self.trackType = trackType
        self.maxSpeed = maxSpeed
        self.capacity = capacity
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
    }
}

// MARK: - Dynamic Infrastructure Models

/// Rappresenta un tratto elementare di binario (circuito di binario / blocco).
public struct TrackSegment: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var order: Int
    public var length: Double // km
    public var isOccupied: Bool = false
    public var signal: Signal?
    
    // Physical Properties
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    public var speedLimit: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, order, length, isOccupied, signal, latitude, longitude, altitude, speedLimit
    }
    
    public init(id: UUID = UUID(), order: Int, length: Double, isOccupied: Bool = false, signal: Signal? = nil, latitude: Double? = nil, longitude: Double? = nil, altitude: Double? = nil, speedLimit: Int? = nil) {
        self.id = id
        self.order = order
        self.length = length
        self.isOccupied = isOccupied
        self.signal = signal
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speedLimit = speedLimit
    }
}

/// Rappresenta un segnale ferroviario.
public struct Signal: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    
    public enum SignalAspect: String, Codable {
        case stop, proceed, caution
    }
    
    public var aspect: SignalAspect = .stop
    public let positionAtEnd: Bool // Se true, il segnale è alla fine del segmento
    
    public init(id: UUID, name: String, aspect: SignalAspect = .stop, positionAtEnd: Bool) {
        self.id = id
        self.name = name
        self.aspect = aspect
        self.positionAtEnd = positionAtEnd
    }
}

/// Rappresenta uno scambio in una stazione o bivio.
struct Switch: Identifiable, Codable, Hashable {
    let id: UUID
    let nodeId: String
    var state: SwitchState = .normal
    let connectedEdges: [UUID] // ID degli Edge collegati
    
    enum SwitchState: String, Codable {
        case normal, reverse
    }
}

// Linea ferroviaria di servizio (insieme di stazioni con tempi di sosta, orari, treni)
struct RailwayLine: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: String? // ex: "#ff0000"
    var width: Double? // Line thickness in schematic view
    var originId: String = ""
    var destinationId: String = ""
    var stops: [RelationStop] = [] 
    
    // Train Numbering Logic
    var codePrefix: String? // e.g. "RE"
    var numberPrefix: Int? // e.g. 5 (results in 5001, 5002...)
    var cadenceFrequency: Double? // e.g. 30.0 or 60.0 minutes
    var terminalTracks: [String: String] = [:] // StationID -> Track
    
    var stations: [String] {
        stops.map { $0.stationId }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, width, originId, destinationId, stops, codePrefix, numberPrefix, cadenceFrequency, terminalTracks
    }

    init(id: String, name: String, color: String? = nil, width: Double? = nil, originId: String = "", destinationId: String = "", stops: [RelationStop] = [], codePrefix: String? = nil, numberPrefix: Int? = nil, cadenceFrequency: Double? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.width = width
        self.originId = originId
        self.destinationId = destinationId
        self.stops = stops
        self.codePrefix = codePrefix
        self.numberPrefix = numberPrefix
        self.cadenceFrequency = cadenceFrequency
        self.terminalTracks = [:]
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "unnamed_line".localized
        color = try container.decodeIfPresent(String.self, forKey: .color)
        width = try container.decodeIfPresent(Double.self, forKey: .width)
        originId = try container.decodeIfPresent(String.self, forKey: .originId) ?? ""
        destinationId = try container.decodeIfPresent(String.self, forKey: .destinationId) ?? ""
        stops = try container.decodeIfPresent([RelationStop].self, forKey: .stops) ?? []
        codePrefix = try container.decodeIfPresent(String.self, forKey: .codePrefix)
        numberPrefix = try container.decodeIfPresent(Int.self, forKey: .numberPrefix)
        cadenceFrequency = try container.decodeIfPresent(Double.self, forKey: .cadenceFrequency)
        terminalTracks = try container.decodeIfPresent([String: String].self, forKey: .terminalTracks) ?? [:]
    }
    
    var uiColor: Color {
        if let hex = color, let c = Color(hex: hex) {
            return c
        }
        return .accentColor
    }
}

// Fermata in una linea di servizio (con tempo di sosta)
struct RelationStop: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stationId: String
    var minDwellTime: Int = 3 // Minuit di sosta base (default 3)
    var extraDwellTime: Double = 0 // Ritardo extra da AI (minuti)
    var isSkipped: Bool = false // Se true, il treno non ferma (transito)
    var track: String? // Binario programmato (es: "1")
    var isManualTrack: Bool = false // Se true, non viene sovrascritto da auto-resolve o sync
    var isPreferredTrack: Bool = false // Se true, l'AI riceve un bonus se sceglie questo binario
    
    // Per treni specifici: orari pianificati (opzionali, sovrascrivono il calcolo)
    var plannedArrival: Date?
    var plannedDeparture: Date?
    
    // Custom dwell time in seconds (when user manually sets departure)
    // If set, this overrides minDwellTime + extraDwellTime
    var customDwellSeconds: TimeInterval?
    
    // Campi calcolati per visualizzazione/validazione corrente
    var arrival: Date?
    var departure: Date?

    enum CodingKeys: String, CodingKey {
        case id, stationId, minDwellTime, extraDwellTime, isSkipped, track, isManualTrack, isPreferredTrack, plannedArrival, plannedDeparture, customDwellSeconds, arrival, departure
    }

    init(id: UUID = UUID(), stationId: String, minDwellTime: Int = 3, extraDwellTime: Double = 0, isSkipped: Bool = false, track: String? = nil, isManualTrack: Bool = false, isPreferredTrack: Bool = false, plannedArrival: Date? = nil, plannedDeparture: Date? = nil, customDwellSeconds: TimeInterval? = nil, arrival: Date? = nil, departure: Date? = nil) {
        self.id = id
        self.stationId = stationId
        self.minDwellTime = minDwellTime
        self.extraDwellTime = extraDwellTime
        self.isSkipped = isSkipped
        self.track = track
        self.isManualTrack = isManualTrack
        self.isPreferredTrack = isPreferredTrack
        self.plannedArrival = plannedArrival
        self.plannedDeparture = plannedDeparture
        self.customDwellSeconds = customDwellSeconds
        self.arrival = arrival
        self.departure = departure
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        stationId = try container.decode(String.self, forKey: .stationId)
        minDwellTime = try container.decodeIfPresent(Int.self, forKey: .minDwellTime) ?? 3
        extraDwellTime = try container.decodeIfPresent(Double.self, forKey: .extraDwellTime) ?? 0
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
        track = try container.decodeIfPresent(String.self, forKey: .track)
        isManualTrack = try container.decodeIfPresent(Bool.self, forKey: .isManualTrack) ?? false
        isPreferredTrack = try container.decodeIfPresent(Bool.self, forKey: .isPreferredTrack) ?? false
        plannedArrival = try container.decodeIfPresent(Date.self, forKey: .plannedArrival)
        plannedDeparture = try container.decodeIfPresent(Date.self, forKey: .plannedDeparture)
        customDwellSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .customDwellSeconds)
        arrival = try container.decodeIfPresent(Date.self, forKey: .arrival)
        departure = try container.decodeIfPresent(Date.self, forKey: .departure)
    }
}

// Mezzo fisico (Materiale Rotabile)
struct Vehicle: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String // Matricola o Nome (es: "ETR521 #042")
    var model: String // Modello (es: "Pop", "Rock", "Minuetto")
    var length: Double = 200 // Lunghezza in metri
    var maxSpeed: Double = 160
    var acceleration: Double = 0.5
    var deceleration: Double = 0.4
    var imageName: String? // Optional image name or path
    
    // Per gestire il giro macchina
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, model, length, maxSpeed, acceleration, deceleration, notes, imageName
    }
    
    init(id: UUID = UUID(), name: String, model: String, length: Double = 200, maxSpeed: Double = 160, acceleration: Double = 0.5, deceleration: Double = 0.4, imageName: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.model = model
        self.length = length
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.imageName = imageName
        self.notes = notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        model = try container.decode(String.self, forKey: .model)
        length = try container.decodeIfPresent(Double.self, forKey: .length) ?? 200
        maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed) ?? 160
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration) ?? 0.5
        deceleration = try container.decodeIfPresent(Double.self, forKey: .deceleration) ?? 0.4
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

// Conflitto di assegnazione materiale rotabile
struct VehicleConflict: Identifiable {
    var id: UUID = UUID()
    let trainA: Train
    let trainB: Train
    let arrivalA: Date
    let departureB: Date
    
    var description: String {
        "Il treno \(trainA.name) arriva alle \(arrivalA.timeFormat), ma il treno \(trainB.name) parte alle \(departureB.timeFormat). Tempo di giro insufficiente."
    }
}

// Template per la creazione rapida di mezzi
struct VehicleTemplate: Identifiable {
    var id: String { name }
    let name: String
    let model: String
    let length: Double
    let maxSpeed: Double
    let acceleration: Double = 0.5
    let deceleration: Double = 0.4
    let imageName: String?
    
    init(name: String, model: String, length: Double, maxSpeed: Double, imageName: String? = nil) {
        self.name = name
        self.model = model
        self.length = length
        self.maxSpeed = maxSpeed
        self.imageName = imageName
    }
    
    static let all: [VehicleTemplate] = [
        // --- ALSTOM ---
        VehicleTemplate(name: "ETR 103 (Pop 3 casse)", model: "ETR 103", length: 65, maxSpeed: 160, imageName: "pop_3_casse"),
        VehicleTemplate(name: "ETR 104 (Pop 4 casse)", model: "ETR 104", length: 84, maxSpeed: 160, imageName: "pop_4_casse"),
        VehicleTemplate(name: "ETR 204 (Pop 4 casse V2)", model: "ETR 204", length: 84, maxSpeed: 160, imageName: "pop_4_casse_v2"),
        VehicleTemplate(name: "ETR 255 (Pop 5 casse)", model: "ETR 255", length: 104, maxSpeed: 160, imageName: "pop_5_casse"),
        VehicleTemplate(name: "ETR 425 (Jazz 5 casse)", model: "ETR 425", length: 82, maxSpeed: 160, imageName: "jazz_5_casse"),
        VehicleTemplate(name: "ETR 324 (Jazz 4 casse)", model: "ETR 324", length: 67, maxSpeed: 160, imageName: "jazz_4_casse"),
        VehicleTemplate(name: "ALn/Eln 501 (Minuetto)", model: "ALn 501", length: 52, maxSpeed: 130, imageName: "minuetto"),
        VehicleTemplate(name: "ETR 600/610 (Pendolino)", model: "ETR 600", length: 187, maxSpeed: 250, imageName: "pendolino_etr600"),
        VehicleTemplate(name: "ETR 485 (Pendolino)", model: "ETR 485", length: 236, maxSpeed: 250, imageName: "pendolino_etr485"),
        
        // --- HITACHI / ANSALDO BREDA ---
        VehicleTemplate(name: "ETR 1000 (Frecciarossa)", model: "ETR 1000", length: 202, maxSpeed: 360, imageName: "frecciarossa_1000"),
        VehicleTemplate(name: "ETR 500 (Frecciarossa)", model: "ETR 500", length: 328, maxSpeed: 300, imageName: "frecciarossa_500"),
        VehicleTemplate(name: "ETR 700 (Frecciargento)", model: "ETR 700", length: 200, maxSpeed: 250, imageName: "frecciargento_700"),
        VehicleTemplate(name: "ETR 421 (Rock 4 casse)", model: "ETR 421", length: 110, maxSpeed: 160, imageName: "rock_4_casse"),
        VehicleTemplate(name: "ETR 521 (Rock 5 casse)", model: "ETR 521", length: 136, maxSpeed: 160, imageName: "rock_5_casse"),
        VehicleTemplate(name: "ETR 621 (Rock 6 casse)", model: "ETR 621", length: 162, maxSpeed: 160, imageName: "rock_6_casse"),
        VehicleTemplate(name: "HTR 312 (Blues 3 casse)", model: "HTR 312", length: 67, maxSpeed: 160, imageName: "blues_3_casse"),
        VehicleTemplate(name: "HTR 412 (Blues 4 casse)", model: "HTR 412", length: 86, maxSpeed: 160, imageName: "blues_4_casse"),
        VehicleTemplate(name: "TAF (Treno Alta Freq.)", model: "TAF", length: 104, maxSpeed: 140, imageName: "taf"),
        VehicleTemplate(name: "TSR (Treno Serv. Reg.)", model: "TSR", length: 78, maxSpeed: 140, imageName: "tsr"),
        
        // --- STADLER ---
        VehicleTemplate(name: "ATR 803 (Colleoni)", model: "ATR 803", length: 67, maxSpeed: 140, imageName: "colleoni"),
        VehicleTemplate(name: "ETR 170 (FLIRT)", model: "ETR 170", length: 75, maxSpeed: 160, imageName: "flirt"),
        VehicleTemplate(name: "ETR 343 (FLIRT XL)", model: "ETR 343", length: 105, maxSpeed: 160, imageName: "flirt_xl"),
        
        // --- PESA ---
        VehicleTemplate(name: "ATR 220 (Swing)", model: "ATR 220", length: 55, maxSpeed: 130, imageName: "swing"),
        
        // --- LOCOMOTIVE / NAVETTA ---
        VehicleTemplate(name: "E.464 + 5 Medie Distanze", model: "E.464", length: 155, maxSpeed: 160, imageName: "navetta_md"),
        VehicleTemplate(name: "E.464 + 3 Vivalto", model: "E.464", length: 110, maxSpeed: 160, imageName: "vivalto_3"),
        VehicleTemplate(name: "E.464 + 5 Vivalto", model: "E.464", length: 160, maxSpeed: 160, imageName: "vivalto_5"),
        VehicleTemplate(name: "E.494 (TRAXX DC3)", model: "E.494", length: 19, maxSpeed: 160, imageName: "traxx_dc3"),
        VehicleTemplate(name: "E.191/193 (Vectron)", model: "E.191", length: 19, maxSpeed: 200, imageName: "vectron"),
        VehicleTemplate(name: "E.652 (Caimano)", model: "E.652", length: 18, maxSpeed: 160, imageName: "caimano"),
        VehicleTemplate(name: "D.445 (Loco Diesel)", model: "D.445", length: 14, maxSpeed: 130, imageName: "d445"),
        
        // --- LEGACY / STORICI ---
        VehicleTemplate(name: "ALn 663 (Singola)", model: "Fiat Ferroviaria (Diesel)", length: 23, maxSpeed: 120, imageName: "aln663"),
        VehicleTemplate(name: "ALn 776 (Singola)", model: "Ferrosud (Diesel)", length: 24, maxSpeed: 150, imageName: "aln776")
    ]
}

// Treno circolante nella rete
struct Train: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var number: Int?
    var name: String
    var type: String
    var lineId: String?
    var departureTime: Date?
    var stops: [RelationStop] = []
    
    // Collegamento al materiale rotante
    var vehicleId: UUID?
    
    // Technical specs
    var maxSpeed: Double = 120
    var acceleration: Double = 0.5
    var deceleration: Double = 0.5
    var priority: Int = 5
    var schedulingError: String? // Campo per segnalare errori di calcolo orario
    
    init(id: UUID = UUID(), number: Int? = nil, name: String, type: String, lineId: String? = nil, departureTime: Date? = nil, stops: [RelationStop] = [], vehicleId: UUID? = nil, maxSpeed: Double = 120, acceleration: Double = 0.5, deceleration: Double = 0.5, priority: Int = 5) {
        self.id = id
        self.number = number
        self.name = name
        self.type = type
        self.lineId = lineId
        self.departureTime = departureTime
        self.stops = stops
        self.vehicleId = vehicleId
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.priority = priority
    }
    
    enum CodingKeys: String, CodingKey {
        case id, number, name, type, lineId, departureTime, stops, maxSpeed, acceleration, deceleration, priority, vehicleId, schedulingError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        lineId = try container.decodeIfPresent(String.self, forKey: .lineId)
        departureTime = try container.decodeIfPresent(Date.self, forKey: .departureTime)
        stops = try container.decodeIfPresent([RelationStop].self, forKey: .stops) ?? []
        vehicleId = try container.decodeIfPresent(UUID.self, forKey: .vehicleId)
        maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed) ?? 120
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration) ?? 0.5
        deceleration = try container.decodeIfPresent(Double.self, forKey: .deceleration) ?? 0.5
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 5
        schedulingError = try container.decodeIfPresent(String.self, forKey: .schedulingError)
    }
}

extension Train {
    /// Restituisce la lista dei binari preferenziali ordinati per priorità.
    /// - Parameters:
    ///   - node: La stazione in oggetto.
    ///   - prevStationId: L'ID della stazione da cui proviene il treno (opzionale).
    ///   - nextStationId: L'ID della stazione successiva (opzionale).
    ///   - line: La linea di appartenenza del treno (se nil, usa quella del treno).
    /// - Returns: Una lista di stringhe (es: ["2", "1", "3"]) dove il primo è il preferito.
    func getPreferredTracks(at node: Node, prevStationId: String?, nextStationId: String?, for line: RailwayLine?) -> [String] {
        let maxPlatforms = node.platforms ?? 2
        let allPlatforms = (1...maxPlatforms).map { "\($0)" }
        let targetLineId = line?.id ?? self.lineId ?? ""
        
        // Cerchiamo i vincoli specifici per questa linea in questa stazione
        let lineConstraints = node.routingConstraints.filter { $0.lineId == targetLineId }
        
        // 1. Cerchiamo un vincolo che corrisponda esattamente alla direzione (prossima stazione)
        let matchingConstraint = lineConstraints.first { $0.directionStationId == nextStationId } 
                              ?? lineConstraints.first { $0.directionStationId == nil }
        
        let preferred = matchingConstraint?.allowedTracks ?? []
        
        // Se non abbiamo preferenze, restituiamo tutti i binari (es: ["1", "2"])
        if preferred.isEmpty {
            return allPlatforms
        }
        
        // Costruiamo la lista finale: prima i preferiti, poi gli altri come alternative
        var finalList = preferred
        for platform in allPlatforms {
            if !finalList.contains(platform) {
                finalList.append(platform)
            }
        }
        
        return finalList
    }

    func isTrackPreferred(_ track: String, at node: Node, prevStationId: String?, nextStationId: String?, for lineId: String?) -> Bool {
        let targetLineId = lineId ?? self.lineId ?? ""
        let lineConstraints = node.routingConstraints.filter { $0.lineId == targetLineId }
        let matchingConstraint = lineConstraints.first { $0.directionStationId == nextStationId } 
                              ?? lineConstraints.first { $0.directionStationId == nil }
        return matchingConstraint?.allowedTracks.contains(track) ?? false
    }
}
// MARK: - Helpers

extension Int: Identifiable {
    public var id: Int { self }
}
/// Simple exporter for nodes and edges only (stations and tracks)
final class NetworkIOExporter: ObservableObject {
    static let shared = NetworkIOExporter()
    private init() {}

    /// Returns JSON Data with only stations (nodes) and tracks (edges)
    func exportStationsAndTracksJSON(nodes: [Node], edges: [Edge]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        struct Payload: Encodable {
            let nodes: [Node]
            let edges: [Edge]
        }
        let payload = Payload(nodes: nodes, edges: edges)
        return try? encoder.encode(payload)
    }

    /// Convenience string version
    func exportString(nodes: [Node], edges: [Edge]) -> String? {
        guard let data = exportStationsAndTracksJSON(nodes: nodes, edges: edges) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

