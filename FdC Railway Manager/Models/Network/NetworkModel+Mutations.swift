import Foundation

extension NetworkModel {
    // MARK: - Mutation Methods (with Undo support)
    
    func addNode(_ node: Node) {
        createCheckpoint()
        nodes.append(node)
    }
    
    func addEdge(_ edge: Edge) {
        createCheckpoint()
        edges.append(edge)
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
    

}
