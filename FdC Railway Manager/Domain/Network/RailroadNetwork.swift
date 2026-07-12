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

    /// Migra hub legacy (es. stazione «Foo AV» separata) e rimappa i binari.
    func reconcileHubTopology() {
        var nodes = network.nodes
        var edges = network.edges
        HubTopology.reconcileLegacyAVStations(nodes: &nodes, edges: &edges)
        reconcileCorridorDuplicates(&edges)
        network.nodes = nodes
        network.edges = edges
        forceUpdateTopology()
    }

    /// Rimuove binari orfani extra sullo stesso tratto (es. terza linea dopo conversioni).
    private func reconcileCorridorDuplicates(_ edges: inout [Edge]) {
        var toRemove = Set<UUID>()
        let grouped = Dictionary(grouping: edges, by: \.canonicalKey)
        for (_, group) in grouped where group.count > 2 {
            let pairIds = Set(group.filter { TrackLayoutMode.isInPair($0, in: group) }.map(\.id))
            guard pairIds.count == 2 else { continue }
            for edge in group where !pairIds.contains(edge.id) {
                toRemove.insert(edge.id)
            }
        }
        guard !toRemove.isEmpty else { return }
        edges.removeAll { toRemove.contains($0.id) }
        print("⚠️ Rimossi \(toRemove.count) binari duplicati sullo stesso tratto")
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
        let hub = HubTopology(nodes: network.nodes)
        let endpoints = hub.resolvedEndpoints(from: from, to: to, trackType: trackType)
        guard endpoints.from != endpoints.to else { return }
        if isPaired {
            let fwdId = UUID()
            let bwdId = UUID()
            let fwd = Edge(
                id: fwdId, from: endpoints.from, to: endpoints.to,
                distance: distance, trackType: trackType,
                maxSpeed: maxSpeed, capacity: capacity,
                pairedEdgeId: bwdId)
            let bwd = Edge(
                id: bwdId, from: endpoints.to, to: endpoints.from,
                distance: distance, trackType: trackType,
                maxSpeed: maxSpeed, capacity: capacity,
                pairedEdgeId: fwdId)
            network.edges.append(contentsOf: [fwd, bwd])
        } else {
            network.edges.append(Edge(
                from: endpoints.from, to: endpoints.to,
                distance: distance, trackType: trackType,
                maxSpeed: maxSpeed, capacity: capacity))
        }
        infrastructureManager.processNetwork(network)
    }

    /// Crea il satellite AV per uno hub, evitando duplicati.
    @discardableResult
    func addHubAVSatellite(
        for parentId: String,
        direction: Node.HubOffsetDirection = .bottomRight
    ) -> Node? {
        guard let parent = network.findNode(id: parentId) else { return nil }
        let hub = HubTopology(nodes: network.nodes)
        guard hub.avSatellite(for: parentId) == nil else { return hub.avSatellite(for: parentId) }

        var satelliteId = "\(parentId)_av"
        var suffix = 2
        while network.findNode(id: satelliteId) != nil {
            satelliteId = "\(parentId)_av\(suffix)"
            suffix += 1
        }

        let satellite = hub.makeAVSatellite(for: parent, direction: direction, id: satelliteId)
        network.addNode(satellite)
        forceUpdateTopology()
        return satellite
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
        guard let idx = network.edges.firstIndex(where: { $0.id == edgeId }),
              network.edges[idx].pairedEdgeId == nil,
              !network.edges.contains(where: { $0.pairedEdgeId == edgeId }) else { return }
        createCheckpoint()
        let original = network.edges[idx]
        let pairedId = UUID()
        var forward = original
        forward.pairedEdgeId = pairedId
        network.edges[idx] = forward
        network.edges.append(Edge(
            id: pairedId,
            from: original.to, to: original.from,
            distance: original.distance,
            trackType: original.trackType,
            maxSpeed: original.maxSpeed,
            capacity: original.capacity,
            pairedEdgeId: original.id
        ))
        infrastructureManager.processNetwork(network)
        forceUpdateTopology()
        objectWillChange.send()
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

    // MARK: - Track layout (singolo / doppio / AV)

    /// Applica il layout binario scelto dall'utente (singolo / doppio / AV).
    func applyTrackLayout(
        _ mode: TrackLayoutMode,
        to edgeId: UUID,
        singleMaxSpeed: Int,
        highSpeedMaxSpeed: Int
    ) {
        guard network.edges.contains(where: { $0.id == edgeId }) else { return }
        repairPairedEdgeLinks()
        createCheckpoint()

        switch mode {
        case .single:
            dissolvePair(around: edgeId)
            removeCorridorOrphans(anchorId: edgeId)
            updateEdgeRecord(edgeId) { edge in
                edge.trackType = .single
                edge.capacity = 6
                edge.maxSpeed = singleMaxSpeed
            }

        case .double:
            removeCorridorOrphans(anchorId: edgeId)
            updateEdgeRecord(edgeId) { edge in
                edge.trackType = .single
                edge.capacity = 6
                edge.maxSpeed = singleMaxSpeed
            }
            if let current = network.edges.first(where: { $0.id == edgeId }),
               !TrackLayoutMode.isInPair(current, in: network.edges) {
                appendPairedEdgeRecord(to: edgeId)
            }
            syncPairedPartner(of: edgeId)

        case .highSpeed:
            removeCorridorOrphans(anchorId: edgeId)
            let wasPaired = network.edges.first(where: { $0.id == edgeId })
                .map { TrackLayoutMode.isInPair($0, in: network.edges) } ?? false
            updateEdgeRecord(edgeId) { edge in
                edge.trackType = .highSpeed
                edge.capacity = 15
                edge.maxSpeed = highSpeedMaxSpeed
            }
            if wasPaired {
                syncPairedPartner(of: edgeId)
            }
        }

        repairPairedEdgeLinks()
        infrastructureManager.processNetwork(network)
        forceUpdateTopology()
        objectWillChange.send()
    }

    /// Azzera `pairedEdgeId` che puntano a binari già rimossi (evita stato inconsistente dopo conversioni).
    private func repairPairedEdgeLinks() {
        let liveIds = Set(network.edges.map(\.id))
        for idx in network.edges.indices {
            if let pairedId = network.edges[idx].pairedEdgeId, !liveIds.contains(pairedId) {
                network.edges[idx].pairedEdgeId = nil
            }
        }
    }

    /// Elimina binari extra sullo stesso tratto (stesso `canonicalKey`), tenendo solo l'ancora e il partner collegato.
    private func removeCorridorOrphans(anchorId: UUID) {
        guard let anchor = network.edges.first(where: { $0.id == anchorId }) else { return }
        let key = anchor.canonicalKey
        let partnerId = anchor.pairedEdgeId ?? network.edges.first(where: { $0.pairedEdgeId == anchorId })?.id
        network.edges.removeAll { edge in
            guard edge.canonicalKey == key else { return false }
            if edge.id == anchorId { return false }
            if let partnerId, edge.id == partnerId { return false }
            return true
        }
    }

    private func updateEdgeRecord(_ edgeId: UUID, mutate: (inout Edge) -> Void) {
        guard let idx = network.edges.firstIndex(where: { $0.id == edgeId }) else { return }
        var edge = network.edges[idx]
        mutate(&edge)
        network.edges[idx] = edge
    }

    private func dissolvePair(around edgeId: UUID) {
        guard let idx = network.edges.firstIndex(where: { $0.id == edgeId }) else { return }
        var edge = network.edges[idx]

        if let pairedId = edge.pairedEdgeId {
            network.edges.removeAll { $0.id == pairedId }
            edge.pairedEdgeId = nil
            network.edges[idx] = edge
            return
        }

        if let partnerIdx = network.edges.firstIndex(where: { $0.pairedEdgeId == edgeId }) {
            network.edges.remove(at: partnerIdx)
        }
    }

    private func appendPairedEdgeRecord(to edgeId: UUID) {
        guard let idx = network.edges.firstIndex(where: { $0.id == edgeId }) else { return }
        let original = network.edges[idx]
        guard original.pairedEdgeId == nil,
              !network.edges.contains(where: { $0.pairedEdgeId == edgeId }) else { return }

        let pairedId = UUID()
        var forward = original
        forward.pairedEdgeId = pairedId
        network.edges[idx] = forward

        network.edges.append(Edge(
            id: pairedId,
            from: original.to,
            to: original.from,
            distance: original.distance,
            trackType: original.trackType,
            maxSpeed: original.maxSpeed,
            capacity: original.capacity,
            pairedEdgeId: original.id
        ))
    }

    private func syncPairedPartner(of edgeId: UUID) {
        guard let idx = network.edges.firstIndex(where: { $0.id == edgeId }) else { return }
        let edge = network.edges[idx]
        let partnerId = edge.pairedEdgeId ?? network.edges.first(where: { $0.pairedEdgeId == edgeId })?.id
        guard let partnerId, let partnerIdx = network.edges.firstIndex(where: { $0.id == partnerId }) else { return }

        var partner = network.edges[partnerIdx]
        partner.trackType = edge.trackType
        partner.maxSpeed = edge.maxSpeed
        partner.capacity = edge.capacity
        partner.distance = edge.distance
        partner.pairedEdgeId = edge.id
        network.edges[partnerIdx] = partner

        var forward = edge
        forward.pairedEdgeId = partnerId
        network.edges[idx] = forward
    }
}
