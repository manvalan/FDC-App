import Foundation

enum LinePathError: Error {
    case tooFewNodes
    case noEndpointsFound
    case pathNotFound
    case pathMissingNodes([String])
}

/// Pathfinding puro su topologia di rete (Dijkstra, distanze, ordinamento linee).
/// Functional Core: nessuna dipendenza da `NetworkModel` o UI.
enum NetworkPathfinder {

    static func findPathEdges(
        from startId: String,
        to endId: String,
        nodes: [Node],
        edges: [Edge],
        ignoreDirection: Bool = false,
        restrictIntermediateStations: Bool = false
    ) -> [Edge]? {
        guard let (pathNodes, _) = findShortestPath(
            from: startId, to: endId,
            nodes: nodes, edges: edges,
            ignoreDirection: ignoreDirection,
            restrictIntermediateStations: restrictIntermediateStations
        ) else { return nil }
        var pathEdges: [Edge] = []
        for i in 0..<pathNodes.count - 1 {
            let u = pathNodes[i]
            let v = pathNodes[i + 1]
            if let edge = edges.first(where: {
                ($0.from == u && $0.to == v) || ($0.from == v && $0.to == u)
            }) {
                pathEdges.append(edge)
            }
        }
        return pathEdges
    }

    static func findShortestPath(
        from start: String,
        to end: String,
        nodes: [Node],
        edges: [Edge],
        ignoreDirection: Bool = false,
        restrictIntermediateStations: Bool = false
    ) -> ([String], Double)? {
        let (distances, previous) = dijkstraAll(
            from: start, nodes: nodes, edges: edges,
            ignoreDirection: ignoreDirection,
            restrictIntermediateStations: restrictIntermediateStations
        )
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

    static func findAlternativePaths(
        from start: String,
        to end: String,
        nodes: [Node],
        edges: [Edge]
    ) -> [(path: [String], distance: Double, description: String)] {
        var results: [(path: [String], distance: Double, description: String)] = []

        if let shortest = findShortestPath(from: start, to: end, nodes: nodes, edges: edges) {
            results.append((shortest.0, shortest.1, "Rapido"))

            if shortest.0.count > 2 {
                let penalizedEdges = edges.map { edge -> Edge in
                    var newEdge = edge
                    let isPartOfShortest = (0..<shortest.0.count - 1).contains { i in
                        (edge.from == shortest.0[i] && edge.to == shortest.0[i + 1]) ||
                        (edge.to == shortest.0[i] && edge.from == shortest.0[i + 1])
                    }
                    if isPartOfShortest { newEdge.distance *= 2.0 }
                    return newEdge
                }

                if let alt = findShortestPath(from: start, to: end, nodes: nodes, edges: penalizedEdges),
                   alt.0 != shortest.0 {
                    let trueDist = calculatePathDistance(path: alt.0, edges: edges)
                    results.append((alt.0, trueDist, "Alternativo"))
                }
            }

            if results.count < 3 && shortest.0.count > 3 {
                let midIdx = shortest.0.count / 2
                let excludedNode = shortest.0[midIdx]
                let restrictedNodes = nodes.filter { $0.id != excludedNode }
                if let alt2 = findShortestPath(from: start, to: end, nodes: restrictedNodes, edges: edges),
                   !results.contains(where: { $0.path == alt2.0 }) {
                    results.append((alt2.0, alt2.1, "Panoramico"))
                }
            }
        }
        return results
    }

    static func calculatePathDistance(path: [String], edges: [Edge]) -> Double {
        guard path.count > 1 else { return 0.0 }
        var total = 0.0
        for i in 0..<(path.count - 1) {
            let from = path[i]
            let to = path[i + 1]
            if let edge = edges.first(where: {
                ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from)
            }) {
                total += edge.distance
            }
        }
        return total
    }

    static func findLineEndpoints(
        nodeIds: [String],
        edges: [Edge]
    ) -> (String, String)? {
        let nodeSet = Set(nodeIds)
        var neighbors: [String: Set<String>] = [:]
        for edge in edges where nodeSet.contains(edge.from) && nodeSet.contains(edge.to) {
            neighbors[edge.from, default: []].insert(edge.to)
            neighbors[edge.to, default: []].insert(edge.from)
        }
        let endpoints = nodeIds.filter { (neighbors[$0]?.count ?? 0) == 1 }
        guard endpoints.count == 2 else { return nil }
        return (endpoints[0], endpoints[1])
    }

