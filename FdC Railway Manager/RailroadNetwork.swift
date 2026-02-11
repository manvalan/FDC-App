
import Foundation
import Combine
import SwiftUI

/// The central class for the Railway Manager system.
/// Separates the logic into distinct functional areas as requested.
@MainActor
final class RailroadNetwork: ObservableObject {
    
    // MARK: - Sub-Systems
    
    /// Network: Tutto quello che si riferisce alla rete fisica (Stazioni, Binari, ecc.)
    @Published var network: NetworkModel
    
    /// Linee: Le relazioni che saranno percorse da un treno (Lines, Trains)
    @Published var lines: LinesManager
    
    /// Impostazioni: Dati di setup
    @Published var settings: SettingsManager
    
    /// I/O: Input/Output operations (Non-published as it is a service)
    var io: IOManager
    
    /// AI: Artificial Intelligence modules
    var ai: AIManager
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        let newNetwork = NetworkModel()
        let newLines = LinesManager(network: newNetwork)
        
        self.network = newNetwork
        self.lines = newLines
        self.settings = SettingsManager()
        self.io = IOManager()
        self.ai = AIManager()
        
        // Fully initialized, now safe to use 'self'
        self.network.owner = self
        self.lines.owner = self
        self.io.railroad = self
        self.ai.railroad = self
        
        // Propagate changes from sub-models to the main RailroadNetwork
        self.network.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        self.lines.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        self.settings.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
    }
    
    // MARK: - Global Undo/Redo System
    
    struct RailroadSnapshot: Equatable {
        let nodes: [Node]
        let edges: [Edge]
        let lines: [RailwayLine]
        let trains: [Train]
        let vehicles: [Vehicle]
    }
    
    private var undoStack: [RailroadSnapshot] = []
    private var redoStack: [RailroadSnapshot] = []
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func createCheckpoint() {
        let snapshot = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
            lines: lines.lines,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        // Only push if different from last
        if undoStack.last != snapshot {
            undoStack.append(snapshot)
            if undoStack.count > 50 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
    }
    
    func undo() {
        guard let last = undoStack.popLast() else { return }
        let current = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
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
        lines.lines = snapshot.lines
        lines.trains = snapshot.trains
        lines.vehicles = snapshot.vehicles
        lines.validateSchedules()
        objectWillChange.send()
    }
}

// MARK: - 1. Network (Physical Infrastructure)

@MainActor
final class NetworkModel: ObservableObject {
    @Published var name: String = "My Network"
    @Published var nodes: [Node] = []
    @Published var edges: [Edge] = []
    
    /// Global system owner
    weak var owner: RailroadNetwork?
    
    // Undo stack is now managed globally by RailroadNetwork
    
    var sortedNodes: [Node] {
        nodes.sorted { $0.name < $1.name }
    }
    
    var sortedEdges: [Edge] {
        edges.sorted { e1, e2 in
            let name1 = nodes.first(where: { $0.id == e1.from })?.name ?? ""
            let name2 = nodes.first(where: { $0.id == e2.from })?.name ?? ""
            return name1 < name2
        }
    }
    
