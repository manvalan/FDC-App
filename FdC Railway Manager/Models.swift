import Foundation
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

// Nodo della rete ferroviaria (stazione o interscambio)
struct Node: Identifiable, Codable, Hashable {
    enum NodeType: String, Codable {
        case station, interchange, depot, junction
    }
    enum StationVisualType: String, Codable, CaseIterable, Identifiable {
        case filledStar = "Stella piena"
        case filledSquare = "Quadrato pieno"
        case emptySquare = "Quadrato vuoto"
        case filledCircle = "Cerchio pieno"
        case emptyCircle = "Cerchio vuoto"
        
        var id: String { self.rawValue }
    }
    let id: String // es: "MI"
    var name: String
    var type: NodeType
    var visualType: StationVisualType?
    var customColor: String?
    var latitude: Double?
    var longitude: Double?
    var capacity: Int?
    var platforms: Int?

    var parentHubId: String? // Groups multiple stations into one hub (e.g. MI Centrale + MI Centrale AV)
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, visualType, customColor, latitude, longitude, capacity, platforms, parentHubId
    }

    init(id: String, name: String, type: NodeType = .station, visualType: StationVisualType? = nil, customColor: String? = nil, latitude: Double? = nil, longitude: Double? = nil, capacity: Int? = nil, platforms: Int? = 2, parentHubId: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.visualType = visualType
        self.customColor = customColor
        self.latitude = latitude
        self.longitude = longitude
        self.capacity = capacity
        self.platforms = platforms
        self.parentHubId = parentHubId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        type = try container.decodeIfPresent(NodeType.self, forKey: .type) ?? .station
        visualType = try container.decodeIfPresent(StationVisualType.self, forKey: .visualType)
        customColor = try container.decodeIfPresent(String.self, forKey: .customColor)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        platforms = try container.decodeIfPresent(Int.self, forKey: .platforms) ?? 2
        parentHubId = try container.decodeIfPresent(String.self, forKey: .parentHubId)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // UI Helpers for consistent defaults
    var defaultVisualType: StationVisualType {
        if parentHubId != nil { return .filledSquare } // Hub is always a square
        switch type {
        case .interchange, .depot: return .filledSquare
        default: return .filledCircle
        }
    }
    
    var defaultColor: String {
        if parentHubId != nil { return "#FF3B30" } // Hub is always red
        switch type {
        case .interchange: return "#FF3B30" // Red
        case .depot: return "#FF9500" // Orange
        default: return "#000000" // Black
        }
    }
}

// Binario (arco del grafo)
struct Edge: Identifiable, Codable, Hashable {
    enum TrackType: String, Codable {
        case highSpeed, regional, single, double
    }
    var id: UUID = UUID()
    var from: String // id nodo di partenza
    var to: String   // id nodo di arrivo
    var distance: Double
    var trackType: TrackType
    var maxSpeed: Int
    var capacity: Int?

    enum CodingKeys: String, CodingKey {
        case id, from, to, distance, trackType, maxSpeed, capacity
    }

    init(id: UUID = UUID(), from: String, to: String, distance: Double, trackType: TrackType, maxSpeed: Int, capacity: Int? = nil) {
        self.id = id
        self.from = from
        self.to = to
        self.distance = distance
        self.trackType = trackType
        self.maxSpeed = maxSpeed
        self.capacity = capacity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 1.0
        trackType = try container.decodeIfPresent(TrackType.self, forKey: .trackType) ?? .regional
        maxSpeed = try container.decodeIfPresent(Int.self, forKey: .maxSpeed) ?? 120
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
    }
}

