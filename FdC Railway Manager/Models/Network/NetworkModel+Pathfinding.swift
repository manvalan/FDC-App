import Foundation

extension NetworkModel {
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
            // Post-migration, paired single edges are directed (pairedEdgeId != nil).
            // Only original unpaired single-track edges remain undirected.
            let isUndirected = edge.trackType == .single && edge.pairedEdgeId == nil
            if ignoreDirection {
                adj[edge.from, default: []].append(edge)
                adj[edge.to, default: []].append(edge)
            } else if isReverse {
                adj[edge.to, default: []].append(edge)
                if isUndirected { adj[edge.from, default: []].append(edge) }
            } else {
                adj[edge.from, default: []].append(edge)
                if isUndirected { adj[edge.to, default: []].append(edge) }
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

    /// Reconstructs an ordered, topologically valid node sequence for a line.
    ///
    /// Given an unordered or partially-ordered list of node IDs (e.g. the
    /// user's tap-selection order), iterates consecutive pairs and fills in
    /// the shortest path between each pair via Dijkstra, including any
    /// intermediate junction nodes not present in the original list.
    ///
    /// Idempotent: calling it on an already-ordered sequence returns the
    /// same sequence unchanged.
    ///
    /// Fallback: if no path exists between a pair, the destination node is
    /// appended at the current position without advancing distance — same
    /// semantics as the gap-case in `LineProfilePoint.buildProfile`.
    ///
    /// - Returns: Ordered node IDs with intermediate junctions inserted.
    static nonisolated func buildOrderedPath(
        through nodeIds: [String],
        nodes: [Node],
        edges: [Edge]
    ) -> [String] {
        guard nodeIds.count >= 2 else { return nodeIds }
        var result: [String] = [nodeIds[0]]
        for i in 0 ..< nodeIds.count - 1 {
            let current = nodeIds[i]
            let next    = nodeIds[i + 1]
            guard let (segment, _) = findShortestPath(
                from: current, to: next,
                nodes: nodes, edges: edges
            ) else {
                // No path: append next directly (gap, distance unknown).
                if result.last != next { result.append(next) }
                continue
            }
            for nodeId in segment.dropFirst() {
                if result.last != nodeId { result.append(nodeId) }
            }
        }
        // Remove duplicates that arise from overlapping Dijkstra segments
        // (e.g. A→C passes through B, then B→D backtracks over A or C).
        // Keeps first occurrence; loops have no meaning on a railway line.
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }
}
