import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

// Nodo della rete ferroviaria (stazione o interscambio)
struct Node: Identifiable, Codable, Hashable {
    enum NodeType: String, Codable {
        case station, interchange, depot, junction
    }
    enum StationVisualType: String, Codable, CaseIterable, Identifiable {
        case filledStar = "Stella piena"
        case filledSquare = "Quadrato pieno"
        case emptySquare = "Quadrato vuoto"
        case filledCircle = "Cerchio pieno"
        case emptyCircle = "Cerchio vuoto"
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .filledStar: return "filled_star".localized
            case .filledSquare: return "filled_square".localized
            case .emptySquare: return "empty_square".localized
            case .filledCircle: return "filled_circle".localized
            case .emptyCircle: return "empty_circle".localized
            }
        }
    }
    
    enum HubOffsetDirection: String, Codable, CaseIterable, Identifiable {
        case topLeft = "In Alto a Sx"
        case topRight = "In Alto a Dx"
        case bottomLeft = "In Basso a Sx"
        case bottomRight = "In Basso a Dx"
        
        var id: String { self.rawValue }
        
        var localizedName: String {
            switch self {
            case .topLeft: return "top_left_offset".localized
            case .topRight: return "top_right_offset".localized
            case .bottomLeft: return "bottom_left_offset".localized
            case .bottomRight: return "bottom_right_offset".localized
            }
        }
    }
    
    let id: String // es: "MI"
    var name: String
    var type: NodeType
    var visualType: StationVisualType?
    var customColor: String?
    var latitude: Double?
    var longitude: Double?
    var capacity: Int?
    var platforms: Int?
    var parentHubId: String? // ID of parent hub station for linked stations
    var hubOffsetDirection: HubOffsetDirection? // Position offset for hub visualization

    enum CodingKeys: String, CodingKey {
        case id, name, type, visualType, customColor, latitude, longitude, capacity, platforms
        case platformCount = "platform_count"
        case parentHubId, hubOffsetDirection
    }

    init(id: String, name: String, type: NodeType = .station, visualType: StationVisualType? = nil, customColor: String? = nil, latitude: Double? = nil, longitude: Double? = nil, capacity: Int? = nil, platforms: Int? = 2, parentHubId: String? = nil, hubOffsetDirection: HubOffsetDirection? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.visualType = visualType
        self.customColor = customColor
        self.latitude = latitude
        self.longitude = longitude
        self.capacity = capacity
        self.platforms = platforms
        self.parentHubId = parentHubId
        self.hubOffsetDirection = hubOffsetDirection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        type = try container.decodeIfPresent(NodeType.self, forKey: .type) ?? .station
        visualType = try container.decodeIfPresent(StationVisualType.self, forKey: .visualType)
        customColor = try container.decodeIfPresent(String.self, forKey: .customColor)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        platforms = try container.decodeIfPresent(Int.self, forKey: .platforms) ?? 
                    container.decodeIfPresent(Int.self, forKey: .platformCount) ?? 2
        parentHubId = try container.decodeIfPresent(String.self, forKey: .parentHubId)
        hubOffsetDirection = try container.decodeIfPresent(HubOffsetDirection.self, forKey: .hubOffsetDirection)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(visualType, forKey: .visualType)
        try container.encodeIfPresent(customColor, forKey: .customColor)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(capacity, forKey: .capacity)
        try container.encodeIfPresent(platforms, forKey: .platforms)
        try container.encodeIfPresent(parentHubId, forKey: .parentHubId)
        try container.encodeIfPresent(hubOffsetDirection, forKey: .hubOffsetDirection)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // UI Helpers for consistent defaults
    var defaultVisualType: StationVisualType {
        switch type {
        case .interchange, .depot: return .filledSquare
        default: return .filledCircle
        }
    }
    
    var defaultColor: String {
        switch type {
        case .interchange: return "#FF3B30" // Red
        case .depot: return "#FF9500" // Orange
        default: return "#000000" // Black
        }
    }
}