// Linea ferroviaria (insieme di stazioni con tempi di sosta) - Unificata con Relazione
struct RailwayLine: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: String? // ex: "#ff0000"
    var width: Double? // Line thickness in schematic view
    var originId: String = ""
    var destinationId: String = ""
    var stops: [RelationStop] = [] 
    
    var stations: [String] {
        stops.map { $0.stationId }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, width, originId, destinationId, stops
    }

    init(id: String, name: String, color: String? = nil, width: Double? = nil, originId: String = "", destinationId: String = "", stops: [RelationStop] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.width = width
        self.originId = originId
        self.destinationId = destinationId
        self.stops = stops
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Linea Senza Nome"
        color = try container.decodeIfPresent(String.self, forKey: .color)
        width = try container.decodeIfPresent(Double.self, forKey: .width)
        originId = try container.decodeIfPresent(String.self, forKey: .originId) ?? ""
        destinationId = try container.decodeIfPresent(String.self, forKey: .destinationId) ?? ""
        stops = try container.decodeIfPresent([RelationStop].self, forKey: .stops) ?? []
    }
}

// Fermata in una relazione (con tempo di sosta)
struct RelationStop: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stationId: String
    var minDwellTime: Int = 3 // Minuit di sosta base (default 3)
    var extraDwellTime: Double = 0 // Ritardo extra da AI (minuti)
    var isSkipped: Bool = false // Se true, il treno non ferma (transito)
    var track: String? // Binario programmato (es: "1")
    
    // Per treni specifici: orari pianificati (opzionali, sovrascrivono il calcolo)
    var plannedArrival: Date?
    var plannedDeparture: Date?
    
    // Campi calcolati per visualizzazione/validazione corrente
    var arrival: Date?
    var departure: Date?

    enum CodingKeys: String, CodingKey {
        case id, stationId, minDwellTime, extraDwellTime, isSkipped, track, plannedArrival, plannedDeparture, arrival, departure
    }

    init(id: UUID = UUID(), stationId: String, minDwellTime: Int = 3, extraDwellTime: Double = 0, isSkipped: Bool = false, track: String? = nil, plannedArrival: Date? = nil, plannedDeparture: Date? = nil, arrival: Date? = nil, departure: Date? = nil) {
        self.id = id
        self.stationId = stationId
        self.minDwellTime = minDwellTime
        self.extraDwellTime = extraDwellTime
        self.isSkipped = isSkipped
        self.track = track
        self.plannedArrival = plannedArrival
        self.plannedDeparture = plannedDeparture
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
        plannedArrival = try container.decodeIfPresent(Date.self, forKey: .plannedArrival)
        plannedDeparture = try container.decodeIfPresent(Date.self, forKey: .plannedDeparture)
        arrival = try container.decodeIfPresent(Date.self, forKey: .arrival)
        departure = try container.decodeIfPresent(Date.self, forKey: .departure)
    }
}


// Rete ferroviaria (grafo)
@MainActor
class RailwayNetwork: ObservableObject {
    @Published var name: String
    @Published var nodes: [Node]
    @Published var edges: [Edge]
    @Published var lines: [RailwayLine]

    init(name: String, nodes: [Node] = [], edges: [Edge] = [], lines: [RailwayLine] = []) {
        self.name = name
        self.nodes = nodes
        self.edges = edges
        self.lines = lines
    }

    // MARK: - Gestione nodi e archi
    func addNode(_ node: Node) {
        nodes.append(node)
    }
    func addEdge(_ edge: Edge) {
        edges.append(edge)
    }
    
    func removeNode(_ id: String) {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
    }
    
    func removeEdge(_ from: String, _ to: String) {
        edges.removeAll { $0.from == from && $0.to == to }
    }

