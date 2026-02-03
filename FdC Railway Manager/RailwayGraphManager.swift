import Foundation
import CoreLocation

// MARK: - Server-Side Models (Strict Mapping)

struct AGStation: Codable {
    let id: Int
    let name: String
    let lat: Double?
    let lon: Double?
    let num_platforms: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, lat, lon
        case num_platforms = "num_platforms"
    }
}

struct AGTrack: Codable {
    let id: Int
    let station_ids: [Int]
    let length_km: Double
    let is_single_track: Bool
    let capacity: Int
    let max_speed: Int? // Optional based on server spec, commonly 120-300
    
    enum CodingKeys: String, CodingKey {
        case id, length_km, is_single_track, capacity, max_speed
        case station_ids = "station_ids"
    }
}

struct AGTrain: Codable {
    let id: Int
    let priority: Int
    let position_km: Double
    let velocity_kmh: Double
    let current_track: Int
    let origin_station: Int 
    let destination_station: Int
    let scheduled_departure_time: String
    let planned_route: [Int]
    let min_dwell_minutes: Int
    let delay_minutes: Int
    let is_delayed: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, priority, position_km, velocity_kmh, current_track
        case origin_station, destination_station
        case scheduled_departure_time, planned_route
        case min_dwell_minutes, delay_minutes, is_delayed
    }
}

struct AGAIRequest: Codable {
    let trains: [AGTrain]
    let tracks: [AGTrack]
    let stations: [AGStation]
    let max_iterations: Int
    let ga_max_iterations: Int
    let ga_population_size: Int
}

// MARK: - RailwayGraphManager

class RailwayGraphManager {
    static let shared = RailwayGraphManager()
    
    // Internal Cache
    private var stationMapping: [String: Int] = [:]
    private var trackMapping: [String: Int] = [:]
    private var trainIdMap: [UUID: Int] = [:]
    
    // Adjacency List for navigation: StationID (Int) -> [TrackID (Int)]
    private var adjacencyList: [Int: [Int]] = [:]
    
    private init() {}
    
    // MARK: - 1. Load Network (From JSON or App Model)
    
    /// Loads the network structure and builds the internal graph/mapping.
    /// Used when initializing from a file or syncing with the active AppState `RailwayNetwork`.
    func loadNetwork(from network: RailwayNetwork) {
        stationMapping.removeAll()
        trackMapping.removeAll()
        adjacencyList.removeAll()
        
        let sortedNodes = network.nodes.sorted(by: { $0.id < $1.id })
        
        // 1. Map Stations
        for (index, node) in sortedNodes.enumerated() {
            stationMapping[node.id] = index
            adjacencyList[index] = []
        }
        
        // 2. Map Tracks (Smart Aggregation)
        // Group edges by their physical segment (sorted station pair) to determine real capacity
        var segmentGroups: [String: [Edge]] = [:]
        
        for edge in network.edges {
            let s1 = stationMapping[edge.from] ?? 0
            let s2 = stationMapping[edge.to] ?? 0
            let key = [s1, s2].sorted().map { String($0) }.joined(separator: "-")
            segmentGroups[key, default: []].append(edge)
        }
        
        var uniqueCount = 0
        var uniqueTracks: [AGTrack] = []
        
        // Sort keys to ensure deterministic ID generation
        for key in segmentGroups.keys.sorted() {
             guard let edges = segmentGroups[key], let firstEdge = edges.first else { continue }
             
             let s1 = stationMapping[firstEdge.from] ?? 0
             let s2 = stationMapping[firstEdge.to] ?? 0
             
             // Determine ID
             let trackId = 1000 + uniqueCount
             uniqueCount += 1
             
             // Map ALL original edges in this group to this new unique Track ID
             for edge in edges {
                 trackMapping[edge.id.uuidString] = trackId
             }
             
             // Smart Capacity Calculation:
             // - If explicit 'double', capacity is at least 2.
             // - If multiple edges exist (parallel tracks), capacity increases.
             // - Basic logic: 1 pair (A->B, B->A) = 1 Physical Track.
             // - 2 pairs (2x A->B, 2x B->A) = 2 Physical Tracks.
             
             // Determine base capacity from track type
             let isDual = firstEdge.trackType == .double || firstEdge.trackType == .highSpeed
             var baseCapacity = isDual ? 2 : 1
             
             // If we have more than 2 edges for the same segment, it implies parallel tracks
             if edges.count > 2 {
                 // E.g. 4 edges = 2 bidirectional tracks
                 baseCapacity = max(baseCapacity, edges.count / 2)
             }
             
             // HIGH PRIORITY: Use explicit capacity if set in the model
             if let explicitCap = firstEdge.capacity, explicitCap > 0 {
                 baseCapacity = explicitCap
             }
             
             let isSingle = baseCapacity == 1
             
             // Add to Graph
             adjacencyList[s1, default: []].append(trackId)
             adjacencyList[s2, default: []].append(trackId)
             
             uniqueTracks.append(AGTrack(
                id: trackId,
                station_ids: [s1, s2],
                length_km: firstEdge.distance,
                is_single_track: isSingle,
                capacity: baseCapacity,
                max_speed: firstEdge.maxSpeed
             ))
        }
        print("[RailwayGraphManager] Network Loaded. Stations: \(stationMapping.count), Segments: \(uniqueCount)")
    }
    
