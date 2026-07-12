import Foundation

/// Snapshot immutabile della topologia di rete per calcoli puri
/// (scheduling, pathfinding, cinematica).
/// Functional Core: nessuna dipendenza da ObservableObject o MainActor.
public struct RailwayTopology: Equatable, Sendable {
    public let nodes: [Node]
    public let edges: [Edge]

    public init(nodes: [Node] = [], edges: [Edge] = []) {
        self.nodes = nodes
        self.edges = edges
    }

    public func node(id: String) -> Node? {
        nodes.first { $0.id == id }
    }

    public func findPathEdges(
        from startId: String,
        to endId: String
    ) -> [Edge]? {
        NetworkPathfinder.findPathEdges(
            from: startId,
            to: endId,
            nodes: nodes,
            edges: edges
        )
    }

    public func calculatePathDistance(path: [String]) -> Double {
        NetworkPathfinder.calculatePathDistance(path: path, edges: edges)
    }
}
