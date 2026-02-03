import Foundation
import Combine

struct Train: Identifiable, Codable, Hashable {
    let id: UUID
    var number: Int // Numeric ID (e.g. 1234)
    var name: String // Train Name or Relation Name
    var type: String
    var maxSpeed: Int
    var priority: Int = 5 // 1-10, 10 is max priority (AV)
    var acceleration: Double = 0.5 // m/s^2
    var deceleration: Double = 0.5 // m/s^2
    var lineId: String? // Link to RailwayLine (unified template)
    var departureTime: Date? // Scheduled Departure Time
    var stops: [RelationStop] = [] // Snapshot of stops for per-train overrides
    
    enum CodingKeys: String, CodingKey {
        case id, number, name, type, maxSpeed, priority, acceleration, deceleration, lineId, departureTime, stops
    }

    init(id: UUID, number: Int, name: String, type: String, maxSpeed: Int, priority: Int = 5, acceleration: Double = 0.5, deceleration: Double = 0.5, lineId: String? = nil, departureTime: Date? = nil, stops: [RelationStop] = []) {
        self.id = id
        self.number = number
        self.name = name
        self.type = type
        self.maxSpeed = maxSpeed
        self.priority = priority
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.lineId = lineId
        self.departureTime = departureTime
        self.stops = stops
    }

    // PIGNOLO PROTOCOL: Resilient decoding for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Treno senza nome"
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "Regionale"
        maxSpeed = try container.decodeIfPresent(Int.self, forKey: .maxSpeed) ?? 120
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 5
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration) ?? 0.5
        deceleration = try container.decodeIfPresent(Double.self, forKey: .deceleration) ?? 0.5
        lineId = try container.decodeIfPresent(String.self, forKey: .lineId)
        departureTime = try container.decodeIfPresent(Date.self, forKey: .departureTime)
        stops = try container.decodeIfPresent([RelationStop].self, forKey: .stops) ?? []
    }
}

@MainActor
final class TrainManager: ObservableObject {
    @Published var trains: [Train] = []
    
    // Sub-Manager for Conflicts
    let conflictManager = ConflictManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward changes from ConflictManager to TrainManager observers
        conflictManager.$conflicts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func validateSchedules(with network: RailwayNetwork) {
        refreshSchedules(with: network)
        conflictManager.detectConflicts(network: network, trains: trains)
    }

    /// Generates full schedules for all trains for visualization/simulation
    func generateSchedules(with network: RailwayNetwork) -> [TrainSchedule] {
        var schedules: [TrainSchedule] = []
        for train in trains {
            let scheduleStops = train.stops.map { stop in
                ScheduleStop(
                    stationId: stop.stationId,
                    arrivalTime: stop.arrival,
                    departureTime: stop.departure,
                    platform: Int(stop.track ?? "1") ?? 1,
                    dwellsMinutes: stop.minDwellTime,
                    stationName: network.nodes.first(where: { $0.id == stop.stationId })?.name ?? stop.stationId
                )
            }
            let sch = TrainSchedule(trainId: train.id, trainName: train.name, stops: scheduleStops)
            schedules.append(sch)
        }
        return schedules
    }
    
    // MARK: - Legacy Local Solver
    
    /// Resolves conflicts using the legacy FDC heuristic engine (Client-side)
    func solveConflictsLocally(network: RailwayNetwork) -> String {
        // 1. Build Schedules
        let simulator = FDCSimulator()
        var schedules: [TrainSchedule] = []
        
        for train in trains {
            guard let lineId = train.lineId,
                  let line = network.lines.first(where: { $0.id == lineId }) else { continue }
            
            let orderedStops = line.stops.map { $0.stationId }
            let startTime = train.departureTime ?? Date()
            
            if let sch = FDCSchedulerEngine.buildSchedule(train: train, network: network, route: orderedStops, startTime: startTime) {
                schedules.append(sch)
            }
        }
        
        simulator.schedules = schedules
        
        // 2. Resolve
        simulator.resolveConflicts(trains: trains, network: network)
        
        // 3. Apply Back
        var updatesCount = 0
        for sch in simulator.schedules {
            if sch.totalDelayMinutes > 0 {
                if let index = trains.firstIndex(where: { $0.id == sch.trainId }) {
                    // Apply delay to initial departure
                    if let originalDep = trains[index].departureTime {
                        trains[index].departureTime = originalDep.addingTimeInterval(Double(sch.totalDelayMinutes) * 60.0)
                        updatesCount += 1
                        print("Adjusted \(trains[index].name) by \(sch.totalDelayMinutes) min")
                    }
                }
            }
        }
        
        validateSchedules(with: network)
        return "Risoluzione completata (Locale). Modificati \(updatesCount) orari."
    }
    
