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
            ferrovie: railroad.network.ferrovie,
            lines: railroad.lines.lines,
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
        railroad.network.nodes = dto.nodes
        railroad.network.edges = dto.edges
        railroad.network.ferrovie = dto.ferrovie ?? []
        railroad.lines.lines = dto.lines ?? []
        railroad.lines.trains = dto.trains ?? []
        railroad.lines.vehicles = dto.vehicles ?? []
        
        InfrastructureManager.shared.processNetwork(railroad.network)
    }
    
    func importFromFDC(data: Data) throws {
        guard let railroad = railroad else { return }
        let parsed = try FDCParser.parse(data: data)
        
        // Mapping logic...
        let nodes = parsed.stations.map { fdcStation in
            let nodeType: Node.NodeType = {
                switch fdcStation.type?.lowercased() {
                case "interchange": return .interchange
                case "depot": return .depot
                default: return .station
                }
            }()
            return Node(id: fdcStation.id, name: fdcStation.name, type: nodeType, latitude: fdcStation.latitude, longitude: fdcStation.longitude, capacity: fdcStation.capacity, platforms: fdcStation.platformCount ?? 2)
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
        
        var trainIdMap: [String: UUID] = [:]
        var tCopy = parsed.trains.enumerated().map { (idx, fdcTrain) -> Train in
            let newId = UUID()
            trainIdMap[fdcTrain.id] = newId
            return Train(id: newId, number: 1000 + idx, name: fdcTrain.name, type: fdcTrain.type ?? "Regionale", maxSpeed: Double(fdcTrain.maxSpeed ?? 120), acceleration: fdcTrain.acceleration ?? 0.5, deceleration: fdcTrain.deceleration ?? 0.5, priority: fdcTrain.priority ?? 5)
        }
        
        let iso8601 = ISO8601DateFormatter()
        let hhmm = DateFormatter()
        hhmm.dateFormat = "HH:mm"
        hhmm.locale = Locale(identifier: "en_US_POSIX")
        
        let hhmmss = DateFormatter()
        hhmmss.dateFormat = "HH:mm:ss"
        hhmmss.locale = Locale(identifier: "en_US_POSIX")
        
        func parseTime(_ s: String) -> Date? {
            if let d = iso8601.date(from: s) { return d }
            if let d = hhmmss.date(from: s) { return d }
            if let d = hhmm.date(from: s) { return d }
            return nil
        }
        
        for sch in parsed.rawSchedules {
            if let swiftId = trainIdMap[sch.train_id], let tIdx = tCopy.firstIndex(where: { $0.id == swiftId }) {
                var previousTime: Date? = nil
                var dayOffset: TimeInterval = 0
                let secondsPerDay: TimeInterval = 86400
                
                tCopy[tIdx].stops = sch.stops.map { stopData in
                    var arrival = parseTime(stopData.arrival)?.addingTimeInterval(dayOffset)
                    if let arr = arrival, let prev = previousTime, arr < prev {
                        arrival = arr.addingTimeInterval(secondsPerDay)
                        dayOffset += secondsPerDay
                    }
                    if let arr = arrival { previousTime = arr }
                    
                    var departure = parseTime(stopData.departure)?.addingTimeInterval(dayOffset)
                    if let dep = departure, let prev = previousTime, dep < prev {
                        departure = dep.addingTimeInterval(secondsPerDay)
                        dayOffset += secondsPerDay
                    }
                    if let dep = departure { previousTime = dep }
                    
                    return RelationStop(
                        stationId: stopData.node_id,
                        minDwellTime: 2,
                        track: stopData.platform.map { "\($0)" },
                        arrival: arrival,
                        departure: departure
                    )
                }
                tCopy[tIdx].departureTime = tCopy[tIdx].stops.first?.departure
            }
        }
        
        railroad.network.nodes = nodes
        railroad.network.edges = edges
        railroad.lines.lines = parsed.lines
        railroad.lines.trains = tCopy
        
        railroad.lines.validateSchedules()
        InfrastructureManager.shared.processNetwork(railroad.network)
    }
}
