import Foundation
import Combine

/// I/O: Operazioni di salvataggio, caricamento ed importazione dati (FDC, OSM, ecc.).
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
            lines: railroad.network.lines,
            routes: railroad.lines.routes,
            trains: railroad.lines.trains,
            vehicles: railroad.lines.vehicles
        )
        
        do {
            let data = try JSONEncoder().encode(dto)
            try data.write(to: lastStateURL)
            print("💾 RailroadNetwork salvato correttamente")
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
            print("✅ RailroadNetwork caricato correttamente")
        } catch {
            print("❌ Errore durante il caricamento: \(error.localizedDescription)")
        }
    }
    
    private func populate(from dto: RailwayNetworkDTO) {
        guard let railroad = railroad else { return }
        var nodes = Self.sanitizeNodes(dto.nodes)
        var edges = dto.edges
        HubTopology.reconcileLegacyAVStations(nodes: &nodes, edges: &edges)
        railroad.network.nodes = nodes
        railroad.network.edges = edges
        railroad.network.lines = dto.lines ?? []
        railroad.lines.routes = dto.routes ?? []
        railroad.lines.trains = dto.trains ?? []
        railroad.lines.vehicles = dto.vehicles ?? []
        railroad.migrateDoubleTracksToSingle()
        railroad.migrateLineNodeOrdering()
        railroad.clearUndoHistory()
        railroad.processInfrastructure()
    }

    /// Rimuove ID duplicati e satelliti hub orfani (evita abort su Dictionary(uniqueKeysWithValues:)).
    private static func sanitizeNodes(_ nodes: [Node]) -> [Node] {
        var seen = Set<String>()
        let deduped = nodes.filter { seen.insert($0.id).inserted }
        if deduped.count != nodes.count {
            print("⚠️ Rimossi \(nodes.count - deduped.count) nodi con ID duplicato dal salvataggio")
        }
        let parentIds = Set(deduped.map(\.id))
        return deduped.map { node in
            var sanitized = node
            if let parentId = sanitized.parentHubId, !parentIds.contains(parentId) {
                sanitized.parentHubId = nil
                sanitized.hubOffsetDirection = nil
            }
            return sanitized
        }
    }

    func importFromFDC(data: Data) throws {
        guard let railroad = railroad else { return }
        let parsed = try FDCParser.parse(data: data)
        
        railroad.network.nodes = mapFDCNodes(parsed.stations)
        railroad.network.edges = mapFDCEdges(parsed.edges)
        railroad.network.lines = parsed.lines
        
        var tCopy = mapFDCTrains(parsed.trains)
        applyFDCSchedules(to: &tCopy, rawSchedules: parsed.rawSchedules)
        
        railroad.lines.trains = tCopy
        railroad.migrateDoubleTracksToSingle()
        railroad.migrateLineNodeOrdering()
        railroad.clearUndoHistory()
        railroad.lines.validateSchedules()
        railroad.processInfrastructure()
    }

    private func mapFDCNodes(_ stations: [FDCStation]) -> [Node] {
        return stations.map { fdc in
            let type: Node.NodeType = {
                switch fdc.type?.lowercased() {
                case "interchange": return .interchange
                case "depot": return .depot
                default: return .station
                }
            }()
            return Node(id: fdc.id, name: fdc.name, type: type, latitude: fdc.latitude, longitude: fdc.longitude, capacity: fdc.capacity, platforms: fdc.platformCount ?? 2)
        }
    }

    private func mapFDCEdges(_ edges: [FDCEdge]) -> [Edge] {
        return edges.map { fdc in
            let rawType = fdc.trackType?.lowercased() ?? "regional"
            let isLegacyDouble = rawType == "double"
            let type: Edge.TrackType = {
                switch rawType {
                case "highspeed", "high_speed": return .highSpeed
                case "single", "double": return .single
                default: return .regional
                }
            }()
            var edge = Edge(
                from: fdc.from, to: fdc.to,
                distance: fdc.distance ?? 1.0,
                trackType: type,
                maxSpeed: Int(fdc.maxSpeed ?? 120.0),
                capacity: fdc.capacity
            )
            if isLegacyDouble {
                edge.needsPairedMigration = true
            }
            return edge
        }
    }

    private func mapFDCTrains(_ trains: [FDCTrain]) -> [Train] {
        return trains.enumerated().map { (idx, fdc) in
            Train(id: UUID(), number: 1000 + idx, name: fdc.name, type: fdc.type ?? "Regionale", maxSpeed: Double(fdc.maxSpeed ?? 120), acceleration: fdc.acceleration ?? 0.5, deceleration: fdc.deceleration ?? 0.5, priority: fdc.priority ?? 5)
        }
    }

    private func applyFDCSchedules(to trains: inout [Train], rawSchedules: [FDCScheduleData]) {
        let iso8601 = ISO8601DateFormatter()
        let hhmm = createFormatter(format: "HH:mm")
        let hhmmss = createFormatter(format: "HH:mm:ss")
        
        func parse(_ s: String) -> Date? {
            return iso8601.date(from: s) ?? hhmmss.date(from: s) ?? hhmm.date(from: s)
        }
        
        for sch in rawSchedules {
            if let idx = trains.firstIndex(where: { $0.name == sch.train_id || $0.id.uuidString == sch.train_id }) {
                trains[idx].stops = parseStops(sch.stops, parse: parse)
                trains[idx].departureTime = trains[idx].stops.first?.departure
            }
        }
    }

    private func createFormatter(format: String) -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = format
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }

    private func parseStops(_ stopsData: [FDCStopData], parse: (String) -> Date?) -> [RelationStop] {
        var previousTime: Date? = nil
        var dayOffset: TimeInterval = 0
        let secondsPerDay: TimeInterval = 86400
        
        return stopsData.map { data in
            func adjust(_ date: Date?) -> Date? {
                guard let d = date else { return nil }
                var adjusted = d.addingTimeInterval(dayOffset)
                if let prev = previousTime, adjusted < prev {
                    adjusted = adjusted.addingTimeInterval(secondsPerDay)
                    dayOffset += secondsPerDay
                }
                previousTime = adjusted
                return adjusted
            }
            
            return RelationStop(
                stationId: data.node_id,
                minDwellTime: 2,
                track: data.platform.map { "\($0)" },
                arrival: adjust(parse(data.arrival)),
                departure: adjust(parse(data.departure))
            )
        }
    }
}
