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
    

}
