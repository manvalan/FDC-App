import Foundation
import Combine
import SwiftUI

/// The central class for the Railway Manager system.
/// Orchestrates the different sub-systems (Network, Lines, Settings, I/O, AI).
@MainActor
final class RailroadNetwork: ObservableObject {
    
    // MARK: - Sub-Systems
    
    /// Network: Tutto quello che si riferisce alla rete fisica (Stazioni, Binari, ecc.)
    @Published var network: NetworkModel
    @Published var topologyId: Int = 0
    
    /// Linee: Le linee di servizio percorse dai treni (Lines, Trains)
    @Published var lines: LinesManager
    
    /// Impostazioni: Dati di setup
    @Published var settings: SettingsManager
    
    /// I/O: Input/Output operations
    var io: IOManager
    
    /// AI: Artificial Intelligence modules
    var ai: AIManager
    
    private var cancellables = Set<AnyCancellable>()
    
    private let infrastructureManager = InfrastructureManager()
    
    // MARK: - Init
    
    init() {
        let newNetwork = NetworkModel()
        let newLines = LinesManager(network: newNetwork)
        
        self.network = newNetwork
        self.lines = newLines
        self.settings = SettingsManager()
        self.io = IOManager()
        self.ai = AIManager()
        
        // Link sub-systems
        self.network.owner = self
        self.lines.owner = self
        self.io.railroad = self
        self.ai.railroad = self
        
        // Propagate changes
        self.network.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        self.lines.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        self.settings.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        
        // Auto-refresh topology when technical data changes (coords, etc)
        // We use debounce to avoid flooding during multi-edits
        self.network.$nodes
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.forceUpdateTopology() }
            .store(in: &cancellables)
    }
    
    // MARK: - Global Undo/Redo System
    
    struct RailroadSnapshot: Equatable {
        let nodes: [RailwayNode]
        let edges: [Edge]
        let ferrovie: [RailwayLine]
        let lines: [TrainRoute]
        let trains: [RailwayTrain]
        let vehicles: [RailwayVehicle]
    }
    
    private var undoStack: [RailroadSnapshot] = []
    private var redoStack: [RailroadSnapshot] = []
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Empties the undo/redo stacks. Call after any bulk load so the user
    /// cannot undo past the freshly-loaded state.
    func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Removes the most recent checkpoint from the undo stack without
    /// applying it. Use this to discard a "phantom" checkpoint created at
    /// the start of a drag gesture when the user subsequently cancels the
    /// operation (e.g., via an Alert) and the model was never modified.
    func discardLastCheckpoint() {
        guard !undoStack.isEmpty else { return }
        undoStack.removeLast()
    }
    
    func createCheckpoint() {
        let snapshot = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
            ferrovie: network.lines,
            lines: lines.lines,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        if undoStack.last != snapshot {
            undoStack.append(snapshot)
            if undoStack.count > 50 { undoStack.removeFirst() }
            redoStack.removeAll()
            topologyId += 1
        }
    }
    
    func undo() {
        guard let last = undoStack.popLast() else { return }
        let current = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
            ferrovie: network.lines,
            lines: lines.lines,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        redoStack.append(current)
        applySnapshot(last)
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        let current = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
            ferrovie: network.lines,
            lines: lines.lines,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        undoStack.append(current)
        applySnapshot(next)
    }
    
    private func applySnapshot(_ snapshot: RailroadSnapshot) {
        network.nodes = snapshot.nodes
        network.edges = snapshot.edges
        network.lines = snapshot.ferrovie
        lines.lines = snapshot.lines
        lines.trains = snapshot.trains
        lines.vehicles = snapshot.vehicles
        lines.validateSchedules()
        topologyId += 1
        objectWillChange.send()
    }
    
    func forceUpdateTopology() {
        topologyId += 1
    }

    /// Rigenera i segmenti di blocco sull'infrastruttura di rete.
    func processInfrastructure() {
        infrastructureManager.processNetwork(network)
    }

    /// Adds an edge to the network and generates its track segments.
    /// Segments are an Infrastructure concern — this shell method keeps Domain clean.
    func addEdge(_ edge: Edge) {
        network.addEdge(edge)
        infrastructureManager.processNetwork(network)
    }

    /// Atomically adds one edge (or a paired A→B / B→A pair) with a
    /// single undo checkpoint. Use this instead of `addEdge(_:)` when
    /// creating edges from the UI, so that paired creation is undone in
    /// one step.
    func addEdge(
        from: String,
        to: String,
        distance: Double,
        trackType: Edge.TrackType,
        maxSpeed: Int,
        capacity: Int?,
        isPaired: Bool
    ) {
        createCheckpoint()
        if isPaired {
            let fwdId = UUID()
            let bwdId = UUID()
            let fwd = Edge(
                id: fwdId, from: from, to: to,
                distance: distance, trackType: trackType,
                maxSpeed: maxSpeed, capacity: capacity,
                pairedEdgeId: bwdId)
            let bwd = Edge(
                id: bwdId, from: to, to: from,
                distance: distance, trackType: trackType,
                maxSpeed: maxSpeed, capacity: capacity,
                pairedEdgeId: fwdId)
            network.edges.append(contentsOf: [fwd, bwd])
        } else {
            network.edges.append(Edge(
                from: from, to: to,
                distance: distance, trackType: trackType,
                maxSpeed: maxSpeed, capacity: capacity))
        }
        infrastructureManager.processNetwork(network)
    }

    /// Removes an edge (and optionally its paired counterpart) under a single
    /// undo checkpoint.
    func removeEdge(_ id: UUID, includingPaired: Bool) {
        createCheckpoint()
        if includingPaired, let paired = network.edges.first(where: { $0.id == id })?.pairedEdgeId {
            network.edges.removeAll { $0.id == id || $0.id == paired }
        } else {
            // When removing one side only, clear the paired reference on the other.
            if let paired = network.edges.first(where: { $0.id == id })?.pairedEdgeId,
               let idx = network.edges.firstIndex(where: { $0.id == paired }) {
                network.edges[idx].pairedEdgeId = nil
            }
            network.edges.removeAll { $0.id == id }
        }
        infrastructureManager.processNetwork(network)
    }

    /// Creates a reverse paired edge for an existing single (non-paired) edge
    /// and cross-links both edges' `pairedEdgeId`.
    /// No-op if the edge is already paired or not found.
    func addPairedEdge(to edgeId: UUID) {
        guard let original = network.edges.first(where: { $0.id == edgeId }),
              original.pairedEdgeId == nil else { return }
        createCheckpoint()
        let pairedId = UUID()
        let reverse = Edge(
            id: pairedId,
            from: original.to, to: original.from,
            distance: original.distance,
            trackType: original.trackType,
            maxSpeed: original.maxSpeed,
            capacity: original.capacity,
            pairedEdgeId: original.id
        )
        if let idx = network.edges.firstIndex(where: { $0.id == edgeId }) {
            network.edges[idx].pairedEdgeId = pairedId
        }
        network.edges.append(reverse)
        infrastructureManager.processNetwork(network)
    }

    // MARK: - Node Removal (cascade-aware)

    /// Removes a node and all dependent data: connected edges, any
    /// RailwayLine or TrainRoute that referenced the deleted node.
    /// Single checkpoint wraps the whole operation for atomic undo.
    func removeNode(_ id: String) {
        createCheckpoint()
        network.nodes.removeAll { $0.id == id }
        network.edges.removeAll { $0.from == id || $0.to == id }
        pruneLines(removingNodeId: id)
        pruneRoutes(removingStationId: id)
    }

    private func pruneLines(removingNodeId id: String) {
        network.lines = network.lines.compactMap { line in
            var updated = line
            updated.nodeIds = updated.nodeIds.filter { $0 != id }
            return updated.nodeIds.count >= 2 ? updated : nil
        }
    }

    private func pruneRoutes(removingStationId id: String) {
        lines.routes = lines.routes.compactMap { route in
            var updated = route
            updated.stationIds = updated.stationIds.filter { $0 != id }
            guard updated.stationIds.count >= 2 else { return nil }
            updated.originStationId = updated.stationIds[0]
            updated.destinationStationId = updated.stationIds[updated.stationIds.count - 1]
            return updated
        }
    }
}
