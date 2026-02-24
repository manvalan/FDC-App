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
    @Published var trains: [RailwayTrain] = [] {
        didSet { validateSchedules() }
    }
    @Published var vehicles: [RailwayVehicle] = [] {
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
        
        // 1. Setup: Identifica flotta e treni
        let dedicatedFleetIds = Set(trains.filter { $0.lineId == lineId }.compactMap { $0.vehicleId })
        let dedicatedFleet = vehicles.filter { dedicatedFleetIds.contains($0.id) }
        let otherFleet = vehicles.filter { !dedicatedFleetIds.contains($0.id) }
        
        // Ordiniamo i treni per orario di partenza
        var localTrains = self.trains
        let lineTrainsIndices = localTrains.indices.filter { localTrains[$0].lineId == lineId && localTrains[$0].departureTime != nil }
            .sorted { (localTrains[$0].departureTime ?? Date.distantPast) < (localTrains[$1].departureTime ?? Date.distantPast) }
        
        if lineTrainsIndices.isEmpty { return }
        
        // 2. Reset: Rimuove assegnazioni precedenti per questa linea
        for i in lineTrainsIndices {
            localTrains[i].vehicleId = nil
        }
        
        // 3. Simulation State: Traccia lo stato di ogni veicolo (dove e quando è disponibile)
        // [VehicleID : (stationId, availableTime, tripCount, lastTrack)]
        var fleetStatus: [UUID: (station: String, time: Date, serviceCount: Int, track: String?)] = [:]
        let buffer: TimeInterval = 15 * 60 // 15 minuti di giro macchina
        
        // Helper per determinare il binario di attestamento stabile
        func getStableTerminalTrack(stationId: String) -> String {
            if let prefs = line.terminalTracks[stationId] { return prefs }
            
            // PIGNOLO: Check routing constraints for departure direction
            let nextId = line.stations.first(where: { $0 != stationId }) // Simple heuristic for terminus
            let best = getBestTrack(stationId: stationId, directionId: nextId, lineId: line.id)
            if best != "1" { return best }
            
            let stationNode = network.nodes.first(where: { $0.id == stationId })
            let platformCount = stationNode?.platforms ?? 2
            let lineInt = line.numberPrefix ?? 1
            let trackNum = (lineInt % platformCount) + 1
            return "\(trackNum)"
        }
        
        for idx in lineTrainsIndices {
            let train = localTrains[idx]
            guard let depTime = train.departureTime,
                  let startStation = train.stops.first?.stationId,
                  let endStation = train.stops.last?.stationId else { continue }
            
            // A. Trova veicolo disponibile
            // Criteri:
            // 1. Deve essere alla stazione di partenza 'startStation'
            // 2. Deve essere disponibile prima di 'depTime' (considerando buffer 15 min)
            let isLineElectrified = InfrastructureService(network: network).checkPathElectrification(stationIds: line.stops.map { $0.stationId })
            
            let candidates = fleetStatus.filter { (vid, status) -> Bool in
                guard let v: RailwayVehicle = vehicles.first(where: { (veh: RailwayVehicle) in veh.id == vid }) else { return false }
                
                // Filtro elettrificazione
                if !isLineElectrified && v.isElectric {
                    return false // Treno elettrico su linea non elettrificata
                }
                
                return status.station == startStation && depTime >= status.time.addingTimeInterval(buffer)
            }
            
            // Strategia di scelta:
            // - Priorità 1: Veicolo che deve "chiudere" il giro (numero corse dispari) -> Ritorno
            // - Priorità 2: Veicolo con meno corse totali (Bilanciamento usura)
            let oddServiceCandidates = candidates.filter { $0.value.serviceCount % 2 != 0 }
            var bestCandidate: UUID? = oddServiceCandidates.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key
            
            if bestCandidate == nil {
                // Se nessun ritorno prioritario, prendi qualsiasi disponibile, preferendo chi ha lavorato meno
                bestCandidate = candidates.min(by: { $0.value.serviceCount < $1.value.serviceCount })?.key
            }
            
            // Se ancora null, prendiamo un veicolo nuovo dalla flotta (prima dedicata, poi altra)
            if bestCandidate == nil {
                bestCandidate = dedicatedFleet.first(where: { v in
                    fleetStatus[v.id] == nil && (!isLineElectrified ? !v.isElectric : true)
                })?.id 
                ?? otherFleet.first(where: { v in
                    fleetStatus[v.id] == nil && (!isLineElectrified ? !v.isElectric : true)
                })?.id
            }
            
            // B. Assegna e Aggiorna
            if let vid = bestCandidate {
                // Assegna ID veicolo al treno
                localTrains[idx].vehicleId = vid
                
                let currentStatus = fleetStatus[vid]
                let currentCount = currentStatus?.serviceCount ?? 0
                
                // TRACK MANAGEMENT ---------------------------------------------------------
                // 1. Binario di Partenza
                // Se il veicolo era già lì, DEVE ripartire dallo stesso binario dove è arrivato (giro macchina)
                var departureTrack: String
                if let status = currentStatus, status.station == startStation, let lastTrack = status.track {
                    departureTrack = lastTrack
                } else {
                    // Se è un nuovo inserimento o reset, usa il binario stabile per questa linea
                    departureTrack = getStableTerminalTrack(stationId: startStation)
                }
                
                // Applica al primo stop
                localTrains[idx].stops[0].track = departureTrack
                localTrains[idx].stops[0].isManualTrack = true
                
                // 2. Binario di Arrivo
                // Usa sempre il binario stabile della linea per la destinazione
                let arrivalTrack = getStableTerminalTrack(stationId: endStation)
                
                let lastStopIdx = localTrains[idx].stops.count - 1
                localTrains[idx].stops[lastStopIdx].track = arrivalTrack
                localTrains[idx].stops[lastStopIdx].isManualTrack = true
                // --------------------------------------------------------------------------
                
                // Calcola orario di arrivo stimato per disponibilità futura
                let arrivalTime = localTrains[idx].stops[lastStopIdx].arrival ?? depTime.addingTimeInterval(3600) // Fallback +1h
                
                // Aggiorna stato flotta
                fleetStatus[vid] = (endStation, arrivalTime, currentCount + 1, arrivalTrack)
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
                        let isPrevSkipped = j > 0 ? (trains[i].stops[j-1].isSkipped) : false
                        let isCurrentSkipped = stop.isSkipped && j < trains[i].stops.count - 1
                        
                        let pathEdges = path ?? []
                        
                        let hours = FDCSchedulerEngine.calculatePathTravelTime(
                            edges: pathEdges.isEmpty ? (network.findEdge(from: currentPrevId, to: stop.stationId).map { [$0] } ?? []) : pathEdges, 
                            train: trains[i], 
                            nodes: network.nodes, 
                            isStarting: !isPrevSkipped, 
                            isStopping: !isCurrentSkipped, 
                            startNodeId: currentPrevId, 
                            endNodeId: stop.stationId
                        ) / 3600.0
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
        line: RailwayLine? = nil,
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
        // VALIDATION: Ensure we have at least 2 stations for a valid train
        guard stationSequence.count >= 2 else {
            #if DEBUG
            print("⚠️ [LinesManager] WARNING: Attempted to create train with only \(stationSequence.count) station(s). Minimum is 2.")
            print("   Train number: \(number), Category: \(category.rawValue)")
            print("   Station sequence: \(stationSequence)")
            #endif
            // Return a minimal valid train with empty stops (will be filtered later)
            let trainNumber: Int
            let fallbackName: String
            
            if let line = line, let lineCode = line.numberPrefix {
                trainNumber = lineCode * 100 + number
                if let prefix = line.codePrefix {
                    fallbackName = "\(prefix)\(lineCode) \(trainNumber)"
                } else {
                    fallbackName = "\(trainNumber)"
                }
            } else {
                trainNumber = number
                fallbackName = "\(number)"
            }
            
            return RailwayTrain(
                number: trainNumber,
                name: name ?? fallbackName,
                type: category.rawValue,
                lineId: line?.id,
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
            
            // PIGNOLO: Determine best track based on priority for this direction
            let nextId = (index < stationSequence.count - 1) ? stationSequence[index + 1] : nil
            let bestTrack = getBestTrack(stationId: stationId, directionId: nextId, lineId: line?.id, isSkipping: isSkipped)
            
            var stop = RelationStop(
                stationId: stationId,
                minDwellTime: minDwell,
                isSkipped: isSkipped,
                track: bestTrack
            )
            
            // PIGNOLO PROTOCOL: Terminals use preferred track and mark as manual to avoid accidental auto-shift
            if index == 0 || index == stationSequence.count - 1 {
                stop.isManualTrack = true
            }
            
            stops.append(stop)
        }
        
        let trainNumber: Int
        let trainName: String
        
        if let customName = name {
            trainNumber = number
            trainName = customName
        } else if let line = line, let _ = line.numberPrefix {
            trainNumber = number
            let formattedNumber = String(format: "%05d", number)
            if let prefix = line.codePrefix {
                trainName = "\(prefix)\(formattedNumber)"
            } else {
                trainName = "\(formattedNumber)"
            }
        } else {
            trainNumber = number
            trainName = "\(number)"
        }
        
        return RailwayTrain(
            number: trainNumber,
            name: trainName,
            type: category.rawValue,
            lineId: line?.id,
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
    ///   - lineId: ID della linea ferroviaria
    ///   - isSkipping: true se il treno transita senza fermarsi
    /// - Returns: Il binario preferito (es: "1", "2", etc.)
    func getBestTrack(stationId: String, directionId: String?, lineId: String?, isSkipping: Bool = false) -> String {
        guard let node = network.nodes.first(where: { $0.id == stationId }) else { return "1" }
        
        // Usa la logica unificata di Train.getPreferredTracks() per consistenza
        // Creiamo un train temporaneo per accedere al metodo di estensione
        let dummyTrain = RailwayTrain(
            number: 0,
            name: "",
            type: "R",
            lineId: lineId,
            departureTime: Date(),
            stops: [],
            maxSpeed: 100,
            acceleration: 0.5,
            deceleration: 0.5,
            mass: 200,
            power: 2500
        )
        
        let priorities = dummyTrain.getPreferredTracks(
            at: node,
            prevStationId: nil,
            nextStationId: directionId,
            for: nil,
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
