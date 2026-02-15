import Foundation
import Combine
import SwiftUI

/// Infrastructure: Rete fisica della ferrovia (Stazioni, Bivi, Binari)
@MainActor
final class NetworkModel: ObservableObject {
    @Published var name: String = "My Network"
    @Published var nodes: [Node] = []
    @Published var edges: [Edge] = []
    
    /// Global system owner
    weak var owner: RailroadNetwork?
    
    var sortedNodes: [Node] {
        nodes.sorted { $0.name < $1.name }
    }
    
    var sortedEdges: [Edge] {
        edges.sorted { e1, e2 in
            let name1 = findNode(id: e1.from)?.name ?? ""
            let name2 = findNode(id: e2.from)?.name ?? ""
            return name1 < name2
        }
    }
    
    init(nodes: [Node] = [], edges: [Edge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
    
    // MARK: - Humane Methods (Domain Driven Design)
    
    func allStations() -> [Node] {
        nodes.filter { $0.type == .station || $0.type == .interchange }
    }
    
    func allJunctions() -> [Node] {
        nodes.filter { $0.type == .junction }
    }
    
    func findNode(id: String) -> Node? {
        nodes.first(where: { $0.id == id })
    }
    
    func findEdge(from: String, to: String) -> Edge? {
        edges.first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) })
    }
    
    // MARK: - Pathfinding logic
    
    func findPathEdges(from startId: String, to endId: String, ignoreDirection: Bool = false, restrictIntermediateStations: Bool = false) -> [Edge]? {
        return NetworkModel.findPathEdges(from: startId, to: endId, nodes: nodes, edges: edges, ignoreDirection: ignoreDirection, restrictIntermediateStations: restrictIntermediateStations)
    }
    
    static nonisolated func findPathEdges(from startId: String, to endId: String, nodes: [Node], edges: [Edge], ignoreDirection: Bool = false, restrictIntermediateStations: Bool = false) -> [Edge]? {
        guard let (pathNodes, _) = findShortestPath(from: startId, to: endId, nodes: nodes, edges: edges, ignoreDirection: ignoreDirection, restrictIntermediateStations: restrictIntermediateStations) else { return nil }
        var pathEdges: [Edge] = []
        for i in 0..<pathNodes.count - 1 {
            let u = pathNodes[i]
            let v = pathNodes[i+1]
            if let edge = edges.first(where: { ($0.from == u && $0.to == v) || ($0.from == v && $0.to == u) }) {
                pathEdges.append(edge)
            }
        }
        return pathEdges
    }
    
    func findShortestPath(from start: String, to end: String, ignoreDirection: Bool = false, restrictIntermediateStations: Bool = false) -> ([String], Double)? {
        return NetworkModel.findShortestPath(from: start, to: end, nodes: nodes, edges: edges, ignoreDirection: ignoreDirection, restrictIntermediateStations: restrictIntermediateStations)
    }
    
    func findAlternativePaths(from start: String, to end: String) -> [(path: [String], distance: Double, description: String)] {
        return NetworkModel.findAlternativePaths(from: start, to: end, nodes: nodes, edges: edges)
    }

    // Static implementations to allow non-isolated computation
    static nonisolated func findAlternativePaths(from start: String, to end: String, nodes: [Node], edges: [Edge]) -> [(path: [String], distance: Double, description: String)] {
        var results: [(path: [String], distance: Double, description: String)] = []
        
        if let shortest = findShortestPath(from: start, to: end, nodes: nodes, edges: edges) {
            results.append((shortest.0, shortest.1, "Rapido"))
            
            if shortest.0.count > 2 {
                let penalizedEdges = edges.map { edge -> Edge in
                    var newEdge = edge
                    let isPartOfShortest = (0..<shortest.0.count-1).contains { i in
                        (edge.from == shortest.0[i] && edge.to == shortest.0[i+1]) ||
                        (edge.to == shortest.0[i] && edge.from == shortest.0[i+1])
                    }
                    if isPartOfShortest {
                        newEdge.distance *= 2.0 
                    }
                    return newEdge
                }
                
                if let alt = findShortestPath(from: start, to: end, nodes: nodes, edges: penalizedEdges) {
                    if alt.0 != shortest.0 {
                        let trueDist = calculatePathDistance(path: alt.0, edges: edges)
                        results.append((alt.0, trueDist, "Alternativo"))
                    }
                }
            }
            
            if results.count < 3 && shortest.0.count > 3 {
                 let midIdx = shortest.0.count / 2
                 let excludedNode = shortest.0[midIdx]
                 let restrictedNodes = nodes.filter { $0.id != excludedNode }
                 if let alt2 = findShortestPath(from: start, to: end, nodes: restrictedNodes, edges: edges) {
                     if !results.contains(where: { $0.path == alt2.0 }) {
                         results.append((alt2.0, alt2.1, "Panoramico"))
                     }
                 }
            }
        }
        return results
    }
    
    // MARK: - Mutation Methods (with Undo support)
    
    func addNode(_ node: Node) {
        createCheckpoint()
        nodes.append(node)
    }
    
    func addEdge(_ edge: Edge) {
        createCheckpoint()
        var newEdge = edge
        if newEdge.segments.isEmpty {
            InfrastructureManager.shared.processNetwork(self)
        }
        edges.append(newEdge)
    }
    
    func removeNode(_ id: String) {
        createCheckpoint()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
    }
    
    func removeEdge(from: String, to: String) {
        createCheckpoint()
        edges.removeAll { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }
    }
    
    func createCheckpoint() {
        owner?.createCheckpoint()
    }
    
    var canUndo: Bool { owner?.canUndo ?? false }
    var canRedo: Bool { owner?.canRedo ?? false }
    
    func undo() { owner?.undo() }
    func redo() { owner?.redo() }
    
    func isTrackAllowed(stationId: String, track: String?, lineId: String, prevStationId: String?, nextStationId: String?) -> Bool {
        guard let node = findNode(id: stationId) else { return true }
        return node.isTrackAllowed(track: track, lineId: lineId, prevStationId: prevStationId, nextStationId: nextStationId)
    }
    
    func getConnectedNodeIds(for nodeId: String) -> [String] {
        return edges.compactMap { edge -> String? in
            if edge.from == nodeId { return edge.to }
            if edge.to == nodeId { return edge.from }
            return nil
        }
    }

    func getNeighborStations(for nodeId: String) -> [String] {
        var neighbors = Set<String>()
        var visited = Set<String>([nodeId])
        var queue = getConnectedNodeIds(for: nodeId)
        
        while !queue.isEmpty {
            let currentId = queue.removeFirst()
            if visited.contains(currentId) { continue }
            visited.insert(currentId)
            
            if let node = findNode(id: currentId) {
                if node.type == .station || node.type == .interchange {
                    neighbors.insert(currentId)
                } else {
                    let nextLevel = getConnectedNodeIds(for: currentId)
                    queue.append(contentsOf: nextLevel)
                }
            }
        }
        return Array(neighbors)
    }
    
    func calculatePathDistance(path: [String]) -> Double {
        return NetworkModel.calculatePathDistance(path: path, edges: edges)
    }
    
    // MARK: - Pathfinding Algorithms
    
    static nonisolated func dijkstraAll(from start: String, nodes: [Node], edges: [Edge], isReverse: Bool = false, ignoreDirection: Bool = false, restrictIntermediateStations: Bool = false) -> (distances: [String: Double], previous: [String: String]) {
        var distances = [String: Double]()
        var previous = [String: String]()
        
        // Fast lookup for node types
        var stationNodes = Set<String>()
        if restrictIntermediateStations {
            for n in nodes {
                if n.type == .station || n.type == .interchange {
                    stationNodes.insert(n.id)
                }
            }
        }
        
        let adj: [String: [Edge]] = {
            var tempAdj = [String: [Edge]]()
            for edge in edges {
                if ignoreDirection {
                    tempAdj[edge.from, default: []].append(edge)
                    tempAdj[edge.to, default: []].append(edge)
                } else if isReverse {
                    tempAdj[edge.to, default: []].append(edge)
                    if edge.trackType == .single { tempAdj[edge.from, default: []].append(edge) }
                } else {
                    tempAdj[edge.from, default: []].append(edge)
                    if edge.trackType == .single { tempAdj[edge.to, default: []].append(edge) }
                }
            }
            return tempAdj
        }()
        
        for node in nodes { distances[node.id] = Double.infinity }
        distances[start] = 0
        
        var candidates: [String] = [start]
        var visited = Set<String>()
        
        while !candidates.isEmpty {
            var minIndex = -1
            var minDistance = Double.infinity
            
            for (i, node) in candidates.enumerated() {
                let d = distances[node] ?? .infinity
                if d < minDistance {
                    minDistance = d
                    minIndex = i
                }
            }
            if minIndex == -1 { break }
            let current = candidates.remove(at: minIndex)
            if visited.contains(current) { continue }
            visited.insert(current)
            
            // Constraint: If restricted, do not expand THROUGH a station (unless it's start)
            if restrictIntermediateStations && current != start && stationNodes.contains(current) {
                continue
            }
            
            let dist = distances[current] ?? .infinity
            if dist == .infinity { break }
            
            let neighbors = adj[current] ?? []
            for edge in neighbors {
                let neighborId = (ignoreDirection || !isReverse) ? (edge.from == current ? edge.to : edge.from) : (edge.to == current ? edge.from : edge.to)
                
                // Extra check for ignoreDirection logic mapping (if using undirected graph, neighbor is the other end)
                // The above ternary handles:
                // if ignoreDirection: generic neighbor
                // else if isReverse: (to->from)
                // else: (from->to)
                // Note: The 'adj' construction already filtered edges based on directionality.
                // However, 'adj' stores the edge object. We need to identify 'neighborId'.
                // If ignoreDirection=true, adj contains both directions.
                
                let actualNeighborId = (edge.from == current) ? edge.to : edge.from
                
                if visited.contains(actualNeighborId) { continue }
                
                let alt = dist + edge.distance
                if alt < (distances[actualNeighborId] ?? .infinity) {
                    distances[actualNeighborId] = alt
                    previous[actualNeighborId] = current
                    candidates.append(actualNeighborId)
                }
            }
        }
        return (distances, previous)
    }
    
    static nonisolated func findShortestPath(from start: String, to end: String, nodes: [Node], edges: [Edge], ignoreDirection: Bool = false, restrictIntermediateStations: Bool = false) -> ([String], Double)? {
        let (distances, previous) = dijkstraAll(from: start, nodes: nodes, edges: edges, ignoreDirection: ignoreDirection, restrictIntermediateStations: restrictIntermediateStations)
        if (distances[end] ?? .infinity) == .infinity { return nil }
        
        var path: [String] = []
        var u: String? = end
        while let node = u, node != start {
            path.append(node)
            u = previous[node]
        }
        if u == start {
            path.append(start)
            path.reverse()
            return (path, distances[end]!)
        }
        return nil
    }
    
    static nonisolated func calculatePathDistance(path: [String], edges: [Edge]) -> Double {
        guard path.count > 1 else { return 0.0 }
        var total = 0.0
        for i in 0..<(path.count - 1) {
            let from = path[i]
            let to = path[i+1]
            if let edge = edges.first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) {
                total += edge.distance
            }
        }
        return total
    }
}
