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

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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
}

// Linea ferroviaria (insieme di stazioni)
struct RailwayLine: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: String? // ex: "#ff0000"
    var width: Double? // Line thickness in schematic view
    var stations: [String] // IDs delle stazioni
}

// Fermata in una relazione (con tempo di sosta)
struct RelationStop: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stationId: String
    var minDwellTime: Int = 3 // Minuti di sosta (default 3)
    var extraDwellTime: Double = 0 // Extra delay from AI (minutes)
    var isSkipped: Bool = false // Se true, il treno non ferma (transito)
    var track: String? // Binario programmato (es: "1", "2", "1 Tronco")
    
    // Cached calculation for persistence/display
    var arrival: Date?
    var departure: Date?
}

// Relazione Treno (Template di itinerario)
struct TrainRelation: Identifiable, Codable, Hashable {
    let id: UUID
    var lineId: String
    var name: String
    var originId: String
    var destinationId: String
    var stops: [RelationStop] // Updated from [String]
}

// Rete ferroviaria (grafo)
@MainActor
class RailwayNetwork: ObservableObject {
    @Published var name: String
    @Published var nodes: [Node]
    @Published var edges: [Edge]
    @Published var lines: [RailwayLine]
    @Published var relations: [TrainRelation]

    init(name: String, nodes: [Node] = [], edges: [Edge] = [], lines: [RailwayLine] = [], relations: [TrainRelation] = []) {
        self.name = name
        self.nodes = nodes
        self.edges = edges
        self.lines = lines
        self.relations = relations
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
        var queue: [(id: String, path: [Edge])] = [(startId, [])]
        var visited: Set<String> = [startId]
        
        while !queue.isEmpty {
            let (curr, path) = queue.removeFirst()
            if curr == endId { return path }
            
            let outgoing = edges.filter { edge in
                if edge.from == curr { return true }
                if edge.trackType == .single && edge.to == curr { return true }
                return false
            }
            
            for edge in outgoing {
                let nextId = (edge.from == curr) ? edge.to : edge.from
                if !visited.contains(nextId) {
                    visited.insert(nextId)
                    var newPath = path
                    newPath.append(edge)
                    queue.append((nextId, newPath))
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