// Categorie Treni con parametri predefiniti
enum TrainCategory: String, CaseIterable, Identifiable {
    case regional = "Regionale"
    case direct = "Diretto"
    case highSpeed = "Alta Velocità"
    case freight = "Merci"
    case support = "Supporto"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .regional: return "regional_train".localized
        case .direct: return "intercity_train".localized
        case .highSpeed: return "highspeed_train".localized
        case .freight: return "freight_train".localized
        case .support: return "support_train".localized
        }
    }
    
    var defaultMaxSpeed: Int {
        switch self {
        case .highSpeed: return 300
        case .regional: return 140
        case .direct: return 160
        case .freight: return 100
        case .support: return 80
        }
    }
    
    var defaultPriority: Int {
        switch self {
        case .highSpeed: return 10
        case .direct: return 7
        case .regional: return 5
        case .freight: return 3
        case .support: return 1
        }
    }
}

// Binario (arco del grafo)
struct Edge: Identifiable, Codable, Hashable {
    enum TrackType: String, Codable, CaseIterable, Identifiable {
        case highSpeed, regional, single, double
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .highSpeed: return "AV"
            case .regional: return "Reg"
            case .single: return "Sing"
            case .double: return "Dop"
            }
        }
        
        var color: Color {
            switch self {
            case .highSpeed: return .red
            case .regional: return .blue
            case .single: return .gray
            case .double: return .gray
            }
        }
    }
    var id: UUID = UUID()
    var from: String // id nodo di partenza
    var to: String   // id nodo di arrivo
    var distance: Double
    var trackType: TrackType
    var maxSpeed: Int
    var capacity: Int?

    var canonicalKey: String {
        let sorted = [from, to].sorted()
        return "\(sorted[0])-\(sorted[1])"
    }

    enum CodingKeys: String, CodingKey {
        case id, from, to, distance, trackType, maxSpeed, capacity
    }

    init(id: UUID = UUID(), from: String, to: String, distance: Double, trackType: TrackType, maxSpeed: Int, capacity: Int? = nil) {
        self.id = id
        self.from = from
        self.to = to
        self.distance = distance
        self.trackType = trackType
        self.maxSpeed = maxSpeed
        self.capacity = capacity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 1.0
        trackType = try container.decodeIfPresent(TrackType.self, forKey: .trackType) ?? .regional
        maxSpeed = try container.decodeIfPresent(Int.self, forKey: .maxSpeed) ?? 120
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
    }
}

// Linea ferroviaria (insieme di stazioni con tempi di sosta) - Unificata con Relazione
struct RailwayLine: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: String? // ex: "#ff0000"
    var width: Double? // Line thickness in schematic view
    var originId: String = ""
    var destinationId: String = ""
    var stops: [RelationStop] = [] 
    
    // Train Numbering Logic
    var codePrefix: String? // e.g. "RE"
    var numberPrefix: Int? // e.g. 5 (results in 5001, 5002...)
    
    var stations: [String] {
        stops.map { $0.stationId }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, width, originId, destinationId, stops, codePrefix, numberPrefix
    }

    init(id: String, name: String, color: String? = nil, width: Double? = nil, originId: String = "", destinationId: String = "", stops: [RelationStop] = [], codePrefix: String? = nil, numberPrefix: Int? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.width = width
        self.originId = originId
        self.destinationId = destinationId
        self.stops = stops
        self.codePrefix = codePrefix
        self.numberPrefix = numberPrefix
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "unnamed_line".localized
        color = try container.decodeIfPresent(String.self, forKey: .color)
        width = try container.decodeIfPresent(Double.self, forKey: .width)
        originId = try container.decodeIfPresent(String.self, forKey: .originId) ?? ""
        destinationId = try container.decodeIfPresent(String.self, forKey: .destinationId) ?? ""
        stops = try container.decodeIfPresent([RelationStop].self, forKey: .stops) ?? []
        codePrefix = try container.decodeIfPresent(String.self, forKey: .codePrefix)
        numberPrefix = try container.decodeIfPresent(Int.self, forKey: .numberPrefix)
    }
}

