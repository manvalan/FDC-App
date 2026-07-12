import Foundation

extension NetworkModel {
    // MARK: - Pathfinding (delegates to Domain)

    func findPathEdges(
        from startId: String,
        to endId: String,
        ignoreDirection: Bool = false,
        restrictIntermediateStations: Bool = false
    ) -> [Edge]? {
        NetworkPathfinder.findPathEdges(
            from: startId, to: endId,
            nodes: nodes, edges: edges,
            ignoreDirection: ignoreDirection,
            restrictIntermediateStations: restrictIntermediateStations
        )
    }

    func findShortestPath(
        from start: String,
        to end: String,
        ignoreDirection: Bool = false,
        restrictIntermediateStations: Bool = false
    ) -> ([String], Double)? {
        NetworkPathfinder.findShortestPath(
            from: start, to: end,
            nodes: nodes, edges: edges,
            ignoreDirection: ignoreDirection,
            restrictIntermediateStations: restrictIntermediateStations
        )
    }

    func findAlternativePaths(from start: String, to end: String)
        -> [(path: [String], distance: Double, description: String)] {
        NetworkPathfinder.findAlternativePaths(
            from: start, to: end, nodes: nodes, edges: edges
        )
    }

    static nonisolated func findPathEdges(
        from startId: String,
        to endId: String,
        nodes: [Node],
        edges: [Edge],
        ignoreDirection: Bool = false,
        restrictIntermediateStations: Bool = false
    ) -> [Edge]? {
        NetworkPathfinder.findPathEdges(
            from: startId, to: endId,
            nodes: nodes, edges: edges,
            ignoreDirection: ignoreDirection,
            restrictIntermediateStations: restrictIntermediateStations
        )
    }

    static nonisolated func findShortestPath(
        from start: String,
        to end: String,
        nodes: [Node],
        edges: [Edge],
        ignoreDirection: Bool = false,
        restrictIntermediateStations: Bool = false
    ) -> ([String], Double)? {
        NetworkPathfinder.findShortestPath(
            from: start, to: end,
            nodes: nodes, edges: edges,
            ignoreDirection: ignoreDirection,
            restrictIntermediateStations: restrictIntermediateStations
        )
    }

    static nonisolated func findAlternativePaths(
        from start: String,
        to end: String,
        nodes: [Node],
        edges: [Edge]
    ) -> [(path: [String], distance: Double, description: String)] {
        NetworkPathfinder.findAlternativePaths(
            from: start, to: end, nodes: nodes, edges: edges
        )
    }

    static nonisolated func calculatePathDistance(path: [String], edges: [Edge]) -> Double {
        NetworkPathfinder.calculatePathDistance(path: path, edges: edges)
    }

    static nonisolated func findLineEndpoints(
        nodeIds: [String],
        edges: [Edge]
    ) -> (String, String)? {
        NetworkPathfinder.findLineEndpoints(nodeIds: nodeIds, edges: edges)
    }

    static nonisolated func buildOrderedPath(
        through nodeIds: [String],
        nodes: [Node],
        edges: [Edge],
        lineName: String = ""
    ) -> [String] {
        NetworkPathfinder.buildOrderedPath(
            through: nodeIds, nodes: nodes, edges: edges, lineName: lineName
        )
    }

    static nonisolated func resolveLinePath(
        through selectedNodeIds: [String],
        nodes: [Node],
        edges: [Edge]
    ) -> Result<[String], LinePathError> {
        NetworkPathfinder.resolveLinePath(
            through: selectedNodeIds, nodes: nodes, edges: edges
        )
    }
}
