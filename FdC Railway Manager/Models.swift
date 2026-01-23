import Foundation
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

// Nodo della rete ferroviaria (stazione o interscambio)
struct Node: Identifiable, Codable, Hashable {
    enum NodeType: String, Codable {
        case station, interchange, depot
    }
    let id: String // es: "MI"
    var name: String
    var type: NodeType
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
    var stations: [String] // IDs delle stazioni
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
            let neighbors = edges.filter { $0.from == current && unvisited.contains($0.to) }
            for edge in neighbors {
                let alt = (distances[current] ?? .infinity) + edge.distance
                if alt < (distances[edge.to] ?? .infinity) {
                    distances[edge.to] = alt
                    previous[edge.to] = current
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
