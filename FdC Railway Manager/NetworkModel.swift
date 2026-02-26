import Foundation
import Combine
import SwiftUI

/// Infrastructure: Rete fisica della ferrovia (Stazioni, Bivi, Binari)
@MainActor
final class NetworkModel: ObservableObject {
    @Published var name: String = "My Network"
    @Published var nodes: [Node] = []
    @Published var edges: [Edge] = []
    /// Physical infrastructure lines (ex `ferrovie`).
    @Published var lines: [RailwayLine] = []
    /// Service-route templates used for schedule creation (ex `lines`).
    @Published var routes: [TrainRoute] = []
    
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
    
    var sortedLines: [RailwayLine] {
        lines.sorted { $0.name < $1.name }
    }
    
    var sortedRoutes: [TrainRoute] {
        routes.sorted { $0.name < $1.name }
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
    
    // MARK: - Infrastructure Updates
    
    func updateNode(_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil) {
        if let idx = nodes.firstIndex(where: { $0.id == id }) {
            var node = nodes[idx]
            if let lat = lat { node.latitude = lat }
            if let lon = lon { node.longitude = lon }
            if let alt = alt { node.altitude = alt }
            nodes[idx] = node
        }
    }

    func updateEdge(_ id: UUID, distance: Double? = nil, speed: Int? = nil) {
        owner?.createCheckpoint()
        if let idx = edges.firstIndex(where: { $0.id == id }) {
            var edge = edges[idx]
            if let d = distance { edge.distance = d }
            if let s = speed { edge.maxSpeed = s }
            edges[idx] = edge
        }
    }
    
    func generateSegments(for edge: Edge) {
        if let idx = edges.firstIndex(where: { $0.id == edge.id }) {
            var newEdge = edge
            let segmentLength = 2.0 
            let count = max(1, Int(ceil(edge.distance / segmentLength)))
            var segments: [TrackSegment] = []
            
            for i in 0..<count {
                let len = (i == count - 1) ? (edge.distance - Double(i) * segmentLength) : segmentLength
                segments.append(TrackSegment(
                    order: i,
                    length: len,
                    speedLimit: edge.maxSpeed
                ))
            }
            newEdge.segments = segments
            edges[idx] = newEdge
        }
    }
    
    func updateSegment(_ edgeId: UUID, index: Int, speed: Double) {
        if let idx = edges.firstIndex(where: { $0.id == edgeId }) {
            var edge = edges[idx]
            if index < edge.segments.count {
                var seg = edge.segments[index]
                seg.speedLimit = Int(speed)
                edge.segments[index] = seg
                edges[idx] = edge
            }
        }
    }
    
    func splitEdge(_ edge: Edge) {
        owner?.createCheckpoint()
        guard let n1 = nodes.first(where: { $0.id == edge.from }),
              let n2 = nodes.first(where: { $0.id == edge.to }) else { return }
              
        let lat1 = n1.latitude ?? 0; let lon1 = n1.longitude ?? 0
        let lat2 = n2.latitude ?? 0; let lon2 = n2.longitude ?? 0
        let midLat = (lat1 + lat2) / 2; let midLon = (lon1 + lon2) / 2
        let midAlt = ((n1.altitude ?? 0) + (n2.altitude ?? 0)) / 2
        
        let checkpointId = "CP-\(Int.random(in: 1000...9999))"
        let newNode = Node(
            id: checkpointId,
            name: "Checkpoint \(checkpointId)",
            type: .junction,
            latitude: midLat,
            longitude: midLon,
            altitude: midAlt
        )
        
        addNode(newNode)
        removeEdge(edge.id)
        
        let d1 = edge.distance / 2.0
        addEdge(Edge(from: edge.from, to: newNode.id, distance: d1, trackType: edge.trackType, maxSpeed: edge.maxSpeed))
        addEdge(Edge(from: newNode.id, to: edge.to, distance: d1, trackType: edge.trackType, maxSpeed: edge.maxSpeed))
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
    
    func removeEdge(_ id: UUID) {
        createCheckpoint()
        edges.removeAll { $0.id == id }
    }
    
    func createCheckpoint() {
        owner?.createCheckpoint()
    }
    
    var canUndo: Bool { owner?.canUndo ?? false }
    var canRedo: Bool { owner?.canRedo ?? false }
    
    func undo() { owner?.undo() }
    func redo() { owner?.redo() }
    
    func isTrackAllowed(stationId: String, track: String?, routeId: String, prevStationId: String?, nextStationId: String?) -> Bool {
        guard let node = findNode(id: stationId) else { return true }
        return node.isTrackAllowed(track: track, routeId: routeId, prevStationId: prevStationId, nextStationId: nextStationId)
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
        
        let stationNodes = restrictIntermediateStations ? getStationNodeIds(nodes: nodes) : Set<String>()
        let adj = buildAdjacencyList(edges: edges, isReverse: isReverse, ignoreDirection: ignoreDirection)
        
        for node in nodes { distances[node.id] = Double.infinity }
        distances[start] = 0
        
        var candidates: [String] = [start]
        var visited = Set<String>()
        
        while !candidates.isEmpty {
            guard let current = findMinDistanceNode(candidates: &candidates, distances: distances) else { break }
            if visited.contains(current) { continue }
            visited.insert(current)
            
            // Constraint: If restricted, do not expand THROUGH a station (unless it's start)
            if restrictIntermediateStations && current != start && stationNodes.contains(current) {
                continue
            }
            
            relaxNeighbors(current: current, adj: adj, visited: visited, distances: &distances, previous: &previous, candidates: &candidates)
        }
        return (distances, previous)
    }

    private static nonisolated func getStationNodeIds(nodes: [Node]) -> Set<String> {
        return Set(nodes.filter { $0.type == .station || $0.type == .interchange }.map { $0.id })
    }

    private static nonisolated func buildAdjacencyList(edges: [Edge], isReverse: Bool, ignoreDirection: Bool) -> [String: [Edge]] {
        var adj = [String: [Edge]]()
        for edge in edges {
            if ignoreDirection {
                adj[edge.from, default: []].append(edge)
                adj[edge.to, default: []].append(edge)
            } else if isReverse {
                adj[edge.to, default: []].append(edge)
                if edge.trackType == .single { adj[edge.from, default: []].append(edge) }
            } else {
                adj[edge.from, default: []].append(edge)
                if edge.trackType == .single { adj[edge.to, default: []].append(edge) }
            }
        }
        return adj
    }

    private static nonisolated func findMinDistanceNode(candidates: inout [String], distances: [String: Double]) -> String? {
        var minIndex = -1
        var minDistance = Double.infinity
        
        for (i, node) in candidates.enumerated() {
            let d = distances[node] ?? .infinity
            if d < minDistance {
                minDistance = d
                minIndex = i
            }
        }
        
        return minIndex != -1 ? candidates.remove(at: minIndex) : nil
    }

    private static nonisolated func relaxNeighbors(current: String,
                                                 adj: [String: [Edge]],
                                                 visited: Set<String>,
                                                 distances: inout [String: Double],
                                                 previous: inout [String: String],
                                                 candidates: inout [String]) {
        guard let dist = distances[current], dist != .infinity else { return }
        
        let neighbors = adj[current] ?? []
        for edge in neighbors {
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