// Fermata in una relazione (con tempo di sosta)
struct RelationStop: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var stationId: String
    var minDwellTime: Int = 3 // Minuit di sosta base (default 3)
    var extraDwellTime: Double = 0 // Ritardo extra da AI (minuti)
    var isSkipped: Bool = false // Se true, il treno non ferma (transito)
    var track: String? // Binario programmato (es: "1")
    
    // Per treni specifici: orari pianificati (opzionali, sovrascrivono il calcolo)
    var plannedArrival: Date?
    var plannedDeparture: Date?
    
    // Campi calcolati per visualizzazione/validazione corrente
    var arrival: Date?
    var departure: Date?

    enum CodingKeys: String, CodingKey {
        case id, stationId, minDwellTime, extraDwellTime, isSkipped, track, plannedArrival, plannedDeparture, arrival, departure
    }

    init(id: UUID = UUID(), stationId: String, minDwellTime: Int = 3, extraDwellTime: Double = 0, isSkipped: Bool = false, track: String? = nil, plannedArrival: Date? = nil, plannedDeparture: Date? = nil, arrival: Date? = nil, departure: Date? = nil) {
        self.id = id
        self.stationId = stationId
        self.minDwellTime = minDwellTime
        self.extraDwellTime = extraDwellTime
        self.isSkipped = isSkipped
        self.track = track
        self.plannedArrival = plannedArrival
        self.plannedDeparture = plannedDeparture
        self.arrival = arrival
        self.departure = departure
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        stationId = try container.decode(String.self, forKey: .stationId)
        minDwellTime = try container.decodeIfPresent(Int.self, forKey: .minDwellTime) ?? 3
        extraDwellTime = try container.decodeIfPresent(Double.self, forKey: .extraDwellTime) ?? 0
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
        track = try container.decodeIfPresent(String.self, forKey: .track)
        plannedArrival = try container.decodeIfPresent(Date.self, forKey: .plannedArrival)
        plannedDeparture = try container.decodeIfPresent(Date.self, forKey: .plannedDeparture)
        arrival = try container.decodeIfPresent(Date.self, forKey: .arrival)
        departure = try container.decodeIfPresent(Date.self, forKey: .departure)
    }
}


// Rete ferroviaria (grafo)
@MainActor
class RailwayNetwork: ObservableObject {
    @Published var name: String
    @Published var nodes: [Node]
    @Published var edges: [Edge]
    @Published var lines: [RailwayLine]
    
    var sortedLines: [RailwayLine] {
        lines.sorted { (a, b) -> Bool in
            let aPref = a.numberPrefix ?? Int.max
            let bPref = b.numberPrefix ?? Int.max
            if aPref != bPref {
                return aPref < bPref
            }
            return a.name < b.name
        }
    }

