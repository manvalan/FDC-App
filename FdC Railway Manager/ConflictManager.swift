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
    
    func detectConflicts(nodes: [Node], edges: [Edge], trains: [Train], pathCache: [String: [Edge]]? = nil) {
        let nodesCopy = nodes
        let edgesCopy = edges
        let trainsCopy = trains
        var localCache = pathCache
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let (newConflicts, newCapacities) = self.calculateConflictsWithCapacities(
                nodes: nodesCopy,
                edges: edgesCopy,
                trains: trainsCopy,
                pathCache: &localCache
            )
            
            DispatchQueue.main.async {
                let sortedNew = Array(Set(newConflicts)).sorted(by: { $0.id < $1.id })
                if self.conflicts != sortedNew {
                    self.conflicts = sortedNew
                }
                self.lastResourceCapacities = newCapacities
            }
        }
    }

    func calculateConflicts(network: RailwayNetwork, trains: [Train]) -> [ScheduleConflict] {
        var dummyCache: [String: [Edge]]? = nil
        return calculateConflictsWithCapacities(nodes: network.nodes, edges: network.edges, trains: trains, pathCache: &dummyCache).0
    }

    func calculateConflicts(network: RailwayNetwork, trains: [Train], pathCache: inout [String: [Edge]]?) -> [ScheduleConflict] {
        return calculateConflictsWithCapacities(nodes: network.nodes, edges: network.edges, trains: trains, pathCache: &pathCache).0
    }

    func calculateConflictsWithCapacities(nodes: [Node], edges: [Edge], trains: [Train], pathCache: inout [String: [Edge]]?) -> ([ScheduleConflict], [String: Int]) {
        var newConflicts: [ScheduleConflict] = []
        
        struct ResourceEvent: Comparable {
            let time: Date
            let isEntry: Bool
            let trainId: UUID
            let trainName: String
            
            static func < (lhs: ResourceEvent, rhs: ResourceEvent) -> Bool {
                if lhs.time != rhs.time { return lhs.time < rhs.time }
                return lhs.isEntry && !rhs.isEntry
            }
        }
        
        struct Occupation {
            let trainId: UUID
            let trainName: String
            let entry: Date
            let exit: Date
            let resId: String
            
            func effectiveExit() -> Date {
                if resId.contains("TRACK") || resId.contains("STATION") {
                    return exit.addingTimeInterval(5)
                }
                return exit.addingTimeInterval(30)
            }
        }
        
        var resourceOccupations: [String: [Occupation]] = [:]
        var resourceCapacities = getResourceCapacities(nodes: nodes, edges: edges)

        // Pre-raggruppamento treni per mezzo per gestire la sosta al capolinea
        let vehicleGroups = Dictionary(grouping: trains.filter { $0.vehicleId != nil }, by: { $0.vehicleId! })
        var vehicleMissions: [UUID: [(trainId: UUID, stationId: String, arrival: Date?, departure: Date?, track: String?)]] = [:]
        
        for (vId, vTrains) in vehicleGroups {
            let missions = vTrains.flatMap { t in
                t.stops.map { s in (trainId: t.id, stationId: s.stationId, arrival: s.arrival, departure: s.departure, track: s.track) }
            }.sorted { 
                ($0.arrival ?? $0.departure ?? Date.distantPast) < ($1.arrival ?? $1.departure ?? Date.distantPast)
            }
            vehicleMissions[vId] = missions
        }

        for train in trains {
            var prevId: String? = nil
            for (stopIdx, stop) in train.stops.enumerated() {
                if stop.isSkipped { continue }
                
                let track = stop.track ?? "1"
                let trackResId = "TRACK::\(stop.stationId)::\(track)"
                let stationGlobalResId = "STATION_GLOBAL::\(stop.stationId)"

                if let arrival = stop.arrival, let departure = stop.departure {
                    let occ = Occupation(trainId: train.id, trainName: train.name, entry: arrival.normalized(), exit: departure.normalized(), resId: trackResId)
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[stationGlobalResId, default: []].append(occ)
                    resourceCapacities[trackResId] = 1
                } 
                else if let departure = stop.departure, stop.arrival == nil {
                    // ORIGINE: Controlla se il mezzo arriva da un altro treno
                    var entry = departure.addingTimeInterval(-30)
                    if let vId = train.vehicleId, let missions = vehicleMissions[vId] {
                        if let myIdx = missions.firstIndex(where: { $0.trainId == train.id && $0.departure == departure }) {
                            if myIdx > 0 && missions[myIdx-1].stationId == stop.stationId {
                                entry = missions[myIdx-1].arrival ?? entry
                            }
                        }
                    }
                    
                    let occ = Occupation(trainId: train.id, trainName: train.name, entry: entry.normalized(), exit: departure.normalized(), resId: trackResId)
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[stationGlobalResId, default: []].append(occ)
                    resourceCapacities[trackResId] = 1
                } else if let arrival = stop.arrival, stop.departure == nil {
                    // CAPOLINEA: Controlla se il mezzo riparte con un altro treno
                    var exit = arrival.addingTimeInterval(30)
                    if let vId = train.vehicleId, let missions = vehicleMissions[vId] {
                        if let myIdx = missions.firstIndex(where: { $0.trainId == train.id && $0.arrival == arrival }) {
                            if myIdx < missions.count - 1 && missions[myIdx+1].stationId == stop.stationId {
                                exit = missions[myIdx+1].departure ?? exit
                            }
                        }
                    }
                    
                    let occ = Occupation(trainId: train.id, trainName: train.name, entry: arrival.normalized(), exit: exit.normalized(), resId: trackResId)
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[stationGlobalResId, default: []].append(occ)
                    resourceCapacities[trackResId] = 1
                }
                
                if let pId = prevId, let arrival = stop.arrival, let arrivalPrev = train.stops.first(where: { $0.stationId == pId })?.departure {
                    let pathKey = "\(pId)--\(stop.stationId)"
                    let path = pathCache?[pathKey] ?? NetworkModel.findPathEdges(from: pId, to: stop.stationId, edges: edges)
                    
                    if let actualPath = path {
                        pathCache?[pathKey] = actualPath
                        let totalDist = actualPath.reduce(0.0) { $0 + $1.distance }
                        let totalTime = arrival.timeIntervalSince(arrivalPrev)
                        let avgSpeed = totalDist > 0 ? (totalDist / (totalTime / 3600.0)) : 0.0
                        
                        var currentTime = arrivalPrev
                        for edge in actualPath {
                            let transitTime = avgSpeed > 0 ? (edge.distance / avgSpeed * 3600.0) : 0.0
                            let exitTime = currentTime.addingTimeInterval(transitTime)
                            let s1Id = edge.from < edge.to ? edge.from : edge.to
                            let s2Id = edge.from < edge.to ? edge.to : edge.from
                            let resId = "SEGMENT::\(s1Id)--\(s2Id)"
                            
                            let occ = Occupation(trainId: train.id, trainName: train.name, entry: currentTime.normalized(), exit: exitTime.normalized(), resId: resId)
                            resourceOccupations[resId, default: []].append(occ)
                            currentTime = exitTime
                        }
                    }
                }
                
                prevId = stop.stationId
                
                if let node = nodes.first(where: { $0.id == stop.stationId }) {
                    let nextStopStationId: String? = {
                        if let idx = train.stops.firstIndex(where: { $0.id == stop.id }), idx < train.stops.count - 1 {
                            return train.stops[idx + 1].stationId
                        }
                        return nil
                    }()
                    let prevStopStationId: String? = {
                        if let idx = train.stops.firstIndex(where: { $0.id == stop.id }), idx > 0 {
                            return train.stops[idx - 1].stationId
                        }
                        return nil
                    }()
                    
                    if !node.isTrackAllowed(track: stop.track, lineId: train.lineId ?? "", prevStationId: prevStopStationId, nextStationId: nextStopStationId) {
                        let start = stop.arrival ?? stop.departure ?? Date()
                        let end = stop.departure ?? stop.arrival?.addingTimeInterval(30) ?? Date()
                        
                        newConflicts.append(ScheduleConflict(
                            trainAId: train.id,
                            trainBId: train.id,
                            trainAName: train.name,
                            trainBName: train.name,
                            locationType: .routing,
                            locationName: node.name,
                            locationId: "ROUTING::\(node.id)::\(train.id)",
                            timeStart: start,
                            timeEnd: end,
                            capacity: 0,
                            occupantsCount: 1
                        ))
                    }
                }
            }
        }
        
        for (resId, occupations) in resourceOccupations {
            let capacity = resourceCapacities[resId] ?? 1
            if occupations.count <= capacity { continue }
            
            var events: [ResourceEvent] = []
            for occ in occupations {
                events.append(ResourceEvent(time: occ.entry, isEntry: true, trainId: occ.trainId, trainName: occ.trainName))
                events.append(ResourceEvent(time: occ.effectiveExit(), isEntry: false, trainId: occ.trainId, trainName: occ.trainName))
            }
            events.sort()
            
            var activeOccupants: Set<UUID> = []
            var activeNames: [UUID: String] = [:]
            
            for event in events {
                if event.isEntry {
                    activeOccupants.insert(event.trainId)
                    activeNames[event.trainId] = event.trainName
                    
                    if activeOccupants.count > capacity {
                        let others = activeOccupants.filter { $0 != event.trainId }
                        for otherId in others {
                            let otherName = activeNames[otherId] ?? "Train"
                            let otherOcc = occupations.first(where: { $0.trainId == otherId && $0.entry <= event.time && $0.effectiveExit() > event.time })
                            guard let occA = otherOcc else { continue }
                            
                            let startOverlap = max(occA.entry, event.time)
                            let endOverlap = occA.effectiveExit()
                            
                            var locName = ""
                            var locType: ScheduleConflict.LocationType = .line
                            
                            if resId.hasPrefix("STATION") {
                                 locType = .station
                                 let parts = resId.components(separatedBy: "::")
                                 let sid = parts.count > 1 ? parts[1] : "?"
                                 let name = nodes.first(where: { $0.id == sid })?.name ?? sid
                                if resId.contains("TRACK") {
                                    let track = parts.count > 2 ? parts[2] : "1"
                                    locName = "Stazione \(name) [SOVRAPPOSIZIONE BINARIO \(track)]"
                                } else {
                                    locName = "Stazione \(name) [TUTTI I BINARI OCCUPATI]"
                                }
                            } else if resId.hasPrefix("SEGMENT::") {
                                 locType = .line
                                 let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
                                 let parts = content.components(separatedBy: "--")
                                 let names = parts.map { id in nodes.first(where: { $0.id == id })?.name ?? id }
                                 locName = "Tratta \(names.joined(separator: "-")) [LINEA SATURA]"
                            } else if resId.hasPrefix("TRACK::") {
                                 locType = .station
                                 let parts = resId.components(separatedBy: "::")
                                 let sid = parts.count > 1 ? parts[1] : "?"
                                 let track = parts.count > 2 ? parts[2] : "1"
                                 let name = nodes.first(where: { $0.id == sid })?.name ?? sid
                                locName = "Binario \(track) a \(name) [OCCUPAZIONE DOPPIA]"
                            } else {
                                locName = "Risorsa \(resId)"
                            }
                            
                            newConflicts.append(ScheduleConflict(
                                trainAId: otherId,
                                trainBId: event.trainId,
                                trainAName: otherName,
                                trainBName: event.trainName,
                                locationType: locType,
                                locationName: locName,
                                locationId: resId,
                                timeStart: startOverlap,
                                timeEnd: endOverlap,
                                capacity: capacity,
                                occupantsCount: activeOccupants.count
                            ))
                        }
                    }
                } else {
                    activeOccupants.remove(event.trainId)
                }
            }
        }
        
        var grouped: [ScheduleConflict] = []
        var seenIncidents = Set<String>() 
        for c in newConflicts {
            let timeBucket = Int(c.timeStart.timeIntervalSince1970 / 1800)
            // PIGNOLO: Include locationId to avoid hiding different conflicts for same trains in same window
            let incidentId = [c.trainAId.uuidString, c.trainBId.uuidString].sorted().joined() + "_\(c.locationId)_\(timeBucket)"
            
            if c.locationType == .station || c.locationType == .routing {
                grouped.append(c)
            } else if !seenIncidents.contains(incidentId) {
                grouped.append(c)
                seenIncidents.insert(incidentId)
            }
        }
        return (grouped, resourceCapacities)
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
            let candidates = node.getTracksByProvenance(from: prevId, forLine: trainA.lineId)
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
        let buffer: TimeInterval = 30
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