    /// Fix-up missing stops and calculate actual times
    ///   - network: La rete ferroviaria
    func refreshSchedules(with network: RailwayNetwork) {
        var dummyCache = [String: [Edge]]()
        refreshSchedules(with: network, pathCache: &dummyCache)
    }

    /// Fix-up missing stops and calculate actual times with an external path cache
    ///   - network: La rete ferroviaria
    ///   - pathCache: Un dizionario per memorizzare i percorsi e velocizzare ricalcoli massivi.
    func refreshSchedules(with network: RailwayNetwork, pathCache: inout [String: [Edge]]) {
        for i in trains.indices {
            guard let depTime = trains[i].departureTime, !trains[i].stops.isEmpty else { continue }
            
            // Re-normalize departure time to 2000-01-01 to ensure consistency
            var currentTime = depTime.normalized()
            
            // The schedule calculation should ALWAYS start from the train's FIRST stop.
            // Using the line's originId is incorrect if the train starts later or is a return trip.
            let originId = trains[i].stops.first?.stationId ?? ""
            var prevId = originId
            
            for j in trains[i].stops.indices {
                let stop = trains[i].stops[j]
                let isSkipped = stop.isSkipped
                let baseDwell = isSkipped ? 0 : Double(stop.minDwellTime)
                let extraDwell = stop.extraDwellTime
                let dwellDuration = (baseDwell + extraDwell) * 60
                
                if stop.stationId == originId && j == 0 {
                    // ORIGIN
                    trains[i].stops[j].arrival = nil
                    trains[i].stops[j].departure = stop.plannedDeparture?.normalized() ?? currentTime
                    currentTime = trains[i].stops[j].departure ?? currentTime
                } else {
                    // LEG TRANSIT - Calculate as continuous motion between stops
                    var legDistance: Double = 0
                    var legMinSpeed: Double = Double.infinity
                    var transitDuration: TimeInterval = 0
                    
                    let currentPrevId = trains[i].stops[j-1].stationId // Use the actual previous stop ID
                    let pathKey = "\(currentPrevId)--\(stop.stationId)"
                    
                    let path = pathCache[pathKey] ?? network.findPathEdges(from: currentPrevId, to: stop.stationId)
                    if let actualPath = path {
                        pathCache[pathKey] = actualPath
                    }
                    
                    if let actualPath = path {
                        for edge in actualPath {
                            legDistance += edge.distance
                            legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                        }
                    }
                    
                    if legDistance > 0 {
                        let hours = FDCSchedulerEngine.calculateTravelTime(
                            distanceKm: legDistance,
                            maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed,
                            train: trains[i],
                            initialSpeedKmh: 0,
                            finalSpeedKmh: 0
                        )
                        transitDuration = hours * 3600
                    }
                    
                    // Safety padding (35s margin for station entry/exit)
                    // PIGNOLO PROTOCOL: Use raw transit without arbitrary 35s padding to stay in sync with Neural AI
                    currentTime = currentTime.addingTimeInterval(transitDuration)
                    
                    // HIGHER PRECISION ROUNDING (1s sync with AI/ConflictManager)
                    let roundedArrivalSeconds = floor(currentTime.timeIntervalSinceReferenceDate + 0.5)
                    let roundedArrival = Date(timeIntervalSinceReferenceDate: roundedArrivalSeconds)
                    
                    let actualArrival = stop.plannedArrival?.normalized() ?? roundedArrival
                    trains[i].stops[j].arrival = actualArrival
                    
                    let earliestDeparture = actualArrival.addingTimeInterval(dwellDuration)
                    let targetDeparture = stop.plannedDeparture?.normalized() ?? earliestDeparture
                    
                    let finalDep = max(earliestDeparture, targetDeparture)
                    let roundedDepSeconds = floor(finalDep.timeIntervalSinceReferenceDate + 0.5)
                    let roundedDep = Date(timeIntervalSinceReferenceDate: roundedDepSeconds)
                    
                    trains[i].stops[j].departure = (j < trains[i].stops.count - 1) ? roundedDep : nil
                    currentTime = roundedDep
                }
                
                prevId = stop.stationId
            }
        }
        objectWillChange.send()
    }
}

// MARK: - AI Conflict Resolution Support
struct AIScheduleSuggestion: Codable {
    let trainId: UUID
    let newDepartureTime: String // HH:mm
    let stopAdjustments: [StopAdjustment]?
    
    struct StopAdjustment: Codable {
        let stationId: String
        let newMinDwellTime: Int
    }
}

extension TrainManager {
    func generateConflictReport(network: RailwayNetwork) -> String {
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
    }


    /// Applica i risultati dell'ottimizzatore V2 (Resolutions)
    func applyResolutions(_ resolutions: [RailwayAIResolution], network: RailwayNetwork, trainMapping: [UUID: Int]) {
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
        
        refreshSchedules(with: network)
        conflictManager.detectConflicts(network: network, trains: trains)
        objectWillChange.send()
    }
}