    var sortedNodes: [Node] {
        nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var sortedEdges: [Edge] {
        let nameLookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.name) })
        return edges.sorted { (a, b) -> Bool in
            let nameAFrom = nameLookup[a.from] ?? ""
            let nameBFrom = nameLookup[b.from] ?? ""
            if nameAFrom != nameBFrom {
                return nameAFrom.localizedStandardCompare(nameBFrom) == .orderedAscending
            }
            let nameATo = nameLookup[a.to] ?? ""
            let nameBTo = nameLookup[b.to] ?? ""
            return nameATo.localizedStandardCompare(nameBTo) == .orderedAscending
        }
    }
    
    // Undo Support
    private var undoStack: [RailwayNetworkDTO] = []
    private var redoStack: [RailwayNetworkDTO] = []
    @Published var canUndo = false
    @Published var canRedo = false
    private var isUndoing = false

    init(name: String, nodes: [Node] = [], edges: [Edge] = [], lines: [RailwayLine] = []) {
        self.name = name
        self.nodes = nodes
        self.edges = edges
        self.lines = lines
    }
    
    // MARK: - Infrastructure Validation
    
    /// Identifica binari doppi che non hanno il corrispondente arco di ritorno
    func checkMissingReturnTracks() -> [(from: String, to: String, type: Edge.TrackType)] {
        var missing: [(from: String, to: String, type: Edge.TrackType)] = []
        
        // Build map for fast lookup O(E)
        var edgeMap = Set<String>()
        for edge in edges {
            edgeMap.insert("\(edge.from)->\(edge.to)")
        }
        
        for edge in edges {
            // Se è doppio, AV o regionale (non esplicitamente single), deve avere un ritorno 
            // per essere considerato una tratta bidirezionale completa nel grafo
            if edge.trackType != .single {
                if !edgeMap.contains("\(edge.to)->\(edge.from)") {
                    missing.append((edge.from, edge.to, edge.trackType))
                }
            }
        }
        return missing
    }
    
    /// Crea i binari di ritorno mancanti
    func fixMissingTracks(_ missing: [(from: String, to: String, type: Edge.TrackType)]) {
        createCheckpoint()
        for m in missing {
            let newEdge = Edge(
                from: m.to,
                to: m.from,
                distance: edges.first(where: { $0.from == m.from && $0.to == m.to })?.distance ?? 1.0,
                trackType: m.type,
                maxSpeed: edges.first(where: { $0.from == m.from && $0.to == m.to })?.maxSpeed ?? 120,
                capacity: 10
            )
            edges.append(newEdge)
        }
    }
    
    func createCheckpoint() {
        guard !isUndoing else { return }
        let dto = self.toDTO()
        undoStack.append(dto)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
        updateUndoFlags()
    }
    
    func undo() {
        guard let last = undoStack.popLast() else { return }
        isUndoing = true
        let current = self.toDTO()
        redoStack.append(current)
        self.apply(dto: last)
        isUndoing = false
        updateUndoFlags()
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        isUndoing = true
        let current = self.toDTO()
        undoStack.append(current)
        self.apply(dto: next)
        isUndoing = false
        updateUndoFlags()
    }
    
    private func updateUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: - Gestione nodi e archi
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
    
    func removeEdge(_ from: String, _ to: String) {
        createCheckpoint()
        edges.removeAll { $0.from == from && $0.to == to }
    }
    
    /// Remove duplicate edges between the same stations
    func removeDuplicateEdges() {
        createCheckpoint()
        var seen = Set<String>()
        var uniqueEdges: [Edge] = []
        
        for edge in edges {
            // Create a key that's the same regardless of direction
            let key1 = "\(edge.from)-\(edge.to)"
            let key2 = "\(edge.to)-\(edge.from)"
            
            if !seen.contains(key1) && !seen.contains(key2) {
                seen.insert(key1)
                seen.insert(key2)
                uniqueEdges.append(edge)
            } else {
                print("🗑️ [CLEANUP] Removing duplicate edge: \(edge.from) <-> \(edge.to), type=\(edge.trackType.rawValue)")
            }
        }
        
        let removed = edges.count - uniqueEdges.count
        edges = uniqueEdges
        print("✅ [CLEANUP] Removed \(removed) duplicate edge(s). Total edges now: \(edges.count)")
    }
    
    /// Resetta l'intera rete e la cronologia (Irreversibile)
    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoFlags()
        
        nodes.removeAll()
        edges.removeAll()
        lines.removeAll()
    }

    // MARK: - Pathfinding (High Performance)
    
    func dijkstraAll(from start: String, isReverse: Bool = false, precalculatedAdj: [String: [Edge]]? = nil) -> (distances: [String: Double], previous: [String: String]) {
        return RailwayNetwork.dijkstraAll(from: start, nodes: nodes, edges: edges, isReverse: isReverse, precalculatedAdj: precalculatedAdj)
    }

    nonisolated static func dijkstraAll(from start: String, nodes: [Node], edges: [Edge], isReverse: Bool = false, precalculatedAdj: [String: [Edge]]? = nil) -> (distances: [String: Double], previous: [String: String]) {
        var distances = [String: Double]()
        var previous = [String: String]()
        
        let adj: [String: [Edge]]
        if let pre = precalculatedAdj {
            adj = pre
        } else {
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
            adj = tempAdj
        }
        
        for node in nodes { distances[node.id] = Double.infinity }
        distances[start] = 0
        
        var candidates: [String] = [start]
        var visited = Set<String>()
        
        var loopCount = 0
        while !candidates.isEmpty {
            loopCount += 1
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

    func findShortestPath(from start: String, to end: String) -> ([String], Double)? {
        return RailwayNetwork.findShortestPath(from: start, to: end, nodes: nodes, edges: edges)
    }
    
    nonisolated static func findShortestPath(from start: String, to end: String, nodes: [Node], edges: [Edge]) -> ([String], Double)? {
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

    func calculatePathDistance(_ path: [String]) -> Double {
        return RailwayNetwork.calculatePathDistance(path, edges: edges)
    }
    
    nonisolated static func calculatePathDistance(_ path: [String], edges: [Edge]) -> Double {
        guard path.count > 1 else { return 0 }
        var total: Double = 0
        for i in 0..<(path.count - 1) {
            let from = path[i]
            let to = path[i+1]
            if let edge = edges.first(where: { 
                ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) 
            }) {
                total += edge.distance
            }
        }
        return total
    }

    func findAlternativePaths(from start: String, to end: String) -> [(path: [String], distance: Double, description: String)] {
        return RailwayNetwork.findAlternativePaths(from: start, to: end, nodes: nodes, edges: edges)
    }
    
    nonisolated static func findAlternativePaths(from start: String, to end: String, nodes: [Node], edges: [Edge]) -> [(path: [String], distance: Double, description: String)] {
        // Pre-calculate adjacency lists for both directions to reuse
        var forwardAdj = [String: [Edge]]()
        var backwardAdj = [String: [Edge]]()
        for edge in edges {
            forwardAdj[edge.from, default: []].append(edge)
            if edge.trackType == .single { forwardAdj[edge.to, default: []].append(edge) }
            
            backwardAdj[edge.to, default: []].append(edge)
            if edge.trackType == .single { backwardAdj[edge.from, default: []].append(edge) }
        }

        var alternatives: [(path: [String], distance: Double, description: String)] = []
        
        let forward = dijkstraAll(from: start, nodes: nodes, edges: edges, isReverse: false, precalculatedAdj: forwardAdj)
        if let dEnd = forward.distances[end], dEnd != .infinity {
            var path: [String] = []
            var u: String? = end
            while let node = u, node != start { path.append(node); u = forward.previous[node] }
            if u == start {
                path.append(start)
                path.reverse()
                alternatives.append((path, dEnd, "Diretto"))
            }
        }
        
        let backward = dijkstraAll(from: end, nodes: nodes, edges: edges, isReverse: true, precalculatedAdj: backwardAdj)
        let interchanges = nodes.filter { $0.type == .interchange && $0.id != start && $0.id != end }
        
        func stationName(_ id: String) -> String {
            return nodes.first(where: { $0.id == id })?.name ?? "Sconosciuta"
        }

        for mid in interchanges {
            let d1 = forward.distances[mid.id] ?? .infinity
            let d2 = backward.distances[mid.id] ?? .infinity
            
            if d1 != .infinity && d2 != .infinity {
                var p1: [String] = []
                var u1: String? = mid.id
                while let n = u1, n != start { p1.append(n); u1 = forward.previous[n] }
                if u1 != start { continue }
                p1.append(start)
                p1.reverse()
                
                var p2: [String] = []
                var curr: String? = mid.id
                while let n = curr, n != end {
                    curr = backward.previous[n]
                    if let next = curr { p2.append(next) }
                }
                if p2.last != end { continue }
                
                let fullPath = p1 + p2
                if Set(fullPath).count == fullPath.count {
                    if !alternatives.contains(where: { $0.path == fullPath }) {
                        alternatives.append((fullPath, d1 + d2, "Via \(mid.name)"))
                    }
                }
            }
        }
        return alternatives.sorted { $0.distance < $1.distance }
    }
    
    func findPathEdges(from startId: String, to endId: String) -> [Edge]? {
        return RailwayNetwork.findPathEdges(from: startId, to: endId, edges: edges)
    }
    
    nonisolated static func findPathEdges(from startId: String, to endId: String, edges: [Edge]) -> [Edge]? {
        guard startId != endId else { return [] }
        
        // Simplified BFS to find edge sequence
        var queue: [(String, [Edge])] = [(startId, [])]
        var visited = Set<String>([startId])
        
        var head = 0
        while head < queue.count {
            let (curr, path) = queue[head]
            head += 1
            
            if curr == endId { return path }
            
            for edge in edges {
                if edge.from == curr {
                    if !visited.contains(edge.to) {
                        visited.insert(edge.to)
                        queue.append((edge.to, path + [edge]))
                    }
                } else if edge.to == curr {
                    if !visited.contains(edge.from) {
                        visited.insert(edge.from)
                        queue.append((edge.from, path + [edge]))
                    }
                }
            }
        }
        return nil
    }
}

extension RailwayNetwork {
    static let fileType = UTType(exportedAs: "it.fdc.railwaynetwork")
    
    func saveToFile(url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let dto = self.toDTO()
        let data = try encoder.encode(dto)
        try data.write(to: url)
    }
    
    static func loadFromFile(url: URL) throws -> RailwayNetworkDTO {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(RailwayNetworkDTO.self, from: data)
    }
}