    static func buildOrderedPath(
        through nodeIds: [String],
        nodes: [Node],
        edges: [Edge],
        lineName: String = ""
    ) -> [String] {
        guard nodeIds.count >= 2 else { return nodeIds }

        if let (capo1, capo2) = findLineEndpoints(nodeIds: nodeIds, edges: edges) {
            if !lineName.isEmpty {
                print("🔍 [Migration] '\(lineName)' endpoints: \(capo1) → \(capo2)")
            }
            if let (path, _) = findShortestPath(from: capo1, to: capo2, nodes: nodes, edges: edges) {
                let nodeSet = Set(nodeIds)
                if nodeSet.isSubset(of: Set(path)) {
                    if !lineName.isEmpty {
                        print("🔄 [Migration] '\(lineName)' reordered via endpoints: \(path.count) nodes")
                    }
                    return path
                }
                let missing = nodeIds.filter { !Set(path).contains($0) }
                if !lineName.isEmpty {
                    print("⚠️ [Migration] '\(lineName)' missing \(missing.count) node(s) — greedy fallback")
                }
            }
        }

        var result: [String] = [nodeIds[0]]
        for i in 0..<nodeIds.count - 1 {
            let current = nodeIds[i]
            let next = nodeIds[i + 1]
            guard let (segment, _) = findShortestPath(
                from: current, to: next, nodes: nodes, edges: edges
            ) else {
                if result.last != next { result.append(next) }
                continue
            }
            for nodeId in segment.dropFirst() where result.last != nodeId {
                result.append(nodeId)
            }
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }

    static func resolveLinePath(
        through selectedNodeIds: [String],
        nodes: [Node],
        edges: [Edge]
    ) -> Result<[String], LinePathError> {
        guard selectedNodeIds.count >= 2 else { return .failure(.tooFewNodes) }
        guard let (start, end) = findLineEndpoints(nodeIds: selectedNodeIds, edges: edges) else {
            return .failure(.noEndpointsFound)
        }
        guard let (path, _) = findShortestPath(
            from: start, to: end,
            nodes: nodes, edges: edges,
            ignoreDirection: true
        ) else {
            return .failure(.pathNotFound)
        }
        let missing = Set(selectedNodeIds).subtracting(Set(path))
        guard missing.isEmpty else { return .failure(.pathMissingNodes(Array(missing))) }
        return .success(path)
    }

    // MARK: - Dijkstra internals

    private static func dijkstraAll(
        from start: String,
        nodes: [Node],
        edges: [Edge],
        isReverse: Bool = false,
        ignoreDirection: Bool = false,
        restrictIntermediateStations: Bool = false
    ) -> (distances: [String: Double], previous: [String: String]) {
        var distances = [String: Double]()
        var previous = [String: String]()

        let stationNodes = restrictIntermediateStations
            ? Set(nodes.filter { $0.type == .station || $0.type == .interchange }.map(\.id))
            : Set<String>()
        let adj = buildAdjacencyList(edges: edges, isReverse: isReverse, ignoreDirection: ignoreDirection)

        for node in nodes { distances[node.id] = Double.infinity }
        distances[start] = 0

        var candidates: [String] = [start]
        var visited = Set<String>()

        while !candidates.isEmpty {
            guard let current = findMinDistanceNode(candidates: &candidates, distances: distances) else {
                break
            }
            if visited.contains(current) { continue }
            visited.insert(current)

            if restrictIntermediateStations && current != start && stationNodes.contains(current) {
                continue
            }

            relaxNeighbors(
                current: current, adj: adj, visited: visited,
                distances: &distances, previous: &previous, candidates: &candidates
            )
        }
        return (distances, previous)
    }

    private static func buildAdjacencyList(
        edges: [Edge],
        isReverse: Bool,
        ignoreDirection: Bool
    ) -> [String: [Edge]] {
        var adj = [String: [Edge]]()
        for edge in edges {
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

    private static func findMinDistanceNode(
        candidates: inout [String],
        distances: [String: Double]
    ) -> String? {
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

    private static func relaxNeighbors(
        current: String,
        adj: [String: [Edge]],
        visited: Set<String>,
        distances: inout [String: Double],
        previous: inout [String: String],
        candidates: inout [String]
    ) {
        guard let dist = distances[current], dist != .infinity else { return }
        for edge in adj[current] ?? [] {
            let neighborId = (edge.from == current) ? edge.to : edge.from
            if visited.contains(neighborId) { continue }
            let alt = dist + edge.distance
            if alt < (distances[neighborId] ?? .infinity) {
                distances[neighborId] = alt
                previous[neighborId] = current
                candidates.append(neighborId)
            }
        }
    }
}
