import Foundation
import Combine
import UniformTypeIdentifiers

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

// Rete ferroviaria (grafo)
class RailwayNetwork: ObservableObject, Codable {
    @Published var name: String
    @Published var nodes: [Node]
    @Published var edges: [Edge]

    enum CodingKeys: String, CodingKey {
        case name, nodes, edges
    }

    init(name: String, nodes: [Node] = [], edges: [Edge] = []) {
        self.name = name
        self.nodes = nodes
        self.edges = edges
    }

    // MARK: - Codable manuale per @Published
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let nodes = try container.decode([Node].self, forKey: .nodes)
        let edges = try container.decode([Edge].self, forKey: .edges)
        self.init(name: name, nodes: nodes, edges: edges)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(edges, forKey: .edges)
    }

    // MARK: - Gestione nodi e archi
    func addNode(_ node: Node) {
        nodes.append(node)
    }
    func addEdge(_ edge: Edge) {
        edges.append(edge)
    }
    // ...altre funzioni di gestione...

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
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    static func loadFromFile(url: URL) throws -> RailwayNetwork {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(RailwayNetwork.self, from: data)
    }
}
