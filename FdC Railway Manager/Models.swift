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
typealias RailwayVehicle = Vehicle
typealias RailwayTrain = Train

// MARK: - Electrification
public enum ElectrificationType: String, Codable, CaseIterable, Identifiable {
    case none = "Nessuna (Diesel)"
    case dc3kv = "3kV CC"
    case ac25kv = "25kV CA"
    case dc950v = "950V CC" // Tipico FdC
    
    public var id: String { rawValue }
    
    public var isElectrified: Bool {
        return self != .none
    }
}


public struct RailwayNetworkDTO: Codable {
    public var name: String? = nil
    public let nodes: [Node]
    public let edges: [Edge]
    public var ferrovie: [Ferrovia]? = nil
    public var lines: [RailwayLine]? = nil
    public var trains: [Train]? = nil
    public var vehicles: [Vehicle]? = nil
    
    public init(name: String? = nil, nodes: [Node], edges: [Edge], ferrovie: [Ferrovia]? = nil, lines: [RailwayLine]? = nil, trains: [Train]? = nil, vehicles: [Vehicle]? = nil) {
        self.name = name
        self.nodes = nodes
        self.edges = edges
        self.ferrovie = ferrovie
        self.lines = lines
        self.trains = trains
        self.vehicles = vehicles
    }
}

