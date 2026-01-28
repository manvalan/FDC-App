import Foundation

// Enhanced FDC parser supporting official JSON format and text fallback
class FDCParser {
    
    static func parse(data: Data) throws -> FDCNetworkParsed {
        let decoder = JSONDecoder()
        
        // 1. Try Official JSON format
        if let official = try? decoder.decode(FDCFileRoot.self, from: data) {
            return mapOfficial(official)
        }
        
        // 1b. Try Topology JSON format (nodes/links)
        if let topology = try? decoder.decode(FDCTopology.self, from: data) {
            return mapTopology(topology)
        }
        
        // 2. Try Legacy JSON format (Dictionary based)
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return mapLegacyDictionary(json)
        }
        
        // 3. Fallback to line-based text parsing (Heuristics)
        return try parseText(data: data)
    }
    
    private static func mapOfficial(_ root: FDCFileRoot) -> FDCNetworkParsed {
        let stations = root.network.nodes.map { 
            FDCStation(id: $0.id, name: $0.name, type: $0.type, latitude: $0.latitude, longitude: $0.longitude, capacity: $0.capacity, platformCount: $0.platform_count ?? $0.platforms)
        }
        
        let edges = root.network.edges.map {
            FDCEdge(from: $0.from_node, to: $0.to_node, distance: $0.distance, trackType: $0.track_type, maxSpeed: $0.max_speed, capacity: $0.capacity, bidirectional: $0.bidirectional)
        }
        
        let trains = root.trains.map {
            FDCTrain(id: $0.id, name: $0.name, type: $0.type, maxSpeed: Int($0.max_speed), acceleration: $0.acceleration, deceleration: $0.deceleration, priority: $0.priority)
        }
        
        let rawSchedules = root.schedules ?? []
        
        let lines = root.lines?.map { lineDTO in
            RailwayLine(
                id: lineDTO.id,
                name: lineDTO.name,
                color: lineDTO.color,
                originId: lineDTO.stations.first ?? "",
                destinationId: lineDTO.stations.last ?? "",
                stops: lineDTO.stations.map { RelationStop(stationId: $0, minDwellTime: 3) }
            )
        } ?? []
        
        return FDCNetworkParsed(
            name: "FDC Network",
            stations: stations,
            edges: edges,
            trains: trains,
            rawSchedules: rawSchedules,
            lines: lines
        )
    }
    
    private static func mapLegacyDictionary(_ dict: [String: Any]) -> FDCNetworkParsed {
        var stations: [FDCStation] = []
        var edges: [FDCEdge] = []
        
        // Extract Nodes
        if let nodes = dict["nodes"] as? [[String: Any]] {
            for n in nodes {
                let id = (n["id"] as? String) ?? (n["name"] as? String) ?? UUID().uuidString
                let name = (n["name"] as? String) ?? id
                stations.append(FDCStation(id: id, name: name, type: n["type"] as? String))
            }
        }
        
        // Extract Edges / Links
        let edgeKeys = ["edges", "links", "connections"]
        for key in edgeKeys {
            if let eArr = dict[key] as? [[String: Any]] {
                for e in eArr {
                    let from = (e["from"] as? String) ?? (e["from_node"] as? String) ?? (e["source"] as? String) ?? ""
                    let to = (e["to"] as? String) ?? (e["to_node"] as? String) ?? (e["target"] as? String) ?? ""
                    if !from.isEmpty && !to.isEmpty {
                        edges.append(FDCEdge(from: from, to: to, distance: e["distance"] as? Double ?? e["length"] as? Double ?? 1.0))
                    }
                }
            }
        }
        
        return FDCNetworkParsed(
            name: (dict["name"] as? String) ?? "Legacy Import",
            stations: stations,
            edges: edges,
            trains: [],
            rawSchedules: [],
            lines: []
        )
    }

    private static func mapTopology(_ topology: FDCTopology) -> FDCNetworkParsed {
        let stations = topology.nodes.map { 
            FDCStation(id: $0.id, name: $0.name, type: $0.type, latitude: $0.latitude, longitude: $0.longitude, capacity: $0.capacity, platformCount: $0.platform_count ?? $0.platforms)
        }
        
        let edges = topology.links.map {
            FDCEdge(from: $0.source, to: $0.target, distance: $0.length ?? 1.0, trackType: $0.track_type ?? "regional", maxSpeed: $0.max_speed ?? 120, capacity: 10, bidirectional: true)
        }
        
        return FDCNetworkParsed(
            name: "FDC Topology",
            stations: stations,
            edges: edges,
            trains: [],
            rawSchedules: [],
            lines: []
        )
    }
    
    private static func parseText(data: Data) throws -> FDCNetworkParsed {
        guard let text = String(data: data, encoding: .utf8) else { throw FDCParserError.invalidData }
        let lines: [String] = text.components(separatedBy: CharacterSet.newlines)
        var stations: [FDCStation] = []
        var edges: [FDCEdge] = []
        var trains: [FDCTrain] = []
        var timetable: [FDCTimetableEntry] = []
        var parsedLines: [RailwayLine] = []
        var seenStationIds = Set<String>()
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Station: Name
            if let idx = trimmed.firstIndex(of: ":"), (trimmed.lowercased().contains("stazione") || trimmed.lowercased().contains("station")) {
                let name = trimmed[trimmed.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
                let id = name.replacingOccurrences(of: " ", with: "_")
                if !seenStationIds.contains(id) {
                    seenStationIds.insert(id)
                    stations.append(FDCStation(id: id, name: name))
                }
            }
            
            // Edge: A -> B
            if trimmed.contains("->") || trimmed.contains("→") {
                let sep = trimmed.contains("->") ? "->" : "→"
                let parts = trimmed.components(separatedBy: sep)
                if parts.count >= 2 {
                    let from = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let to = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let fid = from.replacingOccurrences(of: " ", with: "_")
                    let tid = to.replacingOccurrences(of: " ", with: "_")
                    if !seenStationIds.contains(fid) { seenStationIds.insert(fid); stations.append(FDCStation(id: fid, name: from)) }
                    if !seenStationIds.contains(tid) { seenStationIds.insert(tid); stations.append(FDCStation(id: tid, name: to)) }
                    edges.append(FDCEdge(from: fid, to: tid, distance: 1.0))
                }
            }
        }
        
        if stations.isEmpty && edges.isEmpty { throw FDCParserError.empty }
        return FDCNetworkParsed(name: "Imported Network", stations: stations, edges: edges, trains: trains, rawSchedules: [], lines: parsedLines)
    }

    /// Normalize many common time formats into "HH:MM" (24h) or return nil.
    static func normalizeTimeString(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        
        // Handle ISO8601 like "2025-11-14T06:00:00"
        if s.contains("T") {
            let parts = s.components(separatedBy: "T")
            if parts.count >= 2 {
                let timePart = parts[1]
                let comps = timePart.components(separatedBy: ":")
                if comps.count >= 2 {
                    return "\(comps[0]):\(comps[1])"
                }
            }
        }

        // Clean up string
        let allowed = CharacterSet(charactersIn: "0123456789:.,")
        s = s.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
        if s.isEmpty { return nil }
        
        if s.contains(":") {
            let parts = s.components(separatedBy: ":")
            if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                if h >= 0 && h < 24 && m >= 0 && m < 60 {
                    return String(format: "%02d:%02d", h, m)
                }
            }
        }
        return nil
    }
}
