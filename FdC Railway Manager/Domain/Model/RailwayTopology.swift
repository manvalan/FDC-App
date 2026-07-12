import Foundation

/// Snapshot immutabile della topologia di rete per calcoli puri
/// (scheduling, pathfinding, cinematica).
/// Functional Core: nessuna dipendenza da ObservableObject o MainActor.
struct RailwayTopology: Equatable, Sendable {
    let nodes: [Node]
    let edges: [Edge]

    init(nodes: [Node] = [], edges: [Edge] = []) {
        self.nodes = nodes
        self.edges = edges
    }

    init(network: NetworkModel) {
        self.nodes = network.nodes
        self.edges = network.edges
    }

    func node(id: String) -> Node? {
        nodes.first { $0.id == id }
    }

    func findPathEdges(
        from startId: String,
        to endId: String
    ) -> [Edge]? {
        NetworkModel.findPathEdges(
            from: startId,
            to: endId,
            nodes: nodes,
            edges: edges
        )
    }

    func calculatePathDistance(path: [String]) -> Double {
        NetworkModel.calculatePathDistance(path: path, edges: edges)
    }
}