extension NetworkModel {
    func toDTO() -> RailwayNetworkDTO {
        return RailwayNetworkDTO(name: name, nodes: nodes, edges: edges, ferrovie: ferrovie, lines: nil, trains: nil, vehicles: nil)
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
    public var transitTracks: [String]? // Prioritari per transito (senza sosta)
    public var stopTracks: [String]?    // Prioritari per sosta/partenza/arrivo
    
    enum CodingKeys: String, CodingKey {
        case id, lineId, directionStationId, allowedTracks, transitTracks, stopTracks
    }
    
    public init(id: UUID = UUID(), lineId: String, directionStationId: String? = nil, allowedTracks: [String], transitTracks: [String]? = nil, stopTracks: [String]? = nil) {
        self.id = id
        self.lineId = lineId
        self.directionStationId = directionStationId
        self.allowedTracks = allowedTracks
        self.transitTracks = transitTracks
        self.stopTracks = stopTracks
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
    public var electrification: ElectrificationType = .dc3kv
    public var taktMinutes: Int? // Swiss-style Taktfahrplan: minute mark for convergence (e.g., 0, 15, 30, 45)
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, visualType, customColor, latitude, longitude, altitude, capacity, platforms, electrification
        case platformCount = "platform_count"
        case parentHubId, hubOffsetDirection, routingConstraints, taktMinutes
    }

    public init(id: String, name: String, type: NodeType = .station, visualType: StationVisualType? = nil, customColor: String? = nil, latitude: Double? = nil, longitude: Double? = nil, altitude: Double? = nil, capacity: Int? = nil, platforms: Int? = 2, parentHubId: String? = nil, hubOffsetDirection: HubOffsetDirection? = nil, electrification: ElectrificationType = .dc3kv, taktMinutes: Int? = nil) {
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
        platforms = try container.decodeIfPresent(Int.self, forKey: .platforms) ?? 
                    container.decodeIfPresent(Int.self, forKey: .platformCount) ?? 2
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
public enum TrainCategory: String, CaseIterable, Identifiable {
    case regional = "Regionale"
    case direct = "Diretto"
    case highSpeed = "Alta Velocità"
    case freight = "Merci"
    case support = "Supporto"
    
    public var id: String { rawValue }
    
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
public struct Switch: Identifiable, Codable, Hashable {
    public let id: UUID
    public let nodeId: String
    public var state: SwitchState = .normal
    public let connectedEdges: [UUID] // ID degli Edge collegati
    
    public enum SwitchState: String, Codable {
        case normal, reverse
    }
}

// Linea ferroviaria di servizio (insieme di stazioni con tempi di sosta, orari, treni)
public struct RailwayLine: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var color: String? // ex: "#ff0000"
    public var width: Double? // Line thickness in schematic view
    public var originId: String = ""
    public var destinationId: String = ""
    public var stops: [RelationStop] = [] 
    
    // Train Numbering Logic
    public var codePrefix: String? // e.g. "RE"
    public var numberPrefix: Int? // e.g. 5 (results in 5001, 5002...)
    public var cadenceFrequency: Double? // e.g. 30.0 or 60.0 minutes
    public var terminalTracks: [String: String] = [:] // StationID -> Track
    
    public var stations: [String] {
        stops.map { $0.stationId }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, width, originId, destinationId, stops, codePrefix, numberPrefix, cadenceFrequency, terminalTracks
    }

    public init(id: String, name: String, color: String? = nil, width: Double? = nil, originId: String = "", destinationId: String = "", stops: [RelationStop] = [], codePrefix: String? = nil, numberPrefix: Int? = nil, cadenceFrequency: Double? = nil) {
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
    
    public init(from decoder: Decoder) throws {
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
public struct RelationStop: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var stationId: String
    public var minDwellTime: Int = 3 // Minuit di sosta base (default 3)
    public var extraDwellTime: Double = 0 // Ritardo extra da AI (minuti)
    public var isSkipped: Bool = false // Se true, il treno non ferma (transito)
    public var track: String? // Binario programmato (es: "1")
    public var isManualTrack: Bool = false // Se true, non viene sovrascritto da auto-resolve o sync
    public var isPreferredTrack: Bool = false // Se true, l'AI riceve un bonus se sceglie questo binario
    
    // Per treni specifici: orari pianificati (opzionali, sovrascrivono il calcolo)
    public var plannedArrival: Date?
    public var plannedDeparture: Date?
    
    // Custom dwell time in seconds (when user manually sets departure)
    // If set, this overrides minDwellTime + extraDwellTime
    public var customDwellSeconds: TimeInterval?
    
    // Campi calcolati per visualizzazione/validazione corrente
    public var arrival: Date?
    public var departure: Date?

    enum CodingKeys: String, CodingKey {
        case id, stationId, minDwellTime, extraDwellTime, isSkipped, track, isManualTrack, isPreferredTrack, plannedArrival, plannedDeparture, customDwellSeconds, arrival, departure
    }

    public init(id: UUID = UUID(), stationId: String, minDwellTime: Int = 3, extraDwellTime: Double = 0, isSkipped: Bool = false, track: String? = nil, isManualTrack: Bool = false, isPreferredTrack: Bool = false, plannedArrival: Date? = nil, plannedDeparture: Date? = nil, customDwellSeconds: TimeInterval? = nil, arrival: Date? = nil, departure: Date? = nil) {
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
    
    public init(from decoder: Decoder) throws {
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
public struct Vehicle: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var name: String // Matricola o Nome (es: "ETR521 #042")
    public var model: String // Modello (es: "Pop", "Rock", "Minuetto")
    public var length: Double = 200 // Lunghezza in metri
    public var maxSpeed: Double = 160
    public var acceleration: Double = 0.5
    public var deceleration: Double = 0.4
    public var mass: Double = 200 // Massa in tonnellate
    public var power: Double = 2500 // Potenza in kW
    public var imageName: String? // Optional image name or path
    
    // Per gestire il giro macchina
    public var notes: String?
    public var isElectric: Bool = true // Se il mezzo è elettrico o diesel
    
    enum CodingKeys: String, CodingKey {
        case id, name, model, length, maxSpeed, acceleration, deceleration, mass, power, notes, imageName, isElectric
    }
    
    public init(id: UUID = UUID(), name: String, model: String, length: Double = 200, maxSpeed: Double = 160, acceleration: Double = 0.5, deceleration: Double = 0.4, mass: Double = 200, power: Double = 2500, isElectric: Bool = true, imageName: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.model = model
        self.length = length
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.mass = mass
        self.power = power
        self.isElectric = isElectric
        self.imageName = imageName
        self.notes = notes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        model = try container.decode(String.self, forKey: .model)
        length = try container.decodeIfPresent(Double.self, forKey: .length) ?? 200
        maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed) ?? 160
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration) ?? 0.5
        deceleration = try container.decodeIfPresent(Double.self, forKey: .deceleration) ?? 0.4
        mass = try container.decodeIfPresent(Double.self, forKey: .mass) ?? 200
        power = try container.decodeIfPresent(Double.self, forKey: .power) ?? 2500
        isElectric = try container.decodeIfPresent(Bool.self, forKey: .isElectric) ?? true
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
    let acceleration: Double
    let deceleration: Double
    let mass: Double
    let power: Double
    let isElectric: Bool
    let imageName: String?
    
    init(name: String, model: String, length: Double, maxSpeed: Double, acceleration: Double = 0.5, deceleration: Double = 0.4, mass: Double = 200, power: Double = 2500, isElectric: Bool = true, imageName: String? = nil) {
        self.name = name
        self.model = model
        self.length = length
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.mass = mass
        self.power = power
        self.isElectric = isElectric
        self.imageName = imageName
    }
    
    static let all: [VehicleTemplate] = [
        // --- ALSTOM ---
        VehicleTemplate(name: "ETR 103 (Pop 3 casse)", model: "ETR 103", length: 65, maxSpeed: 160, acceleration: 1.0, mass: 140, power: 2000, imageName: "pop_3_casse"),
        VehicleTemplate(name: "ETR 104 (Pop 4 casse)", model: "ETR 104", length: 84, maxSpeed: 160, acceleration: 1.0, mass: 180, power: 2600, imageName: "pop_4_casse"),
        VehicleTemplate(name: "ETR 204 (Pop 4 casse V2)", model: "ETR 204", length: 84, maxSpeed: 160, acceleration: 1.1, mass: 185, power: 2800, imageName: "pop_4_casse_v2"),
        VehicleTemplate(name: "ETR 255 (Pop 5 casse)", model: "ETR 255", length: 104, maxSpeed: 160, acceleration: 0.9, mass: 220, power: 3200, imageName: "pop_5_casse"),
        VehicleTemplate(name: "ETR 425 (Jazz 5 casse)", model: "ETR 425", length: 82, maxSpeed: 160, acceleration: 0.9, mass: 175, power: 2400, imageName: "jazz_5_casse"),
        VehicleTemplate(name: "ETR 324 (Jazz 4 casse)", model: "ETR 324", length: 67, maxSpeed: 160, acceleration: 1.0, mass: 145, power: 2000, imageName: "jazz_4_casse"),
        VehicleTemplate(name: "ALn/Eln 501 (Minuetto)", model: "ALn 501", length: 52, maxSpeed: 130, acceleration: 0.8, mass: 110, power: 1250, isElectric: false, imageName: "minuetto"),
        VehicleTemplate(name: "ETR 600/610 (Pendolino)", model: "ETR 600", length: 187, maxSpeed: 250, acceleration: 0.48, mass: 390, power: 5500, imageName: "pendolino_etr600"),
        VehicleTemplate(name: "ETR 485 (Pendolino)", model: "ETR 485", length: 236, maxSpeed: 250, acceleration: 0.45, mass: 440, power: 5600, imageName: "pendolino_etr485"),
        
        // --- HITACHI / ANSALDO BREDA ---
        VehicleTemplate(name: "ETR 1000 (Frecciarossa)", model: "ETR 1000", length: 202, maxSpeed: 360, acceleration: 0.7, mass: 450, power: 9800, imageName: "frecciarossa_1000"),
        VehicleTemplate(name: "ETR 500 (Frecciarossa)", model: "ETR 500", length: 328, maxSpeed: 300, acceleration: 0.35, mass: 550, power: 8800, imageName: "frecciarossa_500"),
        VehicleTemplate(name: "ETR 700 (Frecciargento)", model: "ETR 700", length: 202, maxSpeed: 250, acceleration: 0.45, mass: 440, power: 5560, imageName: "frecciargento_700"),
        
        // --- INTERCITY (COMP. FISSA) ---
        VehicleTemplate(name: "E.401 + 8 UIC-Z (IC)", model: "E.401", length: 220, maxSpeed: 200, acceleration: 0.4, mass: 500, power: 6000, imageName: "ic_e401"),
        VehicleTemplate(name: "E.402B + 8 UIC-Z (IC)", model: "E.402B", length: 225, maxSpeed: 200, acceleration: 0.4, mass: 520, power: 6000, imageName: "ic_e402b"),
        VehicleTemplate(name: "ETR 421 (Rock 4 casse)", model: "ETR 421", length: 110, maxSpeed: 160, acceleration: 1.1, mass: 220, power: 3400, imageName: "rock_4_casse"),
        VehicleTemplate(name: "ETR 521 (Rock 5 casse)", model: "ETR 521", length: 136, maxSpeed: 160, acceleration: 1.0, mass: 270, power: 4200, imageName: "rock_5_casse"),
        VehicleTemplate(name: "ETR 621 (Rock 6 casse)", model: "ETR 621", length: 162, maxSpeed: 160, acceleration: 0.9, mass: 320, power: 5000, imageName: "rock_6_casse"),
        VehicleTemplate(name: "HTR 312 (Blues 3 casse)", model: "HTR 312", length: 67, maxSpeed: 160, acceleration: 1.0, mass: 150, power: 2200, isElectric: true, imageName: "blues_3_casse"),
        VehicleTemplate(name: "HTR 412 (Blues 4 casse)", model: "HTR 412", length: 86, maxSpeed: 160, acceleration: 0.9, mass: 190, power: 2800, isElectric: true, imageName: "blues_4_casse"),
        VehicleTemplate(name: "TAF (Treno Alta Freq.)", model: "TAF", length: 104, maxSpeed: 140, acceleration: 0.8, mass: 210, power: 2300, imageName: "taf"),
        VehicleTemplate(name: "TSR (Treno Serv. Reg.)", model: "TSR", length: 78, maxSpeed: 140, acceleration: 0.9, mass: 165, power: 2500, imageName: "tsr"),
        
        // --- STADLER ---
        VehicleTemplate(name: "ATR 803 (Colleoni)", model: "ATR 803", length: 67, maxSpeed: 140, acceleration: 1.0, mass: 135, power: 1800, isElectric: false, imageName: "colleoni"),
        VehicleTemplate(name: "ETR 170 (FLIRT)", model: "ETR 170", length: 75, maxSpeed: 160, acceleration: 1.2, mass: 125, power: 2600, imageName: "flirt"),
        VehicleTemplate(name: "ETR 343 (FLIRT XL)", model: "ETR 343", length: 105, maxSpeed: 160, acceleration: 1.1, mass: 180, power: 3000, imageName: "flirt_xl"),
        
        // --- PESA ---
        VehicleTemplate(name: "ATR 220 (Swing)", model: "ATR 220", length: 55, maxSpeed: 130, acceleration: 0.7, mass: 105, power: 1100, isElectric: false, imageName: "swing"),
        
        // --- LOCOMOTIVE / NAVETTA ---
        VehicleTemplate(name: "E.464 + 5 Medie Distanze", model: "E.464", length: 155, maxSpeed: 160, acceleration: 0.5, mass: 310, power: 3500, isElectric: true, imageName: "navetta_md"),
        VehicleTemplate(name: "E.464 + 3 Vivalto", model: "E.464", length: 110, maxSpeed: 160, acceleration: 0.7, mass: 230, power: 3500, isElectric: true, imageName: "vivalto_3"),
        VehicleTemplate(name: "E.464 + 5 Vivalto", model: "E.464", length: 160, maxSpeed: 160, acceleration: 0.5, mass: 330, power: 3500, isElectric: true, imageName: "vivalto_5"),
        VehicleTemplate(name: "E.494 (TRAXX DC3)", model: "E.494", length: 19, maxSpeed: 160, acceleration: 0.4, mass: 82, power: 6400, isElectric: true, imageName: "traxx_dc3"),
        VehicleTemplate(name: "E.191/193 (Vectron)", model: "E.191", length: 19, maxSpeed: 200, acceleration: 0.5, mass: 86, power: 6400, isElectric: true, imageName: "vectron"),
        VehicleTemplate(name: "E.652 (Caimano)", model: "E.652", length: 18, maxSpeed: 160, acceleration: 0.4, mass: 106, power: 5000, isElectric: true, imageName: "caimano"),
        VehicleTemplate(name: "D.445 (Loco Diesel)", model: "D.445", length: 14, maxSpeed: 130, acceleration: 0.3, mass: 72, power: 1560, isElectric: false, imageName: "d445"),
        
        // --- LEGACY / STORICI ---
        VehicleTemplate(name: "ALn 663 (Singola)", model: "Fiat Ferroviaria (Diesel)", length: 23, maxSpeed: 120, acceleration: 0.4, mass: 43, power: 340, isElectric: false, imageName: "aln663"),
        VehicleTemplate(name: "ALn 776 (Singola)", model: "Ferrosud (Diesel)", length: 24, maxSpeed: 150, acceleration: 0.6, mass: 45, power: 450, isElectric: false, imageName: "aln776")
    ]
}

// Treno circolante nella rete
public struct Train: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var number: Int?
    public var name: String
    public var type: String
    public var lineId: String?
    public var isElectric: Bool = true // Se il treno è elettrico
    public var departureTime: Date?
    public var stops: [RelationStop] = []
    
    // Collegamento al materiale rotante
    public var vehicleId: UUID?
    
    // Technical specs
    public var maxSpeed: Double = 120
    public var acceleration: Double = 0.5
    public var deceleration: Double = 0.5
    public var mass: Double = 200 // Massa in tonnellate
    public var power: Double = 2500 // Potenza in kW
    public var priority: Int = 5
    public var isMainTrain: Bool = false
    public var schedulingError: String? // Campo per segnalare errori di calcolo orario
    
    public init(id: UUID = UUID(), number: Int? = nil, name: String, type: String, lineId: String? = nil, departureTime: Date? = nil, stops: [RelationStop] = [], vehicleId: UUID? = nil, maxSpeed: Double = 160, acceleration: Double = 0.5, deceleration: Double = 0.4, mass: Double = 200, power: Double = 2500, priority: Int = 5, isElectric: Bool = true, isMainTrain: Bool = false) {
        self.id = id
        self.number = number
        self.name = name
        self.type = type
        self.lineId = lineId
        self.stops = stops
        self.vehicleId = vehicleId
        self.departureTime = departureTime
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.mass = mass
        self.power = power
        self.priority = priority
        self.isElectric = isElectric
        self.isMainTrain = isMainTrain
    }
    
    enum CodingKeys: String, CodingKey {
        case id, number, name, type, lineId, departureTime, stops, maxSpeed, acceleration, deceleration, mass, power, priority, vehicleId, schedulingError, isElectric, isMainTrain
    }

    public init(from decoder: Decoder) throws {
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
        mass = try container.decodeIfPresent(Double.self, forKey: .mass) ?? 200
        power = try container.decodeIfPresent(Double.self, forKey: .power) ?? 2500
        isElectric = try container.decodeIfPresent(Bool.self, forKey: .isElectric) ?? true
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 5
        isMainTrain = try container.decodeIfPresent(Bool.self, forKey: .isMainTrain) ?? false
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
    ///   - isSkipping: Se il treno transita senza fermarsi in questa stazione.
    /// - Returns: Una lista di stringhe (es: ["2", "1", "3"]) dove il primo è il preferito.
    func getPreferredTracks(at node: Node, prevStationId: String?, nextStationId: String?, for line: RailwayLine?, isSkipping: Bool = false) -> [String] {
        let maxPlatforms = node.platforms ?? 2
        let allPlatforms = (1...maxPlatforms).map { "\($0)" }
        let targetLineId = line?.id ?? self.lineId ?? ""
        
        // Cerchiamo i vincoli specifici per questa linea in questa stazione
        let lineConstraints = node.routingConstraints.filter { $0.lineId == targetLineId }
        
        // 1. Cerchiamo un vincolo che corrisponda esattamente alla direzione (prossima stazione)
        let matchingConstraint = lineConstraints.first { $0.directionStationId == nextStationId } 
                              ?? lineConstraints.first { $0.directionStationId == nil }
        
        var preferred: [String] = []
        
        if let constraint = matchingConstraint {
            if isSkipping {
                // Priorità Transito: transitTracks -> stopTracks -> allowedTracks
                preferred.append(contentsOf: constraint.transitTracks ?? [])
                preferred.append(contentsOf: constraint.stopTracks ?? [])
                preferred.append(contentsOf: constraint.allowedTracks)
            } else {
                // Priorità Sosta: stopTracks -> transitTracks -> allowedTracks
                preferred.append(contentsOf: constraint.stopTracks ?? [])
                preferred.append(contentsOf: constraint.transitTracks ?? [])
                preferred.append(contentsOf: constraint.allowedTracks)
            }
        }
        
        // Se non abbiamo preferenze, restituiamo tutti i binari (es: ["1", "2"])
        if preferred.isEmpty {
            return allPlatforms
        }
        
        // Costruiamo la lista finale: prima i preferiti (evitando duplicati), poi gli altri come alternative
        var finalList: [String] = []
        for p in preferred {
            if !finalList.contains(p) { finalList.append(p) }
        }
        
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



