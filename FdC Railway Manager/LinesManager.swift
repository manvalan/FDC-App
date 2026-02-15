import Foundation
import Combine
import SwiftUI

/// Operations: Gestione operativa di Linee e Treni.
/// Responsabile della validazione degli orari e del rilevamento conflitti.
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
    var onSchedulesChanged: (() -> Void)?
    
    var sortedLines: [RailwayLine] {
        lines.sorted { l1, l2 in
            let p1 = l1.numberPrefix ?? 9999
            let p2 = l2.numberPrefix ?? 9999
            if p1 != p2 { return p1 < p2 }
            return l1.name < l2.name
        }
    }
    
    unowned var network: NetworkModel
    let conflictManager = ConflictManager()
    private var pathCache: [String: [Edge]] = [:]
    private var cancellables = Set<AnyCancellable>()
    weak var owner: RailroadNetwork?
    
    init(network: NetworkModel) {
        self.network = network
        conflictManager.$conflicts
             .receive(on: RunLoop.main)
             .sink { [weak self] _ in self?.objectWillChange.send() }
             .store(in: &cancellables)
    }
    
    func createCheckpoint() {
        owner?.createCheckpoint()
    }
    
    // MARK: - Queries
    
    func findLine(id: String?) -> RailwayLine? {
        lines.first(where: { $0.id == id })
    }
    
    func trains(for line: RailwayLine) -> [Train] {
        trains.filter { $0.lineId == line.id }
    }
    
    func trains(for lineId: String) -> [Train] {
        trains.filter { $0.lineId == lineId }
    }
    
    var unassignedTrains: [Train] {
        trains.filter { $0.lineId == nil }
    }
    
    func getVehicleConflicts(for vehicleId: UUID) -> [VehicleConflict] {
        let vehicleTrains = trains.filter { $0.vehicleId == vehicleId && $0.departureTime != nil }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
        
        if vehicleTrains.count < 2 { return [] }
        
        var conflicts: [VehicleConflict] = []
        let minTurnaround: TimeInterval = 15 * 60 // 15 min buffer
        
        for i in 0..<vehicleTrains.count - 1 {
            let trainA = vehicleTrains[i]
            let trainB = vehicleTrains[i+1]
            
            guard let arrivalA = trainA.stops.last?.arrival,
                  let departureB = trainB.departureTime else { continue }
            
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
    
    // MARK: - Operations
    
    func autoAssignRollingStock(for lineId: String) {
        guard let line = findLine(id: lineId) else { return }
        let terminalPrefs = line.terminalTracks
        
        let dedicatedFleetIds = Set(trains.filter { $0.lineId == lineId }.compactMap { $0.vehicleId })
        let dedicatedFleet = vehicles.filter { dedicatedFleetIds.contains($0.id) }
        let otherFleet = vehicles.filter { !dedicatedFleetIds.contains($0.id) }
        
        var localTrains = self.trains
        let lineTrainsIndices = localTrains.indices.filter { localTrains[$0].lineId == lineId && localTrains[$0].departureTime != nil }
            .sorted { (localTrains[$0].departureTime ?? Date.distantPast) < (localTrains[$1].departureTime ?? Date.distantPast) }
        
        if lineTrainsIndices.isEmpty { return }
        
        for i in localTrains.indices {
            if localTrains[i].lineId == lineId { localTrains[i].vehicleId = nil }
        }
        
        var fleetStatus: [UUID: (station: String, time: Date, serviceCount: Int, track: String?)] = [:]
        let buffer: TimeInterval = 15 * 60
        
        for idx in lineTrainsIndices {
            let train = localTrains[idx]
            guard let depTime = train.departureTime,
                  let startStation = train.stops.first?.stationId else { continue }
            
            let candidates = fleetStatus.filter { $0.value.station == startStation && depTime >= $0.value.time.addingTimeInterval(buffer) }
            var bestCandidate: UUID? = candidates.filter { $0.value.serviceCount % 2 != 0 }.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key
            if bestCandidate == nil {
                bestCandidate = candidates.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key
            }
            
            if bestCandidate == nil {
                bestCandidate = dedicatedFleet.first(where: { fleetStatus[$0.id] == nil })?.id ?? otherFleet.first(where: { fleetStatus[$0.id] == nil })?.id
            }
            
            if let vid = bestCandidate {
                localTrains[idx].vehicleId = vid
                let currentStatus = fleetStatus[vid]
                let currentCount = currentStatus?.serviceCount ?? 0
                
                let originId = startStation
                let destId = localTrains[idx].stops.last?.stationId ?? ""
                
                // Logic for Departure Track:
                // 1. If vehicle just arrived here, use the arrival track (consistency).
                // 2. Else check if there is a mandatary terminal track for this line.
                // 3. Fallback to first available.
                
                var departureTrack: String? = nil
                
                if let status = currentStatus, status.station == originId, let lastTrack = status.track {
                     departureTrack = lastTrack
                } else {
                     departureTrack = terminalPrefs[originId] ?? line.terminalTracks[originId]
                }
                
                if let track = departureTrack {
                    localTrains[idx].stops[0].track = track
                    localTrains[idx].stops[0].isManualTrack = true
                }
                
                // Logic for Arrival Track:
                // 1. Check for terminal preference at destination.
                // 2. Retain departure track if single track shuttle (rare).
                // 3. Let scheduler decide (nil).
                
                let arrivalTrack = terminalPrefs[destId] ?? line.terminalTracks[destId]
                
                if let track = arrivalTrack {
                    let lastStopIdx = localTrains[idx].stops.count - 1
                    localTrains[idx].stops[lastStopIdx].track = track
                    // Update fleet status so next departure uses this track
                    let arrivalTime = localTrains[idx].stops[lastStopIdx].arrival ?? Date.distantFuture
                    fleetStatus[vid] = (destId, arrivalTime, currentCount + 1, track)
                } else {
                    // If no specific arrival track is forced, we let the scheduler pick one (usually default 1).
                    // BUT we must capture what the scheduler picks to reuse it for return!
                    // Since we are PRE-scheduling here, we will default to the LAST STOP's current default if available, or "1".
                     let lastStopIdx = localTrains[idx].stops.count - 1
                     let defaultTrack = localTrains[idx].stops[lastStopIdx].track ?? "1"
                     localTrains[idx].stops[lastStopIdx].track = defaultTrack
                     
                     let arrivalTime = localTrains[idx].stops[lastStopIdx].arrival ?? Date.distantFuture
                     fleetStatus[vid] = (destId, arrivalTime, currentCount + 1, defaultTrack)
                }
                
                let lastStopIdx = localTrains[idx].stops.count - 1
                localTrains[idx].stops[lastStopIdx].isManualTrack = true
                
                // Fleet status updated above
            }
        }
        self.trains = localTrains
        validateSchedules()
    }
    
    func validateSchedules() {
        guard !isValidating else { return }
        isValidating = true
        
        #if DEBUG
        print("🔄 [LinesManager] Validating schedules for \(trains.count) trains")
        #endif
        
        refreshSchedules()
        conflictManager.detectConflicts(nodes: network.nodes, edges: network.edges, trains: trains, pathCache: pathCache)
        onSchedulesChanged?()
        isValidating = false
        objectWillChange.send()
    }
    
    func refreshSchedules() {
        for i in trains.indices {
            trains[i].schedulingError = nil // Resetta errori precedenti
            guard let depTime = trains[i].departureTime, !trains[i].stops.isEmpty else { continue }
            var currentTime = depTime.normalized()
            let originId = trains[i].stops.first?.stationId ?? ""
            for j in trains[i].stops.indices {
                let stop = trains[i].stops[j]
                if stop.stationId == originId && j == 0 {
                    trains[i].stops[j].arrival = nil
                    let startPoint = (stop.plannedDeparture?.normalized() ?? currentTime).cleanSeconds()
                    trains[i].stops[j].departure = startPoint
                    currentTime = startPoint
                } else {
                    var legDistance: Double = 0
                    var legMinSpeed: Double = .infinity
                    let currentPrevId = trains[i].stops[j-1].stationId
                    let pathKey = "\(currentPrevId)--\(stop.stationId)"
                    // User Requirement: Use the path defined by the line (i.e., direct connection between stops).
                    // We enforce this by:
                    // 1. Ignoring direction (assume bidirectional physical track)
                    // 2. Restricting intermediate stations (path cannot jump through another station)
                    var path = pathCache[pathKey] ?? network.findPathEdges(
                        from: currentPrevId, 
                        to: stop.stationId, 
                        ignoreDirection: true, 
                        restrictIntermediateStations: true
                    )
                    
                    if path == nil {
                        // Soft fallback: Maybe there's a station in between that IS technically part of the track but not a stop? (Unlikely for "restrictIntermediateStations" logic which treats station nodes as walls).
                        // Let's try without restricting intermediate stations but still ignoring direction.
                        // This handles cases where user defined A->C but physically it is A->B->C and B is just a transit node in the graph (though usually B would be a stop).
                        path = network.findPathEdges(from: currentPrevId, to: stop.stationId, ignoreDirection: true)
                    }
                    
                    if let actualPath = path {
                        pathCache[pathKey] = actualPath
                        for edge in actualPath {
                            legDistance += edge.distance
                            legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                        }
                    } else {
                        // Hard fallback if graph is totally disconnected
                        if let edge = network.findEdge(from: currentPrevId, to: stop.stationId) {
                             legDistance += edge.distance
                             legMinSpeed = Double(edge.maxSpeed)
                        } else {
                             // Zero-distance safety
                             legDistance += 5.0
                             legMinSpeed = 60.0
                             #if DEBUG
                             print("⚠️ [LinesManager] Train '\(trains[i].name)': No path between \(currentPrevId) and \(stop.stationId). Using fallback 5km.")
                             #endif
                             trains[i].schedulingError = "Tratta interrotta: \(currentPrevId) -> \(stop.stationId)"
                        }
                    }
                    var transitDuration: TimeInterval = 0
                    if legDistance > 0 {
                        let hours = FDCSchedulerEngine.calculateTravelTime(distanceKm: legDistance, maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed, train: trains[i], initialSpeedKmh: 0, finalSpeedKmh: 0)
                        transitDuration = hours * 3600
                    }
                    currentTime = currentTime.addingTimeInterval(transitDuration)
                    let arrivalAt = Date(timeIntervalSinceReferenceDate: floor(currentTime.timeIntervalSinceReferenceDate + 0.5))
                    trains[i].stops[j].arrival = stop.plannedArrival?.normalized(relativeTo: currentTime) ?? arrivalAt
                    
                    let dwell = (stop.customDwellSeconds ?? (stop.isSkipped ? 0 : (Double(stop.minDwellTime) + stop.extraDwellTime) * 60))
                    let departureAt = trains[i].stops[j].arrival!.addingTimeInterval(dwell)
                    trains[i].stops[j].departure = (j < trains[i].stops.count - 1) ? Date(timeIntervalSinceReferenceDate: floor(departureAt.timeIntervalSinceReferenceDate + 0.5)).cleanSeconds() : nil
                    currentTime = trains[i].stops[j].departure ?? arrivalAt
                }
            }
        }
    }
    
    func generateSchedulesPreview(with customTrains: [Train]? = nil) -> [TrainSchedule] {
        let targetTrains = customTrains ?? self.trains
        let nodeNames = Dictionary(uniqueKeysWithValues: network.nodes.map { ($0.id, $0.name) })
        
        return targetTrains.map { train in
            let schedStops = train.stops.map { stop in
                ScheduleStop(
                    stationId: stop.stationId,
                    arrivalTime: stop.arrival,
                    departureTime: stop.departure,
                    platform: Int(stop.track ?? "1") ?? 1,
                    dwellsMinutes: stop.minDwellTime,
                    stationName: nodeNames[stop.stationId] ?? stop.stationId
                )
            }
            return TrainSchedule(trainId: train.id, trainName: train.name, stops: schedStops)
        }
    }
    
    func applyResolutions(_ resolutions: [RailwayAIResolution], network: NetworkModel, trainMapping: [UUID: Int]) {
        createCheckpoint()
        
        for resolution in resolutions {
            // Find the train by looking up the UUID from the mapping
            guard let trainUUID = trainMapping.first(where: { $0.value == resolution.train_id })?.key,
                  let trainIndex = trains.firstIndex(where: { $0.id == trainUUID }) else {
                continue
            }
            
            // 1. Time Shift
            if resolution.time_adjustment_min != 0, let originalDep = trains[trainIndex].departureTime {
                let adjustment = resolution.time_adjustment_min * 60
                trains[trainIndex].departureTime = originalDep.addingTimeInterval(adjustment)
            }
            
            // 2. Dwell Extensions
            if let dwells = resolution.dwell_delays, !dwells.isEmpty {
                for (i, delayMin) in dwells.enumerated() {
                    if i < trains[trainIndex].stops.count {
                        trains[trainIndex].stops[i].extraDwellTime = max(0, trains[trainIndex].stops[i].extraDwellTime + delayMin)
                    }
                }
            }
        }
        
        validateSchedules()
    }
    
    // MARK: - Factory
    
    func instantiateTrain(
        number: Int,
        name: String? = nil,
        category: TrainCategory,
        departureTime: Date,
        line: RailwayLine? = nil,
        stationSequence: [String],
        acceleration: Double,
        deceleration: Double,
        preferredTrack: String = "1",
        vehicleId: UUID? = nil
    ) -> Train {
        // VALIDATION: Ensure we have at least 2 stations for a valid train
        guard stationSequence.count >= 2 else {
            #if DEBUG
            print("⚠️ [LinesManager] WARNING: Attempted to create train with only \(stationSequence.count) station(s). Minimum is 2.")
            print("   Train number: \(number), Category: \(category.rawValue)")
            print("   Station sequence: \(stationSequence)")
            #endif
            // Return a minimal valid train with empty stops (will be filtered later)
            return Train(
                number: number,
                name: name ?? "\(category.rawValue) \(number)",
                type: category.rawValue,
                lineId: line?.id,
                departureTime: departureTime,
                stops: [],
                vehicleId: vehicleId,
                maxSpeed: Double(category.defaultMaxSpeed),
                acceleration: acceleration,
                deceleration: deceleration,
                priority: category.defaultPriority
            )
        }
        
        var stops: [RelationStop] = []
        for (index, stationId) in stationSequence.enumerated() {
            let node = network.nodes.first(where: { $0.id == stationId })
            let isInterchange = node?.type == .interchange
            let minDwell = isInterchange ? 5 : 3
            
            var stop = RelationStop(
                stationId: stationId,
                minDwellTime: minDwell,
                track: preferredTrack
            )
            
            // PIGNOLO PROTOCOL: Terminals use preferred track
            if index == 0 || index == stationSequence.count - 1 {
                stop.track = preferredTrack
                stop.isManualTrack = true
            }
            
            stops.append(stop)
        }
        
        let trainName = name ?? "\(category.rawValue) \(number)"
        
        return Train(
            number: number,
            name: trainName,
            type: category.rawValue,
            lineId: line?.id,
            departureTime: departureTime,
            stops: stops,
            vehicleId: vehicleId,
            maxSpeed: Double(category.defaultMaxSpeed),
            acceleration: acceleration,
            deceleration: deceleration,
            priority: category.defaultPriority
        )
    }
    
    // MARK: - Binding Helper
    func binding(for train: Train) -> Binding<Train>? {
        guard let index = trains.firstIndex(where: { $0.id == train.id }) else { return nil }
        return Binding(
            get: { self.trains[index] },
            set: { self.trains[index] = $0 }
        )
    }
}