    // MARK: - Pathfinding (Dijkstra base)
    func findShortestPath(from start: String, to end: String) -> ([String], Double)? {
        // Implementazione base Dijkstra
        var distances = [String: Double]()
        var previous = [String: String]()
        var unvisited = Set(nodes.map { $0.id })
        for node in nodes { distances[node.id] = Double.infinity }
        distances[start] = 0
        while !unvisited.isEmpty {
            let current = unvisited.min { (a, b) in (distances[a] ?? .infinity) < (distances[b] ?? .infinity) }!
            unvisited.remove(current)
            if current == end { break }
            let neighbors = edges.filter { edge in
                if edge.from == current && unvisited.contains(edge.to) { return true }
                if edge.trackType == .single && edge.to == current && unvisited.contains(edge.from) { return true }
                return false
            }
            
            for edge in neighbors {
                let neighborId = (edge.from == current) ? edge.to : edge.from
                let alt = (distances[current] ?? .infinity) + edge.distance
                if alt < (distances[neighborId] ?? .infinity) {
                    distances[neighborId] = alt
                    previous[neighborId] = current
                }
            }
        }
        // Ricostruisci percorso
        var path: [String] = []
        var u: String? = end
        while let node = u, node != start {
            path.insert(node, at: 0)
            u = previous[node]
        }
        if u == start { path.insert(start, at: 0) }
        else { return nil }
        return (path, distances[end] ?? .infinity)
    }

    // Calcolo percorsi alternativi (Diretto + Via Interscambi)
    func findAlternativePaths(from start: String, to end: String) -> [(path: [String], distance: Double, description: String)] {
        var alternatives: [(path: [String], distance: Double, description: String)] = []
        
        // 1. Percorso Diretto (Shortest)
        if let direct = findShortestPath(from: start, to: end) {
            alternatives.append((direct.0, direct.1, "Diretto"))
        }
        
        // 2. Via Interscambi
        let interchanges = nodes.filter { $0.type == .interchange && $0.id != start && $0.id != end }
        
        for mid in interchanges {
            if let p1 = findShortestPath(from: start, to: mid.id),
               let p2 = findShortestPath(from: mid.id, to: end) {
                
                // Combine paths
                var combinedPath = p1.0
                let leg2 = p2.0.dropFirst()
                
                // PIGNOLO PROTOCOL: Check for simple paths (no doubling back)
                let fullPath = combinedPath + Array(leg2)
                let uniqueNodes = Set(fullPath)
                
                if uniqueNodes.count == fullPath.count {
                    combinedPath.append(contentsOf: leg2)
                    let combinedDist = p1.1 + p2.1
                    
                    // Avoid duplicates (checking path content)
                    if !alternatives.contains(where: { $0.path == combinedPath }) {
                         alternatives.append((combinedPath, combinedDist, "Via \(mid.name)"))
                    }
                }
            }
        }
        
        // Sort by distance
        return alternatives.sorted { $0.distance < $1.distance }
    }
    
    // Support for per-edge travel logic
    func findPathEdges(from startId: String, to endId: String) -> [Edge]? {
        guard startId != endId else { return [] }
        
        var queue: [String] = [startId]
        var predecessors: [String: (String, Edge)] = [:]
        var visited: Set<String> = [startId]
        
        var head = 0
        while head < queue.count {
            let curr = queue[head]
            head += 1
            
            if curr == endId {
                // Reconstruct path
                var path: [Edge] = []
                var temp = curr
                while temp != startId {
                    if let (prev, edge) = predecessors[temp] {
                        path.insert(edge, at: 0)
                        temp = prev
                    } else { break }
                }
                return path
            }
            
            let outgoing = edges.filter { edge in
                if edge.from == curr { return true }
                if edge.trackType == .single && edge.to == curr { return true }
                return false
            }
            
            for edge in outgoing {
                let nextId = (edge.from == curr) ? edge.to : edge.from
                if !visited.contains(nextId) {
                    visited.insert(nextId)
                    predecessors[nextId] = (curr, edge)
                    queue.append(nextId)
                }
            }
        }
        return nil
    }
}

extension RailwayNetwork {
    static let fileType = UTType(exportedAs: "it.fdc.railwaynetwork")
    
    func saveToFile(url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let dto = self.toDTO()
        let data = try encoder.encode(dto)
        try data.write(to: url)
    }
    
    static func loadFromFile(url: URL) throws -> RailwayNetworkDTO {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(RailwayNetworkDTO.self, from: data)
    }
}
