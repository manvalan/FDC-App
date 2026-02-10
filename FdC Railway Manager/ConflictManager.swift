import Foundation
import SwiftUI
import Combine

// MARK: - Conflict Models

struct ScheduleConflict: Identifiable, Hashable {
    let trainAId: UUID
    let trainBId: UUID
    let trainAName: String
    let trainBName: String
    
    enum LocationType: String {
        case station = "Stazione"
        case line = "Linea"
        case routing = "Instradamento"
    }
    
    let locationType: LocationType
    let locationName: String 
    let locationId: String 
    let timeStart: Date
    let timeEnd: Date
    let capacity: Int
    let occupantsCount: Int
    
    var id: String {
        "\(trainAId.uuidString)_\(trainBId.uuidString)_\(locationId)_\(Int(timeStart.timeIntervalSince1970))"
    }
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let start = formatter.string(from: timeStart)
        let end = formatter.string(from: timeEnd)
        
        if locationType == .routing {
            return "instradamento_non_consentito_fmt".localizedFormat(trainAName, locationName)
        }
        
        let typeStr: String = {
            if locationId.hasPrefix("STATION_GLOBAL") { return "Stazione (Totale Binari)" }
            if locationId.hasPrefix("TRACK") { return "Binario Specifico" }
            if locationId.hasPrefix("SEGMENT") { return "Tratta / Segmento" }
            return "Risorsa"
        }()
        
        return String(format: "conflitto_capacita_fmt".localized, 
                      trainAName, trainBName, locationName, typeStr, capacity, start, end)
    }
}

// MARK: - Conflict Manager

class ConflictManager: ObservableObject {
    @Published var conflicts: [ScheduleConflict] = []
    @Published var lastResourceCapacities: [String: Int] = [:]
    
    // PIGNOLO: Cache for static resource capacities to avoid recomputing in GA loops
    private var cachedCapacities: [String: Int] = [:]
    private var lastNetworkId: String = ""
    
    func getResourceCapacities(nodes: [Node], edges: [Edge]) -> [String: Int] {
        var capacities: [String: Int] = [:]
        for node in nodes {
            let p = node.platforms ?? 2
            capacities["STATION_GLOBAL::\(node.id)"] = max(1, p)
        }
        
        var segmentEdges: [String: [Edge]] = [:]
        for edge in edges {
            let s1Id = edge.from < edge.to ? edge.from : edge.to
            let s2Id = edge.from < edge.to ? edge.to : edge.from
            segmentEdges["\(s1Id)--\(s2Id)", default: []].append(edge)
        }
        
        for (key, edges) in segmentEdges {
            let s1 = key.components(separatedBy: "--").first ?? ""
            let fwdEdges = edges.filter { $0.from == s1 }
            let bwdEdges = edges.filter { $0.to == s1 }
            
            let capFwd = fwdEdges.reduce(0) { sum, edge in
                let slots: Int
                switch edge.trackType {
                case .single, .regional: slots = 1
                case .double, .highSpeed: slots = 2
                }
                return sum + slots
            }
            
            let capBwd = bwdEdges.reduce(0) { sum, edge in
                let slots: Int
                switch edge.trackType {
                case .single, .regional: slots = 1
                case .double, .highSpeed: slots = 2
                }
                return sum + slots
            }
            
            var totalCap = capFwd + capBwd
            if totalCap == 0 { totalCap = 1 }
            
            capacities["SEGMENT::\(key)"] = totalCap
        }
        
        return capacities
    }
    
    // MARK: - Detect Methods
    