    // MARK: - 2. Generate AI Request
    
    /// Generates the strict JSON payload for the Python AI Server
    func generateAIRequestDictionary(for trains: [Train], network: RailwayNetwork) -> [String: Any]? {
        // We reuse the logic but return a dictionary instead of JSON string
        loadNetwork(from: network)
        
        var generatedTracks: [AGTrack] = []
        var segmentGroups: [String: [Edge]] = [:]
        for edge in network.edges {
            let s1 = stationMapping[edge.from] ?? 0
            let s2 = stationMapping[edge.to] ?? 0
            let key = [s1, s2].sorted().map { String($0) }.joined(separator: "-")
            segmentGroups[key, default: []].append(edge)
        }
        
        var processedIds = Set<Int>() 
        for key in segmentGroups.keys.sorted() {
             guard let edges = segmentGroups[key], let firstEdge = edges.first else { continue }
             guard let tId = trackMapping[firstEdge.id.uuidString] else { continue }
             if processedIds.contains(tId) { continue }
             processedIds.insert(tId)
             
             var baseCapacity = (firstEdge.trackType == .double) ? 2 : 1
             if edges.count > 2 { baseCapacity = max(baseCapacity, edges.count / 2) }
             if let explicitCap = firstEdge.capacity, explicitCap > 0 { baseCapacity = explicitCap }
             
             generatedTracks.append(AGTrack(
                id: tId,
                station_ids: [stationMapping[firstEdge.from] ?? 0, stationMapping[firstEdge.to] ?? 0],
                length_km: firstEdge.distance,
                is_single_track: baseCapacity == 1,
                capacity: baseCapacity,
                max_speed: firstEdge.maxSpeed
             ))
        }

        let stations: [AGStation] = network.nodes.compactMap { node in
            guard let id = stationMapping[node.id] else { return nil }
            
            return AGStation(
                id: id,
                name: node.name,
                lat: node.latitude,
                lon: node.longitude,
                num_platforms: node.platforms ?? (node.type == .interchange ? 4 : 2)
            )
        }.sorted(by: { $0.id < $1.id })
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let agTrains: [AGTrain] = trains.enumerated().map { index, train in
            trainIdMap[train.id] = index
            var routeIds: [Int] = []
            for i in 0..<(train.stops.count - 1) {
                let from = train.stops[i].stationId
                let to = train.stops[i+1].stationId
                if let edge = network.edges.first(where: {
                    ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from)
                }), let tId = trackMapping[edge.id.uuidString] {
                    routeIds.append(tId)
                }
            }
            let depTime = normalize(train.departureTime) ?? Date()
            return AGTrain(
                id: index,
                priority: train.priority,
                position_km: 0.0,
                velocity_kmh: Double(train.maxSpeed),
                current_track: routeIds.first ?? 0,
                origin_station: stationMapping[train.stops.first?.stationId ?? ""] ?? 0,
                destination_station: stationMapping[train.stops.last?.stationId ?? ""] ?? 0,
                scheduled_departure_time: timeFormatter.string(from: depTime),
                planned_route: routeIds,
                min_dwell_minutes: train.stops.map { $0.minDwellTime }.max() ?? 3,
                delay_minutes: 0,
                is_delayed: false
            )
        }
        
        let request = AGAIRequest(
            trains: agTrains,
            tracks: generatedTracks,
            stations: stations,
            max_iterations: 1000,
            ga_max_iterations: 300,
            ga_population_size: 100
        )
        
