import Foundation
import Combine
import SwiftUI

/// Infrastructure: Rete fisica della ferrovia (Stazioni, Bivi, Binari)
@MainActor
final class NetworkModel: ObservableObject {
    @Published var name: String = "My Network"
    @Published var nodes: [Node] = []
    @Published var edges: [Edge] = [] {
        didSet { syncPairedControlPoints(changedFrom: oldValue) }
    }
    /// Physical infrastructure lines (ex `ferrovie`).
    @Published var lines: [RailwayLine] = []
    
    /// Global system owner
    weak var owner: RailroadNetwork?

    var topologyService: NetworkTopologyService {
        NetworkTopologyService(nodes: nodes, edges: edges)
    }

    var topology: RailwayTopology { topologyService.topology }

    var sortedNodes: [Node] { topologyService.sortedNodes() }

    var sortedEdges: [Edge] { topologyService.sortedEdges() }
    
    var sortedLines: [RailwayLine] {
        lines.sorted { $0.name < $1.name }
    }
    
    init(nodes: [Node] = [], edges: [Edge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
    
    // MARK: - Humane Methods (Domain Driven Design)
    
    func allStations() -> [Node] { topologyService.allStations() }

    func allJunctions() -> [Node] { topologyService.allJunctions() }

    func findNode(id: String) -> Node? { topologyService.findNode(id: id) }

    func findEdge(from: String, to: String) -> Edge? {
        topologyService.findEdge(from: from, to: to)
    }
    

    func createCheckpoint() {
        owner?.createCheckpoint()
    }

    /// Removes the most recent checkpoint without applying it.
    /// Call in the "Cancel" branch of an Alert when the model was never
    /// modified — discards the phantom checkpoint created at drag start.
    func discardLastCheckpoint() {
        owner?.discardLastCheckpoint()
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
        topologyService.getConnectedNodeIds(for: nodeId)
    }

    func getNeighborStations(for nodeId: String) -> [String] {
        topologyService.getNeighborStations(for: nodeId)
    }

    func calculatePathDistance(path: [String]) -> Double {
        topology.calculatePathDistance(path: path)
    }

    // MARK: - Paired Control-Point Sync

    /// Mirrors controlPoints onto the partner of any paired oriented edge
    /// whose controlPoints just changed (B→A gets the reversed A→B sequence).
    ///
    /// Uses `oldValue` to identify which edge changed — this prevents the
    /// symmetric iteration from overwriting the source with stale data.
    /// Terminates in at most two didSet calls: one to apply, one to confirm.
    private func syncPairedControlPoints(changedFrom old: [Edge]) {
        var oldById = [UUID: Edge]()
        for e in old { oldById[e.id] = e }
        var indexById = [UUID: Int]()
        for (i, e) in edges.enumerated() { indexById[e.id] = i }
        var copy = edges
        var didChange = false
        for edge in edges {
            guard let pairedId = edge.pairedEdgeId,
                  let j = indexById[pairedId],
                  let oldEdge = oldById[edge.id],
                  edge.controlPoints != oldEdge.controlPoints
            else { continue }
            let expected = Array(edge.controlPoints.reversed())
            guard copy[j].controlPoints != expected else { continue }
            copy[j].controlPoints = expected
            didChange = true
        }
        if didChange { edges = copy }
    }
}
