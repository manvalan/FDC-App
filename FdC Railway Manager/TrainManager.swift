import Foundation
import Combine

struct Train: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: String
    var maxSpeed: Int
    var priority: Int = 5 // 1-10, 10 is max priority (AV)
    var acceleration: Double = 0.5 // m/s^2
    var deceleration: Double = 0.5 // m/s^2
    var relationId: UUID? // Link to TrainRelation template
    var departureTime: Date? // Scheduled Departure Time
    var stops: [RelationStop] = [] // Snapshot of stops for per-train overrides
    
    init(id: UUID, name: String, type: String, maxSpeed: Int, priority: Int = 5, acceleration: Double = 0.5, deceleration: Double = 0.5, relationId: UUID? = nil, departureTime: Date? = nil, stops: [RelationStop] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.maxSpeed = maxSpeed
        self.priority = priority
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.relationId = relationId
        self.departureTime = departureTime
        self.stops = stops
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
    
    // Trigger validation
    func validateSchedules(with network: RailwayNetwork) {
        refreshSchedules(with: network)
        conflictManager.detectConflicts(network: network, trains: trains)
    }
    
    // MARK: - Legacy Local Solver
    
    /// Resolves conflicts using the legacy FDC heuristic engine (Client-side)
    func solveConflictsLocally(network: RailwayNetwork) -> String {
        // 1. Build Schedules
        let simulator = FDCSimulator()
        var schedules: [TrainSchedule] = []
        
        for train in trains {
            guard let relId = train.relationId,
                  let relation = network.relations.first(where: { $0.id == relId }) else { continue }
            
            // Reconstruct route from relation stops
            var route: [String] = []
            if !relation.originId.isEmpty { route.append(relation.originId) }
            for stop in relation.stops {
                // Determine if we need to add intermediate stops?
                // For simplified logic, just use the stops as the route + destination
                if stop.stationId != relation.originId && stop.stationId != relation.destinationId {
                     route.append(stop.stationId)
                }
            }
             if !relation.destinationId.isEmpty { route.append(relation.destinationId) }
            
            // Build full route edges? 
            // FDCSimulator.buildSchedule expects a list of station IDs in order.
            // Let's assume relation.stops covers the path.
            // Actually, we must use `relation.stops` order.
            
            let orderedStops = relation.stops.map { $0.stationId }
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
    
    // Fix-up missing stops and calculate actual times
    func refreshSchedules(with network: RailwayNetwork) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)! // Sync with AI UTC
        
        func normalizeToRefDate(_ date: Date) -> Date {
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            return calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour, minute: components.minute, second: components.second)) ?? date
        }
        
        for i in trains.indices {
            guard let relId = trains[i].relationId,
                  let rel = network.relations.first(where: { $0.id == relId }) else { continue }
            
            // Fix-up: If stops snapshot is empty but relation has stops, clone them
            if trains[i].stops.isEmpty && !rel.stops.isEmpty {
                trains[i].stops = rel.stops
            }
            
            // Calculate Times
            guard let depTime = trains[i].departureTime else { continue }
            var currentTime = normalizeToRefDate(depTime)
            
            // Debug: Check if normalization resets day unexpectedly
            // print("Train \(trains[i].name): Raw Dep \(depTime) -> Norm \(currentTime)")
            
            var prevId = rel.originId
            
            for j in trains[i].stops.indices {
                // Dwell calculation for THIS stop
                let isSkipped = trains[i].stops[j].isSkipped
                let baseDwell = isSkipped ? 0 : 3.0 // PIGNOLO PROTOCOL: Hardcoded 3.0m base dwell
                let extraDwell = trains[i].stops[j].extraDwellTime
                let dwellDuration = (baseDwell + extraDwell) * 60
                
                if j == 0 {
                    // ORIGIN: Starts preparation before departure, leaves EXACTLY at depTime
                    trains[i].stops[j].arrival = currentTime.addingTimeInterval(-dwellDuration)
                    trains[i].stops[j].departure = currentTime
                    // From here on, currentTime will represent the moment the train starts moving onto a leg
                } else {
                    // LEG TRANSIT: Move from previous station to this one
                    if let path = network.findPathEdges(from: prevId, to: trains[i].stops[j].stationId) {
                        for edge in path {
                            let speed = min(Double(trains[i].maxSpeed), Double(edge.maxSpeed))
                            let hours = edge.distance / speed
                            currentTime = currentTime.addingTimeInterval(hours * 3600)
                        }
                    }
                    
                    // ARRIVAL: After leg transit
                    trains[i].stops[j].arrival = currentTime
                    
                    // DEPARTURE: After dwelling
                    let dep = currentTime.addingTimeInterval(dwellDuration)
                    trains[i].stops[j].departure = (j < trains[i].stops.count - 1) ? dep : nil
                    
                    // Advance currentTime for the START of the next leg
                    currentTime = dep
                }
                
                prevId = trains[i].stops[j].stationId
            }
        }
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

    func applyAdvancedResolutions(_ resolutions: [OptimizerResolution], network: RailwayNetwork) {
        objectWillChange.send() // Ensure UI starts reflecting changes
        
        // CRITICAL: Reset ALL trains extra dwells to baseline before applying the new global solution
        for i in trains.indices {
            for k in trains[i].stops.indices {
                trains[i].stops[k].extraDwellTime = 0
            }
        }
        
        for res in resolutions {
            // Translate Integer ID back to UUID
            if let trainUUID = RailwayAIService.shared.getTrainId(optimizerId: res.trainId),
               let idx = trains.firstIndex(where: { $0.id == trainUUID }) {
                
                // IMPORTANT: res.timeAdjustmentMin is relative to the time originally sent in the request.
                // To avoid stacking delays, we apply the shift to the departureTime.
                // Since we reset everything except departureTime, if we run again, we send the SHIFTED time.
                // AI then says 0 shift if it's already optimal.
                // So adding res.timeAdjustmentMin is correct for cumulative tracking IF the AI works with snapshots.
                
                let currentDeparture = trains[idx].departureTime ?? Date()
                let newDeparture = currentDeparture.addingTimeInterval(res.timeAdjustmentMin * 60)
                
                // 1. Update Departure Time
                trains[idx].departureTime = newDeparture
                
                // 2. Apply Intermediate Dwell Delays
                if let delays = res.dwellDelays, !delays.isEmpty {
                    // Map intermediate delays
                    let originId = network.relations.first(where: { $0.id == trains[idx].relationId })?.originId ?? trains[idx].stops.first?.stationId
                    let originIndex = trains[idx].stops.firstIndex(where: { $0.stationId == originId }) ?? 0
                    
                    for (k, extra) in delays.enumerated() {
                        let stopIdx = originIndex + k + 1 
                        if stopIdx < trains[idx].stops.count - 1 {
                            trains[idx].stops[stopIdx].extraDwellTime = extra
                        }
                    }
                }
                
                print("[Optimizer] Applied Resolution: \(trains[idx].name) +\(res.timeAdjustmentMin)m -> \(formatTime(newDeparture))")
            }
        }
        
        // Recalculate everything
        refreshSchedules(with: network)
        
        // Final notification to observers
        objectWillChange.send()
    }
}

