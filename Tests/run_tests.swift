import Foundation

// Minimal duplicate of data models for standalone testing
struct Node: Codable, Hashable {
    enum NodeType: String, Codable {
        case station, interchange, depot
    }
    let id: String
    var name: String
    var type: NodeType
    var latitude: Double?
    var longitude: Double?
    var capacity: Int?
    var platforms: Int?
}

struct Edge: Codable, Hashable {
    enum TrackType: String, Codable {
        case highSpeed, regional, single, double
    }
    var id: UUID = UUID()
    var from: String
    var to: String
    var distance: Double
    var trackType: TrackType
    var maxSpeed: Int
    var capacity: Int?
}

struct RailwayNetworkData: Codable {
    var name: String
    var nodes: [Node]
    var edges: [Edge]

    func findShortestPath(from start: String, to end: String) -> ([String], Double)? {
        var distances = [String: Double]()
        var previous = [String: String]()
        var unvisited = Set(nodes.map { $0.id })
        for node in nodes { distances[node.id] = Double.infinity }
        distances[start] = 0
        while !unvisited.isEmpty {
            guard let current = unvisited.min(by: { (a, b) in (distances[a] ?? .infinity) < (distances[b] ?? .infinity) }) else { break }
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

func runTests() -> Bool {
    var ok = true
    // Build a small network A->B->C
    let nA = Node(id: "A", name: "A", type: .station, latitude: nil, longitude: nil, capacity: nil, platforms: nil)
    let nB = Node(id: "B", name: "B", type: .station, latitude: nil, longitude: nil, capacity: nil, platforms: nil)
    let nC = Node(id: "C", name: "C", type: .station, latitude: nil, longitude: nil, capacity: nil, platforms: nil)
    let eAB = Edge(from: "A", to: "B", distance: 1.0, trackType: .regional, maxSpeed: 120, capacity: nil)
    let eBC = Edge(from: "B", to: "C", distance: 1.0, trackType: .regional, maxSpeed: 120, capacity: nil)
    let eAC = Edge(from: "A", to: "C", distance: 3.0, trackType: .regional, maxSpeed: 120, capacity: nil)
    let network = RailwayNetworkData(name: "TestNet", nodes: [nA, nB, nC], edges: [eAB, eBC, eAC])

    // Test pathfinder
    if let (path, dist) = network.findShortestPath(from: "A", to: "C") {
        print("Pathfinder result: path=\(path) dist=\(dist)")
        if path != ["A","B","C"] || abs(dist - 2.0) > 1e-6 {
            print("ERROR: unexpected pathfinder result")
            ok = false
        }
    } else {
        print("ERROR: pathfinder returned nil")
        ok = false
    }

    // Test encoding/decoding
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(network)
        print("Encoded JSON (truncated): \(String(data: data.prefix(200), encoding: .utf8) ?? "...")")
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RailwayNetworkData.self, from: data)
        if decoded.name != network.name || decoded.nodes.count != network.nodes.count || decoded.edges.count != network.edges.count {
            print("ERROR: mismatch after decode")
            ok = false
        }
    } catch {
        print("ERROR: encode/decode failed: \(error)")
        ok = false
    }

    return ok
}

let passed = runTests()
print("Tests \(passed ? "PASSED" : "FAILED")")
exit(passed ? 0 : 1)
