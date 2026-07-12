import Foundation

/// Query e calcoli geometrici puri sulla topologia di rete.
/// Functional Core: nessuna mutazione, nessuna dipendenza da UI o undo.
public struct NetworkTopologyService: Sendable {
    public let topology: RailwayTopology

    public init(topology: RailwayTopology) {
        self.topology = topology
    }

    public init(nodes: [Node], edges: [Edge]) {
        self.topology = RailwayTopology(nodes: nodes, edges: edges)
    }

    public var nodes: [Node] { topology.nodes }
    public var edges: [Edge] { topology.edges }

    public func findNode(id: String) -> Node? {
        topology.node(id: id)
    }

    public func findEdge(from: String, to: String) -> Edge? {
        edges.first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) })
    }

    public func allStations() -> [Node] {
        nodes.filter { $0.type == .station || $0.type == .interchange }
    }

    public func allJunctions() -> [Node] {
        nodes.filter { $0.type == .junction }
    }

    public func sortedNodes() -> [Node] {
        nodes.sorted { $0.name < $1.name }
    }

    public func sortedEdges() -> [Edge] {
        edges.sorted { e1, e2 in
            let name1 = findNode(id: e1.from)?.name ?? ""
            let name2 = findNode(id: e2.from)?.name ?? ""
            return name1 < name2
        }
    }

    public func getConnectedNodeIds(for nodeId: String) -> [String] {
        edges.compactMap { edge -> String? in
            if edge.from == nodeId { return edge.to }
            if edge.to == nodeId { return edge.from }
            return nil
        }
    }

    public func getNeighborStations(for nodeId: String) -> [String] {
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
                    queue.append(contentsOf: getConnectedNodeIds(for: currentId))
                }
            }
        }
        return Array(neighbors)
    }

    /// Distanza in km tra due nodi (coordinate effettive, hub-aware).
    public func calculateDistance(from n1: Node, to n2: Node) -> Double {
        let eff1Lat = effectiveLatitude(for: n1)
        let eff1Lon = effectiveLongitude(for: n1)
        let eff2Lat = effectiveLatitude(for: n2)
        let eff2Lon = effectiveLongitude(for: n2)

        let dLat = eff1Lat - eff2Lat
        let dLon = eff1Lon - eff2Lon
        if dLat == 0 && dLon == 0 { return 0.0 }

        let dist = sqrt(dLat * dLat + dLon * dLon) * RailwayConstants.degreesToKm
        return max(0.1, round(dist * 10) / 10.0)
    }

    private func effectiveLatitude(for node: Node) -> Double {
        if let pid = node.parentHubId, let parent = findNode(id: pid) {
            return parent.latitude ?? 0
        }
        return node.latitude ?? 0
    }

    private func effectiveLongitude(for node: Node) -> Double {
        if let pid = node.parentHubId, let parent = findNode(id: pid) {
            return parent.longitude ?? 0
        }
        return node.longitude ?? 0
    }
}