    func detectConflicts(nodes: [Node], edges: [Edge], trains: [Train], pathCache: [String: [Edge]]? = nil) {
        let nodesCopy = nodes
        let edgesCopy = edges
        let trainsCopy = trains
        var localCache = pathCache
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Calcola i conflitti di binario (occupazioni fisiche in stazione)
            let trackConflicts = self.calculateTrackConflicts(nodes: nodesCopy, trains: trainsCopy)
            
            // 2. Calcola i conflitti di orario (capacità tratte e capacità totale stazioni)
            let (scheduleConflicts, capacities) = self.calculateScheduleConflicts(nodes: nodesCopy, edges: edgesCopy, trains: trainsCopy, pathCache: &localCache)
            
            DispatchQueue.main.async {
                let allConflicts = (trackConflicts + scheduleConflicts)
                let sortedNew = Array(Set(allConflicts)).sorted(by: { $0.id < $1.id })
                
                if self.conflicts != sortedNew {
                    self.conflicts = sortedNew
                }
                self.lastResourceCapacities = capacities
            }
        }
    }

    /// Synchronous version for optimization loops (GA, Cadence, etc.)
    func calculateConflictsWithCapacities(nodes: [Node], edges: [Edge], trains: [Train], pathCache: inout [String: [Edge]]?) -> ([ScheduleConflict], [String: Int]) {
        let trackConflicts = calculateTrackConflicts(nodes: nodes, trains: trains)
        let (scheduleConflicts, capacities) = calculateScheduleConflicts(nodes: nodes, edges: edges, trains: trains, pathCache: &pathCache)
        
        let allConflicts = Array(Set(trackConflicts + scheduleConflicts)).sorted(by: { $0.id < $1.id })
        return (allConflicts, capacities)
    }

    // MARK: - Core Logic (Separated)
    
    /// Rileva occupazioni doppie sullo stesso binario specifico
    private func calculateTrackConflicts(nodes: [Node], trains: [Train]) -> [ScheduleConflict] {
        var conflicts: [ScheduleConflict] = []
        var trackOccupations: [String: [ResourceOccupation]] = [:]
        
        let vehicleMissions = prepareVehicleMissions(trains: trains)
        
        for train in trains {
            for stop in train.stops {
                guard !stop.isSkipped else { continue }
                let track = stop.track ?? "1"
                let resId = "TRACK::\(stop.stationId)::\(track)"
                
                let (occEntry, occExit) = calculateEffectiveOccupationTimes(train: train, stop: stop, vehicleMissions: vehicleMissions)
                
                let occ = ResourceOccupation(
                    trainId: train.id,
                    vehicleId: train.vehicleId,
                    trainName: train.name,
                    entry: occEntry.normalized(),
                    exit: occExit.normalized(),
                    resId: resId,
                    bufferMinutes: 2.0
                )
                trackOccupations[resId, default: []].append(occ)
            }
        }
        
        for (resId, occupations) in trackOccupations {
            conflicts.append(contentsOf: detectOverlaps(occupations: occupations, capacity: 1, resId: resId, nodes: nodes))
        }
        
        return conflicts
    }
    
    /// Rileva saturazione tratte o mancanza di binari totali in stazione
    private func calculateScheduleConflicts(nodes: [Node], edges: [Edge], trains: [Train], pathCache: inout [String: [Edge]]?) -> ([ScheduleConflict], [String: Int]) {
        var conflicts: [ScheduleConflict] = []
        var resourceOccupations: [String: [ResourceOccupation]] = [:]
        let resourceCapacities = getResourceCapacities(nodes: nodes, edges: edges)
        
        let vehicleMissions = prepareVehicleMissions(trains: trains)
        
        for train in trains {
            var prevId: String? = nil
            for stop in train.stops {
                if stop.isSkipped { continue }
                
                // Capacità Totale Stazione
                let resId = "STATION_GLOBAL::\(stop.stationId)"
                let (occEntry, occExit) = calculateEffectiveOccupationTimes(train: train, stop: stop, vehicleMissions: vehicleMissions)
                let occ = ResourceOccupation(
                    trainId: train.id,
                    vehicleId: train.vehicleId,
                    trainName: train.name,
                    entry: occEntry.normalized(),
                    exit: occExit.normalized(),
                    resId: resId,
                    bufferMinutes: 1.0
                )
                resourceOccupations[resId, default: []].append(occ)
                
                // Tratte (Segmenti)
                if let pId = prevId, let arrival = stop.arrival, let departurePrev = train.stops.first(where: { $0.stationId == pId })?.departure {
                    let pathKey = "\(pId)--\(stop.stationId)"
                    let path = pathCache?[pathKey] ?? NetworkModel.findPathEdges(from: pId, to: stop.stationId, edges: edges)
                    
                    if let actualPath = path {
                        pathCache?[pathKey] = actualPath
                        let totalDist = actualPath.reduce(0.0) { $0 + $1.distance }
                        let totalTime = arrival.timeIntervalSince(departurePrev)
                        let avgSpeed = totalDist > 0 ? (totalDist / (totalTime / 3600.0)) : 0.0
                        
                        var currentTime = departurePrev
                        for edge in actualPath {
                            let transitTime = avgSpeed > 0 ? (edge.distance / avgSpeed * 3600.0) : 0.0
                            let exitTime = currentTime.addingTimeInterval(transitTime)
                            let s1Id = edge.from < edge.to ? edge.from : edge.to
                            let s2Id = edge.from < edge.to ? edge.to : edge.from
                            let segId = "SEGMENT::\(s1Id)--\(s2Id)"
                            
                            let segOcc = ResourceOccupation(
                                trainId: train.id, 
                                vehicleId: train.vehicleId, 
                                trainName: train.name, 
                                entry: currentTime.normalized(), 
                                exit: exitTime.normalized(), 
                                resId: segId, 
                                bufferMinutes: 1.0
                            )
                            resourceOccupations[segId, default: []].append(segOcc)
                            currentTime = exitTime
                        }
                    }
                }
                prevId = stop.stationId
            }
        }
        
        for (resId, occupations) in resourceOccupations {
            let cap = resourceCapacities[resId] ?? 1
            conflicts.append(contentsOf: detectOverlaps(occupations: occupations, capacity: cap, resId: resId, nodes: nodes))
        }
        
        return (conflicts, resourceCapacities)
    }

    // MARK: - Helper Methods
    
    private struct ResourceOccupation {
        let trainId: UUID
        let vehicleId: UUID?
        let trainName: String
        let entry: Date
        let exit: Date
        let resId: String
        let bufferMinutes: Double
        
        init(trainId: UUID, vehicleId: UUID?, trainName: String, entry: Date, exit: Date, resId: String, bufferMinutes: Double) {
            self.trainId = trainId
            self.vehicleId = vehicleId
            self.trainName = trainName
            self.entry = entry
            self.exit = exit
            self.resId = resId
            self.bufferMinutes = bufferMinutes
        }
        
        func effectiveExit() -> Date {
            return exit.addingTimeInterval(bufferMinutes * 60)
        }
    }
    
    private func prepareVehicleMissions(trains: [Train]) -> [UUID: [(trainId: UUID, stationId: String, arrival: Date?, departure: Date?)]] {
        let vehicleGroups = Dictionary(grouping: trains.filter { $0.vehicleId != nil }, by: { $0.vehicleId! })
        var missions: [UUID: [(trainId: UUID, stationId: String, arrival: Date?, departure: Date?)]] = [:]
        
        for (vId, vTrains) in vehicleGroups {
            missions[vId] = vTrains.flatMap { t in
                t.stops.map { s in (trainId: t.id, stationId: s.stationId, arrival: s.arrival, departure: s.departure) }
            }.sorted { 
                ($0.arrival ?? $0.departure ?? Date.distantPast) < ($1.arrival ?? $1.departure ?? Date.distantPast)
            }
        }
        return missions
    }
    
    private func calculateEffectiveOccupationTimes(train: Train, stop: RelationStop, vehicleMissions: [UUID: [(trainId: UUID, stationId: String, arrival: Date?, departure: Date?)]]) -> (entry: Date, exit: Date) {
        let defaultBuffer: TimeInterval = 10 * 60 // 10 min default sosta se manca dato
        var entry = (stop.arrival ?? stop.departure?.addingTimeInterval(-defaultBuffer)) ?? Date()
        var exit = (stop.departure ?? stop.arrival?.addingTimeInterval(defaultBuffer)) ?? Date()
        
        if let vId = train.vehicleId, let missions = vehicleMissions[vId] {
            if let myIdx = missions.firstIndex(where: { $0.trainId == train.id && ($0.arrival == stop.arrival || $0.departure == stop.departure) }) {
                // Se il mezzo arriva da un altro treno NELLA STESSA STAZIONE, l'occupazione inizia dall'arrivo del precedente
                if myIdx > 0 && missions[myIdx-1].stationId == stop.stationId {
                    entry = missions[myIdx-1].arrival ?? missions[myIdx-1].departure ?? entry
                }
                // Se il mezzo riparte con un altro treno NELLA STESSA STAZIONE, l'occupazione finisce alla partenza del successivo
                if myIdx < missions.count - 1 && missions[myIdx+1].stationId == stop.stationId {
                    exit = missions[myIdx+1].departure ?? missions[myIdx+1].arrival ?? exit
                }
            }
        }
        return (entry, exit)
    }
    
    private func detectOverlaps(occupations: [ResourceOccupation], capacity: Int, resId: String, nodes: [Node]) -> [ScheduleConflict] {
        if occupations.count <= capacity { return [] }
        
        struct Event: Comparable {
            let time: Date
            let isEntry: Bool
            let trainId: UUID
            let vehicleId: UUID?
            let trainName: String
            
            static func < (lhs: Event, rhs: Event) -> Bool {
                if lhs.time != rhs.time { return lhs.time < rhs.time }
                return lhs.isEntry && !rhs.isEntry
            }
        }
        
        let events = occupations.flatMap { occ -> [Event] in
            [Event(time: occ.entry, isEntry: true, trainId: occ.trainId, vehicleId: occ.vehicleId, trainName: occ.trainName),
             Event(time: occ.effectiveExit(), isEntry: false, trainId: occ.trainId, vehicleId: occ.vehicleId, trainName: occ.trainName)]
        }.sorted()
        
        var activeOccupants: [UUID: (vehicleId: UUID?, name: String)] = [:]
        var conflicts: [ScheduleConflict] = []
        
        for event in events {
            if event.isEntry {
                activeOccupants[event.trainId] = (event.vehicleId, event.trainName)
                
                // Conta quanti "mezzi fisici" distinti ci sono
                // Se vId è nil, è considerato un mezzo unico. Se vId esiste, conta solo se diverso.
                var physicalOccupantsCount = 0
                var seenVehicles = Set<UUID>()
                for (_, data) in activeOccupants {
                    if let vId = data.vehicleId {
                        if !seenVehicles.contains(vId) {
                            physicalOccupantsCount += 1
                            seenVehicles.insert(vId)
                        }
                    } else {
                        physicalOccupantsCount += 1
                    }
                }
                
                if physicalOccupantsCount > capacity {
                    // Genera conflitti tra il nuovo arrivato e TUTTI gli altri che non sono lo stesso mezzo fisico
                    for (otherId, otherData) in activeOccupants where otherId != event.trainId {
                        // Cruciale: Se è lo stesso mezzo fisico, non è un conflitto!
                        if let vId = event.vehicleId, let oVId = otherData.vehicleId, vId == oVId {
                            continue 
                        }
                        
                        let occA = occupations.first(where: { $0.trainId == otherId })!
                        let startOverlap = max(occA.entry, event.time)
                        let endOverlap = min(occA.effectiveExit(), event.time.addingTimeInterval(300)) // 5 min min overlap display
                        
                        let locInfo = parseLocationInfo(resId: resId, nodes: nodes)
                        
                        conflicts.append(ScheduleConflict(
                            trainAId: otherId,
                            trainBId: event.trainId,
                            trainAName: otherData.name,
                            trainBName: event.trainName,
                            locationType: locInfo.type,
                            locationName: locInfo.name,
                            locationId: resId,
                            timeStart: startOverlap,
                            timeEnd: endOverlap,
                            capacity: capacity,
                            occupantsCount: physicalOccupantsCount
                        ))
                    }
                }
            } else {
                activeOccupants.removeValue(forKey: event.trainId)
            }
        }
        
        // Grouping to avoid duplicates
        return groupConflictsByIncident(conflicts)
    }
    
    private func parseLocationInfo(resId: String, nodes: [Node]) -> (name: String, type: ScheduleConflict.LocationType) {
        if resId.hasPrefix("TRACK::") {
            let parts = resId.components(separatedBy: "::")
            let sid = parts.count > 1 ? parts[1] : "?"
            let track = parts.count > 2 ? parts[2] : "1"
            let name = nodes.first(where: { $0.id == sid })?.name ?? sid
            return ("Binario \(track) a \(name)", .station)
        } else if resId.hasPrefix("STATION_GLOBAL::") {
            let sid = resId.components(separatedBy: "::").last ?? "?"
            let name = nodes.first(where: { $0.id == sid })?.name ?? sid
            return ("Stazione \(name) [TUTTI I BINARI OCCUPATI]", .station)
        } else if resId.hasPrefix("SEGMENT::") {
            let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
            let parts = content.components(separatedBy: "--")
            let names = parts.map { id in nodes.first(where: { $0.id == id })?.name ?? id }
            return ("Tratta \(names.joined(separator: "-"))", .line)
        }
        return (resId, .line)
    }
    
    private func groupConflictsByIncident(_ conflicts: [ScheduleConflict]) -> [ScheduleConflict] {
        var grouped: [ScheduleConflict] = []
        var seen = Set<String>()
        for c in conflicts {
            let bucket = Int(c.timeStart.timeIntervalSince1970 / 600) // 10 min window
            let incidentId = [c.trainAId.uuidString, c.trainBId.uuidString].sorted().joined() + "_\(c.locationId)_\(bucket)"
            if !seen.contains(incidentId) {
                grouped.append(c)
                seen.insert(incidentId)
            }
        }
        return grouped
    }

    func calculateSuggestion(for conflict: ScheduleConflict, network: NetworkModel, trains: [Train]) -> String {
        if conflict.locationId.contains("TRACK") || conflict.locationType == .station || conflict.locationType == .routing {
            let parts = conflict.locationId.components(separatedBy: "::")
            let sid = parts.count >= 2 ? parts[1] : conflict.locationId.replacingOccurrences(of: "STATION_GLOBAL::", with: "")
            guard let node = network.nodes.first(where: { $0.id == sid }), let trainA = trains.first(where: { $0.id == conflict.trainAId }) else {
                return "consider_track_reassignment".localized
            }
            let stopAIdx = trainA.stops.firstIndex(where: { $0.stationId == sid }) ?? 0
            let prevId = stopAIdx > 0 ? trainA.stops[stopAIdx - 1].stationId : nil
            let nextId = stopAIdx < trainA.stops.count - 1 ? trainA.stops[stopAIdx + 1].stationId : nil
            let candidates = node.getTracksByProvenance(from: prevId, nextStationId: nextId, forLine: trainA.lineId)
            let currentTrack = trainA.stops[stopAIdx].track ?? "1"
            for cand in candidates {
                if cand == currentTrack { continue }
                if isTrackFree(stationId: sid, track: cand, from: conflict.timeStart, to: conflict.timeEnd, trains: trains, excludingId: trainA.id) {
                    return String(format: "suggestion_move_to_track_fmt".localized, trainA.name, cand)
                }
            }
            return "consider_track_reassignment".localized
        }
        if conflict.locationId.contains("SEGMENT") {
            return "suggest_shift_fmt".localized
        }
        return "consider_time_shift".localized
    }
    
    private func isTrackFree(stationId: String, track: String, from: Date, to: Date, trains: [Train], excludingId: UUID) -> Bool {
        let buffer: TimeInterval = 120 // 2 min buffer
        for t in trains {
            if t.id == excludingId { continue }
            guard let stop = t.stops.first(where: { $0.stationId == stationId && ($0.track ?? "1") == track }) else { continue }
            guard let arr = stop.arrival, let dep = stop.departure else { continue }
            let overlapStart = max(from, arr)
            let overlapEnd = min(to, dep)
            if overlapStart < overlapEnd.addingTimeInterval(-buffer) {
                return false
            }
        }
        return true
    }
}