        if let data = try? JSONEncoder().encode(request),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return nil
    }
    
    func generateAIRequestJSON(for trains: [Train], network: RailwayNetwork) -> String? {
        // Ensure mappings are up to date (this populates uniqueTracks internally if we stored them, 
        // but currently loadNetwork doesn't store uniqueTracks in a property. 
        // We probably should to avoid recalculating it differently here!)
        
        // REFACTOR: We need to expose the uniqueTracks calculated in loadNetwork OR return them.
        // Let's modify loadNetwork to STORE uniqueTracks or return them, but generateAIRequest relies on stable mappings.
        // For safety, we'll re-run a generation-safe version here or rely on the mapping being correct.
        
        // To guarantee consistency, we will reconstruct the uniqueAGTracks array using the SAME logic 
        // or helper. Since we heavily upgraded logic above, we need to apply it here too.
        
        // Actually, best practice: loadNetwork should populate a cache of AGTracks too if we want to reuse it.
        // But for now, let's copy the smart aggregation logic here for the 'tracks' list generation phase.
        
        // 1. Re-run mapping to ensure consistency
        loadNetwork(from: network)
        
        // 2. Extract the AGTracks from the internal state we just built? 
        // loadNetwork didn't save AGTracks. Let's fix that pattern or re-generate.
        // We'll regenerate using the exact same loop logic which is deterministic.
        
        var generatedTracks: [AGTrack] = []
        var segmentGroups: [String: [Edge]] = [:]
        for edge in network.edges {
            let s1 = stationMapping[edge.from] ?? 0
            let s2 = stationMapping[edge.to] ?? 0
            let key = [s1, s2].sorted().map { String($0) }.joined(separator: "-")
            segmentGroups[key, default: []].append(edge)
        }
        
        // Use mapping to find ID
        var processedIds = Set<Int>() 
        
        // We need the exact track objects that match the trackMapping
        for key in segmentGroups.keys.sorted() {
             guard let edges = segmentGroups[key], let firstEdge = edges.first else { continue }
             guard let tId = trackMapping[firstEdge.id.uuidString] else { continue }
             
             if processedIds.contains(tId) { continue }
             processedIds.insert(tId)
             
             var baseCapacity = (firstEdge.trackType == .double) ? 2 : 1
             if edges.count > 2 { baseCapacity = max(baseCapacity, edges.count / 2) }
             if let explicitCap = firstEdge.capacity, explicitCap > 0 { baseCapacity = explicitCap }
             
             generatedTracks.append(AGTrack(
                id: tId,
                station_ids: [stationMapping[firstEdge.from] ?? 0, stationMapping[firstEdge.to] ?? 0],
                length_km: firstEdge.distance,
                is_single_track: baseCapacity == 1,
                capacity: baseCapacity,
                max_speed: firstEdge.maxSpeed
             ))
        }

        // 3. Convert Stations
        let stations: [AGStation] = network.nodes.compactMap { node in
            guard let id = stationMapping[node.id] else { return nil }
            return AGStation(
                id: id,
                name: node.name,
                lat: node.latitude,
                lon: node.longitude,
                num_platforms: node.platforms ?? (node.type == .interchange ? 4 : 2)
            )
        }.sorted(by: { $0.id < $1.id })
        
        
        // 3. Convert Trains
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let agTrains: [AGTrain] = trains.enumerated().map { index, train in
            trainIdMap[train.id] = index
            
            // Route Building
            var routeIds: [Int] = []
            for i in 0..<(train.stops.count - 1) {
                let from = train.stops[i].stationId
                let to = train.stops[i+1].stationId
                // Find edge
                if let edge = network.edges.first(where: {
                    ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from)
                }), let tId = trackMapping[edge.id.uuidString] {
                    routeIds.append(tId)
                }
            }
            
            let depTime = normalize(train.departureTime) ?? Date()
            
            return AGTrain(
                id: index,
                priority: train.priority,
                position_km: 0.0,
                velocity_kmh: Double(train.maxSpeed),
                current_track: routeIds.first ?? 0,
                origin_station: stationMapping[train.stops.first?.stationId ?? ""] ?? 0,
                destination_station: stationMapping[train.stops.last?.stationId ?? ""] ?? 0,
                scheduled_departure_time: timeFormatter.string(from: depTime),
                planned_route: routeIds,
                min_dwell_minutes: train.stops.map { $0.minDwellTime }.max() ?? 3,
                delay_minutes: 0,
                is_delayed: false
            )
        }
        
        // 4. Wrap Request
        let request = AGAIRequest(
            trains: agTrains,
            tracks: generatedTracks,
            stations: stations,
            max_iterations: 1000,
            ga_max_iterations: 300,
            ga_population_size: 100
        )
        
        // 5. Encode
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(request) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // Helper Time Normalizer
    private func normalize(_ date: Date?) -> Date? {
        guard let date = date else { return nil }
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
        return calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: comps.hour, minute: comps.minute, second: comps.second))
    }
    
    // MARK: - Compatibility helpers
    func getTrainUUID(fromId id: Int) -> UUID? {
        return trainIdMap.first(where: { $0.value == id })?.key
    }
    
    func getOriginalStationId(fromNumericId id: Int) -> String? {
        return stationMapping.first(where: { $0.value == id })?.key
    }
}
