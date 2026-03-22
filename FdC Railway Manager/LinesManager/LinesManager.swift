import Foundation
import Combine
import SwiftUI

@MainActor
public final class LinesManager: ObservableObject {
    @Published var routes: [TrainRoute] = [] {
        didSet { validateSchedules() }
    }
    @Published var trains: [RailwayTrain] = [] {
        didSet { validateSchedules() }
    }
    @Published var vehicles: [RailwayVehicle] = [] {
        didSet { validateSchedules() }
    }
    
    private var isValidating = false
    var onSchedulesChanged: (() -> Void)?
    
    var sortedRoutes: [TrainRoute] {
        routes.sorted { r1, r2 in
            let p1 = r1.numberPrefix ?? 9999
            let p2 = r2.numberPrefix ?? 9999
            if p1 != p2 { return p1 < p2 }
            return r1.name < r2.name
        }
    }
    
    /// Backward compat alias — prefer `routes`.
    var lines: [TrainRoute] {
        get { routes }
        set { routes = newValue }
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
    
    func findRoute(id: String?) -> TrainRoute? {
        routes.first(where: { $0.id == id })
    }
    
    /// Backward compat alias — prefer `findRoute(id:)`.
    func findLine(id: String?) -> TrainRoute? { findRoute(id: id) }
    
    func trains(for route: TrainRoute) -> [Train] {
        trains.filter { $0.routeId == route.id }
    }
    
    func trains(for routeId: String) -> [Train] {
        trains.filter { $0.routeId == routeId }
    }
    
    var unassignedTrains: [Train] {
        trains.filter { $0.routeId == nil }
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
    
    func autoAssignRollingStock(for routeId: String) {
        guard let route = findRoute(id: routeId) else { return }
        
        let dedicatedFleetIds = Set(trains.filter { $0.routeId == routeId }.compactMap { $0.vehicleId })
        let dedicatedFleet = vehicles.filter { dedicatedFleetIds.contains($0.id) }
        let otherFleet = vehicles.filter { !dedicatedFleetIds.contains($0.id) }
        
        var localTrains = self.trains
        let routeTrainIndices = localTrains.indices
            .filter { localTrains[$0].routeId == routeId && localTrains[$0].departureTime != nil }
            .sorted { (localTrains[$0].departureTime ?? Date.distantPast) < (localTrains[$1].departureTime ?? Date.distantPast) }
        
        if routeTrainIndices.isEmpty { return }
        
        // Reset previous vehicle assignments for this route
        for i in routeTrainIndices {
            localTrains[i].vehicleId = nil
        }
        
        // 3. Simulation State: Traccia lo stato di ogni veicolo (dove e quando è disponibile)
        // [VehicleID : (stationId, availableTime, tripCount, lastTrack)]
        var fleetStatus: [UUID: (station: String, time: Date, serviceCount: Int, track: String?)] = [:]
        let buffer: TimeInterval = 15 * 60 // 15 minuti di giro macchina
        
        // Helper per determinare il binario di attestamento stabile
        func getStableTerminalTrack(stationId: String) -> String {
            let nextId = route.stationIds.first(where: { $0 != stationId })
            let best = getBestTrack(stationId: stationId, directionId: nextId, routeId: route.id)
            if best != "1" { return best }
            let stationNode = network.nodes.first(where: { $0.id == stationId })
            let platformCount = stationNode?.platforms ?? 2
            let lineInt = route.numberPrefix ?? 1
            return "\((lineInt % platformCount) + 1)"
        }
        
        for idx in routeTrainIndices {
            let train = localTrains[idx]
            guard let depTime = train.departureTime,
                  let startStation = train.stops.first?.stationId,
                  let endStation = train.stops.last?.stationId else { continue }
            
            // A. Trova veicolo disponibile
            let isLineElectrified = InfrastructureService(network: network)
                .checkPathElectrification(stationIds: route.stationIds)
            
            let vid = findBestVehicleCandidate(
                for: train,
                startStation: startStation,
                depTime: depTime,
                isLineElectrified: isLineElectrified,
                fleetStatus: fleetStatus,
                dedicatedFleet: dedicatedFleet,
                otherFleet: otherFleet
            )
            
            // B. Assegna e Aggiorna
            if let vid = vid {
                assignVehicleToTrain(
                    trainIdx: idx,
                    vehicleId: vid,
                    startStation: startStation,
                    endStation: endStation,
                    depTime: depTime,
                    fleetStatus: &fleetStatus,
                    localTrains: &localTrains,
                    route: route
                )
            }
        }
        
        self.trains = localTrains
        validateSchedules()
    }
    
    private func findBestVehicleCandidate(
        for train: Train,
        startStation: String,
        depTime: Date,
        isLineElectrified: Bool,
        fleetStatus: [UUID: (station: String, time: Date, serviceCount: Int, track: String?)],
        dedicatedFleet: [RailwayVehicle],
        otherFleet: [RailwayVehicle]
    ) -> UUID? {
        let buffer: TimeInterval = 15 * 60
        let candidates = fleetStatus.filter { (vid, status) -> Bool in
            guard let v = vehicles.first(where: { $0.id == vid }) else { return false }
            if !isLineElectrified && v.isElectric { return false }
            return status.station == startStation && depTime >= status.time.addingTimeInterval(buffer)
        }
        
        let oddServiceCandidates = candidates.filter { $0.value.serviceCount % 2 != 0 }
        if let best = oddServiceCandidates.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key {
            return best
        }
        
        if let best = candidates.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key {
            return best
        }
        
        return dedicatedFleet.first(where: { v in
            fleetStatus[v.id] == nil && (!isLineElectrified ? !v.isElectric : true)
        })?.id ?? otherFleet.first(where: { v in
            fleetStatus[v.id] == nil && (!isLineElectrified ? !v.isElectric : true)
        })?.id
    }

    private func assignVehicleToTrain(
        trainIdx: Int,
        vehicleId: UUID,
        startStation: String,
        endStation: String,
        depTime: Date,
        fleetStatus: inout [UUID: (station: String, time: Date, serviceCount: Int, track: String?)],
        localTrains: inout [RailwayTrain],
        route: TrainRoute
    ) {
        localTrains[trainIdx].vehicleId = vehicleId
        let currentStatus = fleetStatus[vehicleId]
        let currentCount = currentStatus?.serviceCount ?? 0
        
        let departureTrack = (currentStatus?.station == startStation)
            ? (currentStatus?.track ?? getStableTerminalTrack(stationId: startStation, route: route))
            : getStableTerminalTrack(stationId: startStation, route: route)
        
        localTrains[trainIdx].stops[0].track = departureTrack
        localTrains[trainIdx].stops[0].isManualTrack = true
        
        let arrivalTrack = getStableTerminalTrack(stationId: endStation, route: route)
        let lastStopIdx = localTrains[trainIdx].stops.count - 1
        localTrains[trainIdx].stops[lastStopIdx].track = arrivalTrack
        localTrains[trainIdx].stops[lastStopIdx].isManualTrack = true
        
        let arrivalTime = localTrains[trainIdx].stops[lastStopIdx].arrival ?? depTime.addingTimeInterval(3600)
        fleetStatus[vehicleId] = (endStation, arrivalTime, currentCount + 1, arrivalTrack)
    }

    private func getStableTerminalTrack(stationId: String, route: TrainRoute) -> String {
        let nextId = route.stationIds.first(where: { $0 != stationId })
        let best = getBestTrack(stationId: stationId, directionId: nextId, routeId: route.id)
        if best != "1" { return best }
        let stationNode = network.nodes.first(where: { $0.id == stationId })
        let platformCount = stationNode?.platforms ?? 2
        let lineInt = route.numberPrefix ?? 1
        return "\((lineInt % platformCount) + 1)"
    }
    func validateSchedules() {
        guard !isValidating else { return }
        isValidating = true
        
        #if DEBUG
        print("🔄 [LinesManager] Validating schedules for \(trains.count) trains")
        #endif
        
        refreshSchedules()
        conflictManager.refreshConflicts(nodes: network.nodes, edges: network.edges, trains: trains, pathCache: pathCache)
        onSchedulesChanged?()
        isValidating = false
        objectWillChange.send()
    }
    
    func refreshSchedules() {
        for i in trains.indices {
            trains[i].schedulingError = nil
            guard let depTime = trains[i].departureTime, !trains[i].stops.isEmpty else { continue }
            updateTrainStops(at: i, depTime: depTime)
        }
    }

    private func updateTrainStops(at index: Int, depTime: Date) {
        var currentTime = depTime.normalized()
        let originId = trains[index].stops.first?.stationId ?? ""
        
        for j in trains[index].stops.indices {
            if j == 0 && trains[index].stops[j].stationId == originId {
                currentTime = processFirstStop(at: index, currentTime: currentTime)
            } else {
                currentTime = processSubsequentStop(trainIdx: index, stopIdx: j, currentTime: currentTime)
            }
        }
    }

    private func processFirstStop(at trainIdx: Int, currentTime: Date) -> Date {
        trains[trainIdx].stops[0].arrival = nil
        let startPoint = (trains[trainIdx].stops[0].plannedDeparture?.normalized() ?? currentTime).cleanSeconds()
        trains[trainIdx].stops[0].departure = startPoint
        return startPoint
    }

    private func processSubsequentStop(trainIdx: Int, stopIdx: Int, currentTime: Date) -> Date {
        let prevId = trains[trainIdx].stops[stopIdx-1].stationId
        let currentId = trains[trainIdx].stops[stopIdx].stationId
        
        let transitDuration = calculateTransitDuration(trainIdx: trainIdx, stopIdx: stopIdx, from: prevId, to: currentId)
        let arrivalTime = currentTime.addingTimeInterval(transitDuration).normalized()
        
        trains[trainIdx].stops[stopIdx].arrival = trains[trainIdx].stops[stopIdx].plannedArrival?.normalized(relativeTo: arrivalTime) ?? arrivalAt(arrivalTime)
        
        let dwell = calculateDwellTime(trainIdx: trainIdx, stopIdx: stopIdx)
        let departureAt = trains[trainIdx].stops[stopIdx].arrival!.addingTimeInterval(dwell)
        
        if stopIdx < trains[trainIdx].stops.count - 1 {
            let departure = departureAt.cleanSeconds()
            trains[trainIdx].stops[stopIdx].departure = departure
            return departure
        } else {
            trains[trainIdx].stops[stopIdx].departure = nil
            return trains[trainIdx].stops[stopIdx].arrival!
        }
    }

    private func arrivalAt(_ time: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: floor(time.timeIntervalSinceReferenceDate + 0.5))
    }

    private func calculateTransitDuration(trainIdx: Int, stopIdx: Int, from: String, to: String) -> TimeInterval {
        let pathKey = "\(from)--\(to)"
        let path = pathCache[pathKey] ?? network.findPathEdges(from: from, to: to, ignoreDirection: true, restrictIntermediateStations: true)
                   ?? network.findPathEdges(from: from, to: to, ignoreDirection: true)
        
        if let actualPath = path {
            pathCache[pathKey] = actualPath
            let isPrevSkipped = stopIdx > 0 ? trains[trainIdx].stops[stopIdx-1].isSkipped : false
            let isCurrentSkipped = trains[trainIdx].stops[stopIdx].isSkipped && stopIdx < trains[trainIdx].stops.count - 1
            
            return FDCSchedulerEngine.calculatePathTravelTime(
                edges: actualPath,
                train: trains[trainIdx],
                nodes: network.nodes,
                isStarting: !isPrevSkipped,
                isStopping: !isCurrentSkipped,
                startNodeId: from,
                endNodeId: to
            )
        } else {
            return handleMissingPath(trainIdx: trainIdx, from: from, to: to)
        }
    }

    private func handleMissingPath(trainIdx: Int, from: String, to: String) -> TimeInterval {
        trains[trainIdx].schedulingError = "Tratta interrotta: \(from) -> \(to)"
        if let edge = network.findEdge(from: from, to: to) {
            return (edge.distance / 60.0) * 3600 // Fallback approx
        }
        return 300 // 5 min fallback
    }

    private func calculateDwellTime(trainIdx: Int, stopIdx: Int) -> TimeInterval {
        let stop = trains[trainIdx].stops[stopIdx]
        if let custom = stop.customDwellSeconds { return custom }
        if stop.isSkipped { return 0 }
        return (Double(stop.minDwellTime) + stop.extraDwellTime) * 60
    }
    
    func generateSchedulesPreview(with customTrains: [RailwayTrain]? = nil) -> [TrainSchedule] {
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
        route: TrainRoute? = nil,
        stationSequence: [String],
        acceleration: Double,
        deceleration: Double,
        mass: Double = 200,
        power: Double = 2500,
        preferredTrack: String = "1",
        vehicleId: UUID? = nil,
        skippedStopIds: Set<String> = [],
        isMainTrain: Bool = false
    ) -> RailwayTrain {
        guard stationSequence.count >= 2 else {
            let trainNumber: Int
            let fallbackName: String
            if let r = route, let prefix = r.numberPrefix {
                trainNumber = prefix * 100 + number
                fallbackName = r.serviceCodePrefix.map { "\($0)\(trainNumber)" } ?? "\(trainNumber)"
            } else {
                trainNumber = number
                fallbackName = "\(number)"
            }
            return RailwayTrain(
                number: trainNumber,
                name: name ?? fallbackName,
                type: category.rawValue,
                lineId: route?.id,
                departureTime: departureTime,
                stops: [],
                vehicleId: vehicleId,
                maxSpeed: Double(category.defaultMaxSpeed),
                acceleration: acceleration,
                deceleration: deceleration,
                mass: mass,
                power: power,
                priority: category.defaultPriority,
                isMainTrain: isMainTrain
            )
        }
        
        var stops: [RelationStop] = []
        for (index, stationId) in stationSequence.enumerated() {
            let minDwell = getStandardDwell(for: stationId)
            let isSkipped = skippedStopIds.contains(stationId)
            let nextId = (index < stationSequence.count - 1) ? stationSequence[index + 1] : nil
            let bestTrack = getBestTrack(stationId: stationId, directionId: nextId, routeId: route?.id, isSkipping: isSkipped)
            var stop = RelationStop(stationId: stationId, minDwellTime: minDwell, isSkipped: isSkipped, track: bestTrack)
            if index == 0 || index == stationSequence.count - 1 { stop.isManualTrack = true }
            stops.append(stop)
        }
        
        let trainNumber: Int
        let trainName: String
        if let customName = name {
            trainNumber = number
            trainName = customName
        } else if let r = route, r.numberPrefix != nil {
            trainNumber = number
            let formattedNumber = String(format: "%05d", number)
            trainName = r.serviceCodePrefix.map { "\($0)\(formattedNumber)" } ?? formattedNumber
        } else {
            trainNumber = number
            trainName = "\(number)"
        }
        
        return RailwayTrain(
            number: trainNumber,
            name: trainName,
            type: category.rawValue,
            lineId: route?.id,
            departureTime: departureTime,
            stops: stops,
            vehicleId: vehicleId,
            maxSpeed: Double(category.defaultMaxSpeed),
            acceleration: acceleration,
            deceleration: deceleration,
            mass: mass,
            power: power,
            priority: category.defaultPriority,
            isMainTrain: isMainTrain
        )
    }

    // MARK: - Binding Helper
    func binding(for train: RailwayTrain) -> Binding<RailwayTrain>? {
        guard let index = trains.firstIndex(where: { $0.id == train.id }) else { return nil }
        return Binding(
            get: { self.trains[index] },
            set: { self.trains[index] = $0 }
        )
    }

    func removeTrain(_ trainId: UUID) {
        createCheckpoint()
        trains.removeAll(where: { $0.id == trainId })
        validateSchedules()
    }

    // MARK: - Standard Dwells Logic
    
    func getStandardDwell(for stationId: String) -> Int {
        guard let node = network.nodes.first(where: { $0.id == stationId }) else { return 3 }
        if node.type == .interchange { return 5 }
        
        switch node.visualType {
        case .filledCircle, .emptyCircle:
            return 1
        case .emptySquare:
            return 2
        case .filledSquare, .filledStar:
            return 3
        default:
            return 3
        }
    }
    
    // MARK: - Track Priority Logic
    
    /// Restituisce il binario migliore per una stazione, direzione e linea specifiche.
    /// Usa la stessa logica di Train.getPreferredTracks() ma restituisce solo il primo.
    /// - Parameters:
    ///   - stationId: ID della stazione
    ///   - directionId: ID della prossima stazione (direzione)
    ///   - routeId: ID della rotta (servizio)
    ///   - isSkipping: true se il treno transita senza fermarsi
    /// - Returns: Il binario preferito (es: "1", "2", etc.)
    func getBestTrack(stationId: String, directionId: String?, routeId: String?, isSkipping: Bool = false) -> String {
        guard let node = network.nodes.first(where: { $0.id == stationId }) else { return "1" }
        
        // Usa la logica unificata di Train.getPreferredTracks() per consistenza
        // Creiamo un train temporaneo per accedere al metodo di estensione
        let dummyTrain = RailwayTrain(
            number: 0, name: "", type: "R",
            lineId: routeId,
            departureTime: Date(), stops: [],
            maxSpeed: 100, acceleration: 0.5, deceleration: 0.5, mass: 200, power: 2500
        )
        
        let priorities = dummyTrain.getPreferredTracks(
            at: node,
            prevStationId: nil as String?,
            nextStationId: directionId,
            for: nil as TrainRoute?,
            isSkipping: isSkipping
        )
        
        return priorities.first ?? "1"
    }
    
    func autoAssignTracksToAllTrains() {
        createCheckpoint()
        
        let conflictMgr = ConflictManager()
        let allTrains = self.trains
        
        for i in trains.indices {
            for j in trains[i].stops.indices {
                if trains[i].stops[j].isManualTrack { continue }
                
                let stationId = trains[i].stops[j].stationId
                let nextStationId = (j < trains[i].stops.count - 1) ? trains[i].stops[j+1].stationId : nil
                
                guard let node = network.nodes.first(where: { $0.id == stationId }) else { continue }
                
                let isSkipping = trains[i].stops[j].isSkipped
                let priorities = trains[i].getPreferredTracks(at: node, prevStationId: nil, nextStationId: nextStationId, for: nil, isSkipping: isSkipping)
                
                // PIGNOLO SMART ASSIGNMENT: Try to find the first FREE track among priorities
                var assigned = false
                if let arr = trains[i].stops[j].arrival, let dep = trains[i].stops[j].departure {
                    for track in priorities {
                        // Check if this track is free for this train (excluding itself)
                        if isTrackActuallyFree(stationId: stationId, track: track, from: arr, to: dep, excludingTrainId: trains[i].id) {
                            trains[i].stops[j].track = track
                            assigned = true
                            break
                        }
                    }
                }
                
                // Fallback: use first priority if no free one found or no times yet
                if !assigned, let first = priorities.first {
                    trains[i].stops[j].track = first
                }
            }
        }
        
        validateSchedules()
    }
    
    /// Helper per verificare se un binario è libero considerando tutti gli altri treni
    private func isTrackActuallyFree(stationId: String, track: String, from: Date, to: Date, excludingTrainId: UUID) -> Bool {
        let buffer: TimeInterval = 60 // 1 min buffer
        for t in trains {
            if t.id == excludingTrainId { continue }
            // Cerca se l'altro treno usa lo stesso binario nella stessa stazione
            guard let stop = t.stops.first(where: { $0.stationId == stationId && ($0.track ?? "1") == track }) else { continue }
            guard let arr = stop.arrival, let dep = stop.departure else { continue }
            
            // Verifica sovrapposizione temporale con buffer
            let overlapStart = max(from, arr)
            let overlapEnd = min(to, dep)
            if overlapStart < overlapEnd.addingTimeInterval(-buffer) {
                return false
            }
        }
        return true
    }
    
    func applyStandardDwellsToAllTrains() {
        createCheckpoint()
        for i in trains.indices {
            for j in trains[i].stops.indices {
                let stationId = trains[i].stops[j].stationId
                trains[i].stops[j].minDwellTime = getStandardDwell(for: stationId)
            }
        }
        validateSchedules()
    }
}