    init(nodes: [Node] = [], edges: [Edge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
    
    // MARK: - Legacy Bridge & Pathfinding
    // Using static methods from RailwayNetwork for calculation to avoid code duplication
    
    func findPathEdges(from startId: String, to endId: String) -> [Edge]? {
        return RailwayNetwork.findPathEdges(from: startId, to: endId, edges: edges)
    }
    
    func findShortestPath(from start: String, to end: String) -> ([String], Double)? {
        return NetworkModel.findShortestPath(from: start, to: end, nodes: nodes, edges: edges)
    }
    
    func findAlternativePaths(from start: String, to end: String) -> [(path: [String], distance: Double, description: String)] {
        return NetworkModel.findAlternativePaths(from: start, to: end, nodes: nodes, edges: edges)
    }

    static nonisolated func findAlternativePaths(from start: String, to end: String, nodes: [Node], edges: [Edge]) -> [(path: [String], distance: Double, description: String)] {
        var results: [(path: [String], distance: Double, description: String)] = []
        
        // 1. Path 1: Pure Shortest Path (Rapid)
        if let shortest = findShortestPath(from: start, to: end, nodes: nodes, edges: edges) {
            results.append((shortest.0, shortest.1, "Rapido"))
            
            // 2. Path 2: Try to find an alternative by penalizing edges of the first path
            // This is a simplified version of finding a different route
            if shortest.0.count > 2 {
                let penalizedEdges = edges.map { edge -> Edge in
                    var newEdge = edge
                    let isPartOfShortest = (0..<shortest.0.count-1).contains { i in
                        (edge.from == shortest.0[i] && edge.to == shortest.0[i+1]) ||
                        (edge.to == shortest.0[i] && edge.from == shortest.0[i+1])
                    }
                    if isPartOfShortest {
                        newEdge.distance *= 2.0 // Penalize heavily to force a detour
                    }
                    return newEdge
                }
                
                if let alt = findShortestPath(from: start, to: end, nodes: nodes, edges: penalizedEdges) {
                    // Check if it's actually different
                    if alt.0 != shortest.0 {
                        let trueDist = calculatePathDistance(path: alt.0, edges: edges)
                        results.append((alt.0, trueDist, "Alternativo"))
                    }
                }
            }
            
            // 3. Path 3: Try another variation (e.g. avoiding different middle node)
            if results.count < 3 && shortest.0.count > 3 {
                 let midIdx = shortest.0.count / 2
                 let excludedNode = shortest.0[midIdx]
                 let restrictedNodes = nodes.filter { $0.id != excludedNode }
                 if let alt2 = findShortestPath(from: start, to: end, nodes: restrictedNodes, edges: edges) {
                     if !results.contains(where: { $0.path == alt2.0 }) {
                         results.append((alt2.0, alt2.1, "Panoramico"))
                     }
                 }
            }
        }
        
        return results
    }
    
    // MARK: - Mutation Methods (with Undo)
    
    func addNode(_ node: Node) {
        createCheckpoint()
        nodes.append(node)
    }
    
    func addEdge(_ edge: Edge) {
        createCheckpoint()
        var newEdge = edge
        if newEdge.segments.isEmpty {
            // Se non ha segmenti, generiamoli ora
            InfrastructureManager.shared.processNetwork(self)
        }
        edges.append(newEdge)
    }
    
    func removeNode(_ id: String) {
        createCheckpoint()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
    }
    
    func removeEdge(_ from: String, _ to: String) {
        createCheckpoint()
        edges.removeAll { $0.from == from && $0.to == to }
    }
    
    var canUndo: Bool { false } // Managed globally
    var canRedo: Bool { false } // Managed globally
    
    func createCheckpoint() {
        owner?.createCheckpoint()
    }
    
    func undo() { }
    func redo() { }
    
    func isTrackAllowed(stationId: String, track: String?, lineId: String, prevStationId: String?, nextStationId: String?) -> Bool {
        guard let node = nodes.first(where: { $0.id == stationId }) else { return true }
        return node.isTrackAllowed(track: track, lineId: lineId, prevStationId: prevStationId, nextStationId: nextStationId)
    }
    
    func getConnectedNodeIds(for nodeId: String) -> [String] {
        return edges.compactMap { edge -> String? in
            if edge.from == nodeId { return edge.to }
            if edge.to == nodeId { return edge.from }
            return nil
        }
    }

    /// Finds all passenger stations (station/interchange) reachable from the given node
    /// by traversing through junctions, depots, or other non-passenger nodes.
    func getNeighborStations(for nodeId: String) -> [String] {
        var neighbors = Set<String>()
        var visited = Set<String>([nodeId])
        var queue = getConnectedNodeIds(for: nodeId)
        
        while !queue.isEmpty {
            let currentId = queue.removeFirst()
            if visited.contains(currentId) { continue }
            visited.insert(currentId)
            
            if let node = nodes.first(where: { $0.id == currentId }) {
                if node.type == .station || node.type == .interchange {
                    neighbors.insert(currentId)
                } else {
                    // It's a technical node (junction, depot, etc.), continue searching
                    let nextLevel = getConnectedNodeIds(for: currentId)
                    queue.append(contentsOf: nextLevel)
                }
            }
        }
        return Array(neighbors)
    }
    
    // Bridge instance methods for compatibility
    
    func calculatePathDistance(path: [String]) -> Double {
        return NetworkModel.calculatePathDistance(path: path, edges: edges)
    }
    
    // MARK: - Pathfinding (Migrated from RailwayNetwork)
    
    static nonisolated func dijkstraAll(from start: String, nodes: [Node], edges: [Edge], isReverse: Bool = false) -> (distances: [String: Double], previous: [String: String]) {
        var distances = [String: Double]()
        var previous = [String: String]()
        
        let adj: [String: [Edge]] = {
            var tempAdj = [String: [Edge]]()
            for edge in edges {
                if isReverse {
                    tempAdj[edge.to, default: []].append(edge)
                    if edge.trackType == .single { tempAdj[edge.from, default: []].append(edge) }
                } else {
                    tempAdj[edge.from, default: []].append(edge)
                    if edge.trackType == .single { tempAdj[edge.to, default: []].append(edge) }
                }
            }
            return tempAdj
        }()
        
        for node in nodes { distances[node.id] = Double.infinity }
        distances[start] = 0
        
        var candidates: [String] = [start]
        var visited = Set<String>()
        
        while !candidates.isEmpty {
            var minIndex = -1
            var minDistance = Double.infinity
            
            for (i, node) in candidates.enumerated() {
                let d = distances[node] ?? .infinity
                if d < minDistance {
                    minDistance = d
                    minIndex = i
                }
            }
            
            if minIndex == -1 { break }
            let current = candidates.remove(at: minIndex)
            
            if visited.contains(current) { continue }
            visited.insert(current)
            
            let dist = distances[current] ?? .infinity
            if dist == .infinity { break }
            
            let neighbors = adj[current] ?? []
            for edge in neighbors {
                let neighborId = isReverse ? (edge.to == current ? edge.from : edge.to) : (edge.from == current ? edge.to : edge.from)
                if visited.contains(neighborId) { continue }
                
                let alt = dist + edge.distance
                if alt < (distances[neighborId] ?? .infinity) {
                    distances[neighborId] = alt
                    previous[neighborId] = current
                    candidates.append(neighborId)
                }
            }
        }
        return (distances, previous)
    }
    
    static nonisolated func findShortestPath(from start: String, to end: String, nodes: [Node], edges: [Edge]) -> ([String], Double)? {
        let (distances, previous) = dijkstraAll(from: start, nodes: nodes, edges: edges)
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
    
    static nonisolated func findPathEdges(from startId: String, to endId: String, edges: [Edge]) -> [Edge]? {
        guard startId != endId else { return [] }
        
        // PIGNOLO: Adjacency must be BIDIRECTIONAL for all track types to support reverse paths 
        // even if only one direction is explicitly defined as .double or .highSpeed.
        var adj = [String: [Edge]]()
        adj.reserveCapacity(edges.count * 2)
        for edge in edges {
            adj[edge.from, default: []].append(edge)
            adj[edge.to, default: []].append(edge)
        }
        
        var distances = [String: Double]()
        var previous = [String: (from: String, edge: Edge)]()
        distances[startId] = 0
        
        var queue = Set<String>([startId])
        
        while let curr = queue.min(by: { (distances[$0] ?? .infinity) < (distances[$1] ?? .infinity) }) {
            queue.remove(curr)
            if curr == endId { break }
            
            let dist = distances[curr] ?? .infinity
            if dist == .infinity { break }
            
            for edge in adj[curr] ?? [] {
                let neighbor = (edge.from == curr) ? edge.to : edge.from
                let newDist = dist + edge.distance
                if newDist < (distances[neighbor] ?? .infinity) {
                    distances[neighbor] = newDist
                    previous[neighbor] = (curr, edge)
                    queue.insert(neighbor)
                }
            }
        }
        
        if distances[endId] == nil { return nil }
        
        var path: [Edge] = []
        var curr = endId
        while curr != startId {
            guard let prev = previous[curr] else { return nil }
            path.append(prev.edge)
            curr = prev.from
        }
        return path.reversed()
    }
    
    static nonisolated func calculatePathDistance(path: [String], edges: [Edge]) -> Double {
        guard path.count > 1 else { return 0.0 }
        var total = 0.0
        for i in 0..<(path.count - 1) {
            let from = path[i]
            let to = path[i+1]
            if let edge = edges.first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) {
                total += edge.distance
            }
        }
        return total
    }
}

// MARK: - 2. Lines (Lines, Trains, Schedule Logic)

@MainActor
final class LinesManager: ObservableObject {
    @Published var lines: [RailwayLine] = [] {
        didSet { validateSchedules() }
    }
    @Published var trains: [Train] = [] {
        didSet { validateSchedules() }
    }
    @Published var vehicles: [Vehicle] = [] {
        didSet { validateSchedules() }
    }
    
    private var isValidating = false
    
    /// Callback for when schedules are revalidated (useful for simulator sync)
    var onSchedulesChanged: (() -> Void)?
    
    var sortedLines: [RailwayLine] {
        lines.sorted { l1, l2 in
            let p1 = l1.numberPrefix ?? 9999
            let p2 = l2.numberPrefix ?? 9999
            if p1 != p2 {
                return p1 < p2
            }
            return l1.name < l2.name
        }
    }
    
    /// Reference to the physical network for validation
    unowned var network: NetworkModel
    
    /// Conflict Manager handles resource contention detection
    let conflictManager = ConflictManager()
    
    private var pathCache: [String: [Edge]] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    /// Global system owner
    weak var owner: RailroadNetwork?
    
    func createCheckpoint() {
        owner?.createCheckpoint()
    }
    
    init(network: NetworkModel) {
        self.network = network
        
        conflictManager.$conflicts
             .receive(on: RunLoop.main)
             .sink { [weak self] _ in
                 self?.objectWillChange.send()
             }
             .store(in: &cancellables)
    }
    
    func binding(for train: Train) -> Binding<Train>? {
        guard let index = trains.firstIndex(where: { $0.id == train.id }) else { return nil }
        return Binding(
            get: { self.trains[index] },
            set: { 
                self.trains[index] = $0 
                self.validateSchedules()
            }
        )
    }
    
    func trains(for line: RailwayLine) -> [Train] {
        return trains.filter { $0.lineId == line.id }
    }
    
    var unassignedTrains: [Train] {
        return trains.filter { $0.lineId == nil }
    }
    
    var activeConflicts: [ScheduleConflict] {
        return conflictManager.conflicts
    }
    
    /// Checks for scheduling conflicts for a specific vehicle across all its assigned trains.
    func getVehicleConflicts(for vehicleId: UUID) -> [VehicleConflict] {
        let vehicleTrains = trains.filter { $0.vehicleId == vehicleId && $0.departureTime != nil }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
        
        // Safety check: if less than 2 trains, no conflict possible
        if vehicleTrains.count < 2 { return [] }
        
        var conflicts: [VehicleConflict] = []
        
        for i in 0..<vehicleTrains.count - 1 {
            let trainA = vehicleTrains[i]
            let trainB = vehicleTrains[i+1]
            
            // Get arrival at last stop for trainA
            guard let arrivalA = trainA.stops.last?.arrival,
                  let departureB = trainB.departureTime else { continue }
            
            // 15-minute minimum turnaround buffer
            let minTurnaround: TimeInterval = 15 * 60
            
            if departureB < arrivalA.addingTimeInterval(minTurnaround) {
                conflicts.append(VehicleConflict(
                    trainA: trainA,
                    trainB: trainB,
                    arrivalA: arrivalA,
                    departureB: departureB
                ))
            }
        }
        return conflicts
    }
    
    // MARK: - Scheduling Operations (Vehicle Optimization)
    
    /// Algoritmo di assegnazione automatica con bilanciamento (Load Balancing).
    /// Associa i treni della linea minimizzando i mezzi e distribuendo equamente il carico,
    /// assegnando anche i binari ai capolinea in base ai turni.
    func autoAssignRollingStock(for lineId: String) {
        guard let line = lines.first(where: { $0.id == lineId }) else { return }
        let terminalPrefs = line.terminalTracks
        
        let dedicatedFleetIds = Set(trains.filter { $0.lineId == lineId }.compactMap { $0.vehicleId })
        let dedicatedFleet = vehicles.filter { dedicatedFleetIds.contains($0.id) }
        let otherFleet = vehicles.filter { !dedicatedFleetIds.contains($0.id) }
        
        var localTrains = self.trains
        let lineTrainsIndices = localTrains.indices.filter { localTrains[$0].lineId == lineId && localTrains[$0].departureTime != nil }
            .sorted { (localTrains[$0].departureTime ?? Date.distantPast) < (localTrains[$1].departureTime ?? Date.distantPast) }
        
        if lineTrainsIndices.isEmpty { return }
        
        // Reset
        for i in localTrains.indices {
            if localTrains[i].lineId == lineId {
                localTrains[i].vehicleId = nil
            }
        }
        
        // Stato: vehicleId -> (l'ultima stazione, orario arrivo, numero servizi assegnati, ultimo binario usato)
        var fleetStatus: [UUID: (station: String, time: Date, serviceCount: Int, track: String?)] = [:]
        let buffer: TimeInterval = 15 * 60
        
        for idx in lineTrainsIndices {
            let train = localTrains[idx]
            guard let depTime = train.departureTime,
                  let startStation = train.stops.first?.stationId else { continue }
            
            // 1. Identifica candidati validi (stazione corretta + tempo di sosta)
            let candidates = fleetStatus.filter { (vid, status) in
                status.station == startStation && depTime >= status.time.addingTimeInterval(buffer)
            }
            
            var bestCandidate: UUID? = nil
            
            if !candidates.isEmpty {
                // Strategia di Bilanciamento:
                // A. Priorità ai mezzi con numero DISPARI di servizi (per renderli PARI)
                let oddCandidates = candidates.filter { $0.value.serviceCount % 2 != 0 }
                if !oddCandidates.isEmpty {
                    bestCandidate = oddCandidates.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key
                } else {
                    bestCandidate = candidates.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key
                }
            }
            
            // 2. Se nessun candidato esistente, usa uno nuovo
            if bestCandidate == nil {
                if let unusedDedicated = dedicatedFleet.first(where: { fleetStatus[$0.id] == nil }) {
                    bestCandidate = unusedDedicated.id
                } else if let unusedGlobal = otherFleet.first(where: { fleetStatus[$0.id] == nil }) {
                    bestCandidate = unusedGlobal.id
                }
            }
            
            if let vid = bestCandidate {
                localTrains[idx].vehicleId = vid
                let currentStatus = fleetStatus[vid]
                let currentCount = currentStatus?.serviceCount ?? 0
                
                // ----- ASSEGNAZIONE BINARI CAPOLINEA -----
                let originId = startStation
                let destId = localTrains[idx].stops.last?.stationId ?? ""
                
                // Binario di Partenza: 
                // Se il mezzo era già in stazione, usa lo stesso binario dell'arrivo precedente.
                // Altrimenti usa la preferenza della linea.
                let departureTrack = currentStatus?.track ?? terminalPrefs[originId]
                
                if let track = departureTrack {
                    localTrains[idx].stops[0].track = track
                    localTrains[idx].stops[0].isManualTrack = true
                }
                
                // Binario di Arrivo:
                // Usa la preferenza della linea per la destinazione.
                let arrivalTrack = terminalPrefs[destId] ?? departureTrack // Default al binario di partenza se non specificato
                
                if let track = arrivalTrack {
                    let lastStopIdx = localTrains[idx].stops.count - 1
                    localTrains[idx].stops[lastStopIdx].track = track
                    localTrains[idx].stops[lastStopIdx].isManualTrack = true
                }
                // ------------------------------------------

                if let arrivalAtEnd = localTrains[idx].stops.last?.arrival {
                    fleetStatus[vid] = (destId, arrivalAtEnd, currentCount + 1, arrivalTrack)
                }
            }
        }
        
        self.trains = localTrains
        validateSchedules()
    }
    
    // MARK: - Legacy Refresh
    
    func refreshSchedules() {
        // Reuse the logic from TrainManager but adapted to 'network' (NetworkModel)
        // We need a temporary adapter or we need to update TrainManager logic to use NetworkModel
        // Since NetworkModel matches the structure (nodes, edges), we can construct a dummy RailwayNetwork 
        // OR refactor the logic.
        // For expedience, we will implement the core loop here.
        
        for i in trains.indices {
            guard let depTime = trains[i].departureTime, !trains[i].stops.isEmpty else { continue }
            
            var currentTime = depTime.normalized()
            let originId = trains[i].stops.first?.stationId ?? ""
            var prevId = originId
            
            for j in trains[i].stops.indices {
                let stop = trains[i].stops[j]
                let isSkipped = stop.isSkipped
                let baseDwell = isSkipped ? 0 : Double(stop.minDwellTime)
                let extraDwell = stop.extraDwellTime
                let dwellDuration = (baseDwell + extraDwell) * 60
                
                if stop.stationId == originId && j == 0 {
                    trains[i].stops[j].arrival = nil
                    let startPoint = (stop.plannedDeparture?.normalized() ?? currentTime).cleanSeconds()
                    trains[i].stops[j].departure = startPoint
                    currentTime = startPoint
                } else {
                    var legDistance: Double = 0
                    var legMinSpeed: Double = Double.infinity
                    var transitDuration: TimeInterval = 0
                    
                    let currentPrevId = trains[i].stops[j-1].stationId
                    let pathKey = "\(currentPrevId)--\(stop.stationId)"
                    
                    let path = pathCache[pathKey] ?? network.findPathEdges(from: currentPrevId, to: stop.stationId)
                    if let actualPath = path {
                        pathCache[pathKey] = actualPath
                        for edge in actualPath {
                            legDistance += edge.distance
                            legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                        }
                    }
                    
                    if legDistance > 0 {
                         // We need FDCSchedulerEngine. Calculate manually or bridge?
                         // Assuming FDCSchedulerEngine is available
                         let hours = FDCSchedulerEngine.calculateTravelTime(
                            distanceKm: legDistance,
                            maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed,
                            train: trains[i],
                            initialSpeedKmh: 0,
                            finalSpeedKmh: 0
                        )
                        transitDuration = hours * 3600
                    }
                    
                    currentTime = currentTime.addingTimeInterval(transitDuration)
                    let roundedArrivalSeconds = floor(currentTime.timeIntervalSinceReferenceDate + 0.5)
                    let roundedArrival = Date(timeIntervalSinceReferenceDate: roundedArrivalSeconds)
                    
                    let actualArrival = stop.plannedArrival?.normalized() ?? roundedArrival
                    trains[i].stops[j].arrival = actualArrival
                    
                    // Use custom dwell time if set, otherwise use calculated dwell
                    let effectiveDwellTime: TimeInterval
                    if let customDwell = stop.customDwellSeconds {
                        // User has set a custom dwell time - preserve it
                        effectiveDwellTime = customDwell
                    } else {
                        // Use standard dwell time
                        effectiveDwellTime = dwellDuration
                    }
                    
                    let finalDep = actualArrival.addingTimeInterval(effectiveDwellTime)
                    let roundedDepSeconds = floor(finalDep.timeIntervalSinceReferenceDate + 0.5)
                    let roundedDep = Date(timeIntervalSinceReferenceDate: roundedDepSeconds)
                    
                    trains[i].stops[j].departure = (j < trains[i].stops.count - 1) ? roundedDep.cleanSeconds() : nil
                    currentTime = roundedDep.cleanSeconds()
                }
                prevId = stop.stationId
            }
        }
    }
    
    func validateSchedules() {
        guard !isValidating else { return }
        isValidating = true
        
        refreshSchedules()
        // Reset detection
        conflictManager.detectConflicts(nodes: network.nodes, edges: network.edges, trains: trains, pathCache: pathCache)
        
        onSchedulesChanged?()
        
        isValidating = false
        objectWillChange.send()
    }
    
    func generateConflictReport(network: NetworkModel) -> String {
        var report = "REPORT CONFLITTI ATTUALI:\n"
        
        if conflictManager.conflicts.isEmpty {
            report += "Nessun conflitto rilevato.\n"
        } else {
            for (idx, c) in conflictManager.conflicts.enumerated() {
                report += "\(idx+1). Conflitto tra \(c.trainAName) e \(c.trainBName) a \(c.locationName).\n"
                report += "   Intervallo: \(formatTime(c.timeStart)) - \(formatTime(c.timeEnd))\n"
            }
        }
        
        report += "\nORARI TRENI COINVOLTI:\n"
        let involvedIds = Set(conflictManager.conflicts.flatMap { [ $0.trainAId, $0.trainBId ] })
        let involvedTrains = trains.filter { involvedIds.contains($0.id) }
        
        for train in involvedTrains {
            report += "Treno: \(train.type) \(train.name) (ID: \(train.id.uuidString))\n"
            report += "  Partenza: \(formatTime(train.departureTime ?? Date()))\n"
            report += "  Fermate:\n"
            for stop in train.stops {
                let stationName = network.nodes.first(where: { $0.id == stop.stationId })?.name ?? stop.stationId
                report += "    - \(stationName): Sosta \(stop.minDwellTime) min"
                if let arr = stop.arrival, let dep = stop.departure {
                     report += " (Arr: \(formatTime(arr)), Part: \(formatTime(dep)))"
                }
                report += "\n"
            }
        }
        
        return report
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func applyAISuggestions(_ suggestions: [AIScheduleSuggestion]) {
        let calendar = Calendar.current
        
        for suggestion in suggestions {
            if let idx = trains.firstIndex(where: { $0.id == suggestion.trainId }) {
                // Parse HH:mm
                let parts = suggestion.newDepartureTime.components(separatedBy: ":")
                if parts.count == 2, let hour = Int(parts[0]), let min = Int(parts[1]) {
                    let baseDate = trains[idx].departureTime ?? Date()
                    if let newDate = calendar.date(bySettingHour: hour, minute: min, second: 0, of: baseDate) {
                        trains[idx].departureTime = newDate
                    }
                }
                
                // Adjust Dwells
                if let adjustments = suggestion.stopAdjustments {
                    for adj in adjustments {
                        if let sIdx = trains[idx].stops.firstIndex(where: { $0.stationId == adj.stationId }) {
                            trains[idx].stops[sIdx].minDwellTime = adj.newMinDwellTime
                        }
                    }
                }
            }
        }
        validateSchedules()
    }

    /// Applica i risultati dell'ottimizzatore V2 (Resolutions)
    func applyResolutions(_ resolutions: [RailwayAIResolution], network: NetworkModel, trainMapping: [UUID: Int]) {
        objectWillChange.send()
        
        // Invert mapping for fast lookup
        let idToUUID = Dictionary(uniqueKeysWithValues: trainMapping.map { ($1, $0) })
        
        for res in resolutions {
            guard let uuid = idToUUID[res.train_id],
                  let idx = trains.firstIndex(where: { $0.id == uuid }) else { continue }
            
            // 1. Apply initial departure delay
            if res.time_adjustment_min != 0 {
                if let currentDep = trains[idx].departureTime {
                    trains[idx].departureTime = currentDep.addingTimeInterval(res.time_adjustment_min * 60)
                }
            }
            
            // 2. Apply dwell delays to individual stops
            if let dwells = res.dwell_delays {
                for (stopIdx, delayMin) in dwells.enumerated() {
                    if stopIdx < trains[idx].stops.count {
                        // We add to the existing extra dwell
                        trains[idx].stops[stopIdx].extraDwellTime += delayMin
                    }
                }
            }
        }
        
        validateSchedules()
        objectWillChange.send()
    }
    
    // MARK: - Line/Train Management
    
    func addTrain(_ train: Train) {
        var mutableTrain = train
        trains.append(mutableTrain)
        
        // 1. Calcola gli orari per avere arrival/departure popolati
        refreshSchedules()
        
        // 2. Tenta di risolvere i conflitti di binario spostando il treno su binari liberi
        resolveTrackConflicts(for: &mutableTrain)
        
        // 3. Aggiorna il treno nella lista se è cambiato
        if let idx = trains.firstIndex(where: { $0.id == mutableTrain.id }) {
            trains[idx] = mutableTrain
        }
        
        validateSchedules()
    }
    
    /// Verifica se un binario specifico è libero in un intervallo temporale
    func isTrackAvailable(stationId: String, track: String, from: Date, to: Date, excludingTrainId: UUID? = nil) -> Bool {
        // Strict buffer: we want at least 5 seconds between trains to match ConflictManager security margins
        let safetyMargin: TimeInterval = 5
        
        for t in trains {
            if t.id == excludingTrainId { continue }
            guard let stop = t.stops.first(where: { $0.stationId == stationId && ($0.track ?? "1") == track }) else { continue }
            if stop.isSkipped { continue }
            guard let arrival = stop.arrival, let departure = stop.departure else { continue }
            
            // Standard overlap check: [from, to] vs [arrival, departure]
            // We consider it occupied if they overlap OR if the gap is less than the safety margin
            let overlapStart = max(from, arrival)
            let overlapEnd = min(to, departure)
            
            if overlapStart < overlapEnd.addingTimeInterval(safetyMargin) {
                return false // Occupied
            }
        }
        return true
    }
    
    /// Analizza il treno e sposta le fermate su binari liberi se rileva conflitti
    func resolveTrackConflicts(for train: inout Train) {
        // Rieseguiamo il detect per avere la lista conflitti aggiornata
        conflictManager.detectConflicts(nodes: network.nodes, edges: network.edges, trains: trains, pathCache: pathCache)
        
        for idx in train.stops.indices {
            let stop = train.stops[idx]
            if stop.isSkipped { continue }
            guard let arrival = stop.arrival, let departure = stop.departure else { continue }
            
            // Controlliamo se la risorsa specifica è in conflitto
            let currentTrack = stop.track ?? "1"
            let resId = "TRACK::\(stop.stationId)::\(currentTrack)"
            
            let isConflicting = conflictManager.conflicts.contains { c in
                (c.locationId == resId || c.locationId == "STATION_GLOBAL::\(stop.stationId)") &&
                (c.trainAId == train.id || c.trainBId == train.id)
            }
            
            if isConflicting {
                let node = network.nodes.first(where: { $0.id == stop.stationId })
                let prevSid = idx > 0 ? train.stops[idx-1].stationId : nil
                let nextSid = idx < train.stops.count - 1 ? train.stops[idx+1].stationId : nil
                
                // Ottieni la lista preferenziale dalla direzione/provenienza
                let candidates = node?.getTracksByProvenance(from: prevSid, nextStationId: nextSid, forLine: train.lineId) ?? ["1"]
                
                // Prova gli altri candidati nella lista (binari autorizzati)
                for alt in candidates {
                    if isTrackAvailable(stationId: stop.stationId, track: alt, from: arrival, to: departure, excludingTrainId: train.id) {
                        train.stops[idx].track = alt
                        break
                    }
                }
                
                // Fallback: Solo se proprio non c'è scelta, ma ceriamo di evitare binari non autorizzati
                // PIGNOLO: In un nodo saturo, meglio un conflitto di orario che un binario sbagliato fisicamente
                // quindi NON facciamo più il fallback automatico su qualsiasi binario se viola l'instradamento
                // a meno che non sia un binario fisico esistente e non ci siano vincoli.
            }
        }
    }
    
    func generateSchedulesPreview() -> [TrainSchedule] {
        // PIGNOLO: Optimize node lookup with a dictionary O(1) instead of nested firstIndex O(N)
        let nodeNames = Dictionary(uniqueKeysWithValues: network.nodes.map { ($0.id, $0.name) })
        
        var schedules: [TrainSchedule] = []
        for train in trains {
            var schedStops: [ScheduleStop] = []
            for stop in train.stops {
                schedStops.append(ScheduleStop(
                    stationId: stop.stationId,
                    arrivalTime: stop.arrival,
                    departureTime: stop.departure,
                    platform: Int(stop.track ?? "1") ?? 1,
                    dwellsMinutes: stop.minDwellTime,
                    stationName: nodeNames[stop.stationId] ?? stop.stationId
                ))
            }
            schedules.append(TrainSchedule(trainId: train.id, trainName: train.name, stops: schedStops))
        }
        return schedules
    }
    
    func removeTrain(_ id: UUID) {
        trains.removeAll { $0.id == id }
        validateSchedules()
    }

    /// factory method per la creazione di un treno con parametri standard
    func instantiateTrain(
        number: Int,
        name: String? = nil,
        category: TrainCategory,
        departureTime: Date,
        line: RailwayLine?,
        stationSequence: [String],
        acceleration: Double,
        deceleration: Double,
        preferredTrack: String? = nil,
        vehicleId: UUID? = nil
    ) -> Train {
        // 1. Determina il nome (prefisso linea + numero o nome custom)
        let finalName: String
        if let customName = name, !customName.isEmpty {
            finalName = customName
        } else {
            let code = line?.codePrefix ?? category.rawValue
            finalName = "\(code) \(number)"
        }
        
        // 2. Crea le fermate con i dwell time corretti e rispetto instradamenti
        let stops = (0..<stationSequence.count).map { i -> RelationStop in
            let sid = stationSequence[i]
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            
            // PIGNOLO: Logica binari intelligente con rispetto Instradamenti e Regole di Linea
            var track = preferredTrack
            
            // Se è un capolinea e la linea ha regole specifiche, usale
            if track == nil {
                if i == 0 || i == stationSequence.count - 1 {
                    if let line = line, let terminalTrack = line.terminalTracks[sid] {
                        track = terminalTrack
                    }
                }
            }
            
            if let node = node {
                if (node.platforms ?? 2) <= 1 {
                    track = nil // Single track station/halt usually doesn't have platform choice
                } else if track == nil {
                     // If no preferred track, try to find one based on constraints
                    let nextId = (i < stationSequence.count - 1) ? stationSequence[i+1] : nil
                    let prevId = (i > 0) ? stationSequence[i-1] : nil
                    let targetLineId = line?.id ?? ""
                    
                    let candidates = node.getTracksByProvenance(from: prevId, nextStationId: nextId, forLine: targetLineId)
                    track = candidates.first
                }
            }
            
            return RelationStop(stationId: sid, minDwellTime: defaultDwell, track: track)
        }
        
        return Train(
            id: UUID(),
            number: number,
            name: finalName,
            type: category.rawValue,
            lineId: line?.id,
            departureTime: departureTime.normalized(),
            stops: stops,
            vehicleId: vehicleId,
            maxSpeed: Double(category.defaultMaxSpeed),
            acceleration: acceleration,
            deceleration: deceleration,
            priority: category.defaultPriority
        )
    }

    /// Estrae la sequenza di stazioni da una linea tra due punti
    func getSequenceFromLine(line: RailwayLine, startId: String, endId: String) -> [String] {
        let allIds = line.stops.map { $0.stationId }
        guard let startIdx = allIds.firstIndex(of: startId),
              let endIdx = allIds.firstIndex(of: endId) else {
            return allIds
        }
        
        if startIdx <= endIdx {
            return Array(allIds[startIdx...endIdx])
        } else {
            return Array(allIds[endIdx...startIdx].reversed())
        }
    }

    /// Comodità per creare un treno da endpoints e linea (come richiesto dall'utente)
    func createTrain(
        number: Int,
        category: TrainCategory,
        departureTime: Date,
        line: RailwayLine,
        startStationId: String,
        endStationId: String,
        preferredTrack: String? = nil
    ) -> Train {
        let sequence = getSequenceFromLine(line: line, startId: startStationId, endId: endStationId)
        let physics = AppState.shared.getPhysics(for: category)
        
        return instantiateTrain(
            number: number,
            category: category,
            departureTime: departureTime,
            line: line,
            stationSequence: sequence,
            acceleration: physics.acceleration,
            deceleration: physics.deceleration,
            preferredTrack: preferredTrack
        )
    }
}

// MARK: - 3. Settings

@MainActor
final class SettingsManager: ObservableObject {
    // Bridges AppState settings
    @Published var globalLineWidth: Double {
        didSet { UserDefaults.standard.set(globalLineWidth, forKey: "global_line_width") }
    }
    @Published var globalFontSize: Double {
        didSet { UserDefaults.standard.set(globalFontSize, forKey: "global_font_size") }
    }
    
    // Train Parameters (Regional, Intercity, HighSpeed)
    @Published var regionalMaxSpeed: Double
    @Published var regionalAcceleration: Double
    @Published var regionalDeceleration: Double
    @Published var regionalPriority: Double
    
    @Published var intercityMaxSpeed: Double
    @Published var intercityAcceleration: Double
    @Published var intercityDeceleration: Double
    @Published var intercityPriority: Double
    
    @Published var highSpeedMaxSpeed: Double
    @Published var highSpeedAcceleration: Double
    @Published var highSpeedDeceleration: Double
    @Published var highSpeedPriority: Double
    
    init() {
        self.globalLineWidth = UserDefaults.standard.double(forKey: "global_line_width") > 0 ? UserDefaults.standard.double(forKey: "global_line_width") : 12.0
        self.globalFontSize = UserDefaults.standard.double(forKey: "global_font_size") > 0 ? UserDefaults.standard.double(forKey: "global_font_size") : 14.0
        
        // Load defaults or user prefs
        self.regionalMaxSpeed = UserDefaults.standard.double(forKey: "regional_max_speed") > 0 ? UserDefaults.standard.double(forKey: "regional_max_speed") : 120
        self.regionalAcceleration = UserDefaults.standard.double(forKey: "regional_acceleration") > 0 ? UserDefaults.standard.double(forKey: "regional_acceleration") : 0.5
        self.regionalDeceleration = UserDefaults.standard.double(forKey: "regional_deceleration") > 0 ? UserDefaults.standard.double(forKey: "regional_deceleration") : 0.5
        self.regionalPriority = UserDefaults.standard.double(forKey: "regional_priority") > 0 ? UserDefaults.standard.double(forKey: "regional_priority") : 3
        
        self.intercityMaxSpeed = UserDefaults.standard.double(forKey: "intercity_max_speed") > 0 ? UserDefaults.standard.double(forKey: "intercity_max_speed") : 160
        self.intercityAcceleration = UserDefaults.standard.double(forKey: "intercity_acceleration") > 0 ? UserDefaults.standard.double(forKey: "intercity_acceleration") : 0.7
        self.intercityDeceleration = UserDefaults.standard.double(forKey: "intercity_deceleration") > 0 ? UserDefaults.standard.double(forKey: "intercity_deceleration") : 0.7
        self.intercityPriority = UserDefaults.standard.double(forKey: "intercity_priority") > 0 ? UserDefaults.standard.double(forKey: "intercity_priority") : 6
        
        self.highSpeedMaxSpeed = UserDefaults.standard.double(forKey: "highspeed_max_speed") > 0 ? UserDefaults.standard.double(forKey: "highspeed_max_speed") : 300
        self.highSpeedAcceleration = UserDefaults.standard.double(forKey: "highspeed_acceleration") > 0 ? UserDefaults.standard.double(forKey: "highspeed_acceleration") : 1.0
        self.highSpeedDeceleration = UserDefaults.standard.double(forKey: "highspeed_deceleration") > 0 ? UserDefaults.standard.double(forKey: "highspeed_deceleration") : 1.0
        self.highSpeedPriority = UserDefaults.standard.double(forKey: "highspeed_priority") > 0 ? UserDefaults.standard.double(forKey: "highspeed_priority") : 10
    }
}

// MARK: - 4. I/O

@MainActor
final class IOManager: ObservableObject {
    weak var railroad: RailroadNetwork?
    
    private var lastStateURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("last_state.json")
    }
    
    func save() {
        guard let railroad = railroad else { return }
        
        let dto = RailwayNetworkDTO(
            name: "Current Network",
            nodes: railroad.network.nodes,
            edges: railroad.network.edges,
            lines: railroad.lines.lines,
            trains: railroad.lines.trains,
            vehicles: railroad.lines.vehicles
        )
        
        do {
            let data = try JSONEncoder().encode(dto)
            try data.write(to: lastStateURL)
            print("💾 RailroadNetwork salvato correttamente in: \(lastStateURL.lastPathComponent)")
        } catch {
            print("❌ Errore durante il salvataggio: \(error.localizedDescription)")
        }
    }
    
    func load() {
        guard let railroad = railroad else { return }
        guard FileManager.default.fileExists(atPath: lastStateURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: lastStateURL)
            let dto = try JSONDecoder().decode(RailwayNetworkDTO.self, from: data)
            populate(from: dto)
            print("✅ RailroadNetwork caricato correttamente da: \(lastStateURL.lastPathComponent)")
        } catch {
            print("❌ Errore durante il caricamento: \(error.localizedDescription)")
        }
    }
    
    private func populate(from dto: RailwayNetworkDTO) {
        guard let railroad = railroad else { return }
        railroad.network.nodes = dto.nodes
        railroad.network.edges = dto.edges
        railroad.lines.lines = dto.lines ?? []
        railroad.lines.trains = dto.trains ?? []
        railroad.lines.vehicles = dto.vehicles ?? []
        
        // Calcola l'infrastruttura dettagliata per i dati caricati
        InfrastructureManager.shared.processNetwork(railroad.network)
    }
    
    func importFromFDC(data: Data) throws {
        guard let railroad = railroad else { return }
        
        let parsed = try FDCParser.parse(data: data)
        
        // Map parsed into domain models
        let nodes = parsed.stations.map { fdcStation in
            let type: Node.NodeType = {
                switch fdcStation.type?.lowercased() {
                case "interchange": return .interchange
                case "depot": return .depot
                default: return .station
                }
            }()
            return Node(id: fdcStation.id, name: fdcStation.name, type: type, latitude: fdcStation.latitude, longitude: fdcStation.longitude, capacity: fdcStation.capacity, platforms: fdcStation.platformCount ?? 2)
        }
        
        let edges = parsed.edges.map { fdcEdge in
            let trackType: Edge.TrackType = {
                switch fdcEdge.trackType?.lowercased() {
                case "highspeed", "high_speed": return .highSpeed
                case "single": return .single
                case "double": return .double
                default: return .regional
                }
            }()
            return Edge(from: fdcEdge.from, to: fdcEdge.to, distance: fdcEdge.distance ?? 1.0, trackType: trackType, maxSpeed: Int(fdcEdge.maxSpeed ?? 120.0), capacity: fdcEdge.capacity)
        }
        
        // Map trains with schedules
        var trainIdMap: [String: UUID] = [:]
        var tCopy = parsed.trains.enumerated().map { (idx, fdcTrain) -> Train in
            let newId = UUID()
            trainIdMap[fdcTrain.id] = newId
            let number = 1000 + idx // Fallback number
            return Train(
                id: newId, 
                number: number, 
                name: fdcTrain.name, 
                type: fdcTrain.type ?? "Regionale", 
                maxSpeed: Double(fdcTrain.maxSpeed ?? 120), 
                acceleration: fdcTrain.acceleration ?? 0.5,
                deceleration: fdcTrain.deceleration ?? 0.5,
                priority: fdcTrain.priority ?? 5
            )
        }
        
        let df = ISO8601DateFormatter()
        for sch in parsed.rawSchedules {
            let swiftTrainId = trainIdMap[sch.train_id] ?? UUID()
            if let tIdx = tCopy.firstIndex(where: { $0.id == swiftTrainId }) {
                tCopy[tIdx].stops = sch.stops.map { stop in
                    RelationStop(stationId: stop.node_id, 
                                 minDwellTime: 2, 
                                 track: stop.platform.map { "\($0)" }, 
                                 arrival: df.date(from: stop.arrival), 
                                 departure: df.date(from: stop.departure))
                }
                tCopy[tIdx].departureTime = tCopy[tIdx].stops.first?.departure
            }
        }
        
        // Update model
        railroad.network.nodes = nodes
        railroad.network.edges = edges
        railroad.lines.lines = parsed.lines
        railroad.lines.trains = tCopy
        
        railroad.lines.validateSchedules()
        InfrastructureManager.shared.processNetwork(railroad.network)
    }

    // Wrappers for FDCImporter/Exporter
    func importNetwork(url: URL) {
        guard let railroad = railroad else { return }
        // TODO: Implementation using FDCImporter logic
        // For now, placeholder
    }
}

// MARK: - 5. AI

@MainActor
final class AIManager: ObservableObject {
    weak var railroad: RailroadNetwork?
    
    @Published var isAnalyzing = false
    @Published var lastAnalysis: RailwayAIService.LineAnalysis?
    
    func analyzeLine(_ line: RailwayLine) async {
        guard let railroad = railroad else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            let stationIds = line.stops.map { $0.stationId }
            let result = try await RailwayAIService.shared.analyzeLine(
                name: line.name,
                stationIds: stationIds,
                nodes: railroad.network.nodes,
                edges: railroad.network.edges
            )
            lastAnalysis = result
        } catch {
            print("❌ AI Analysis failed: \(error.localizedDescription)")
        }
    }
    
    func optimizeSchedules(for lineIds: [String]) async {
        // The provided code snippet for .onChange and .alert is SwiftUI view code
        // and cannot be placed directly inside a class method like this.
        // Assuming the intent was to remove placeholder content or move it to a view.
        // As per instruction, removing the provided snippet as it's not valid here.
    }
    
    // Wrappers for RailwayAIService
    func optimize() async {
        guard let railroad = railroad else { return }
        // TODO: Implementation using RailwayScheduleOptimizer
        // This will likely call RailwayScheduleOptimizer.shared.executePipeline(...)
        // passing railroad.lines.trains and railroad.network (wrapped)
    }
}
