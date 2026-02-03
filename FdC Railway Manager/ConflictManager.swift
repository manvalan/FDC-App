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
    }
    
    let locationType: LocationType
    let locationName: String 
    let locationId: String 
    
    let timeStart: Date
    let timeEnd: Date
    
    var id: String {
        "\(trainAId.uuidString)_\(trainBId.uuidString)_\(locationId)_\(Int(timeStart.timeIntervalSince1970))"
    }
    
    var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let start = formatter.string(from: timeStart)
        let end = formatter.string(from: timeEnd)
        return "Binario/Tratta occupata contemporaneamente da \(trainAName) e \(trainBName) presso \(locationName) [\(start) - \(end)]"
    }
}

// MARK: - Conflict Manager

class ConflictManager: ObservableObject {
    @Published var conflicts: [ScheduleConflict] = []
    @Published var lastResourceCapacities: [String: Int] = [:]
    
    func detectConflicts(network: RailwayNetwork, trains: [Train]) {
        let (newConflicts, newCapacities) = calculateConflictsWithCapacities(network: network, trains: trains)
        DispatchQueue.main.async {
            self.conflicts = Array(Set(newConflicts))
            self.lastResourceCapacities = newCapacities
        }
    }

    func calculateConflicts(network: RailwayNetwork, trains: [Train]) -> [ScheduleConflict] {
        var dummyCache: [String: [Edge]]? = nil
        return calculateConflictsWithCapacities(network: network, trains: trains, pathCache: &dummyCache).0
    }

    func calculateConflicts(network: RailwayNetwork, trains: [Train], pathCache: inout [String: [Edge]]?) -> [ScheduleConflict] {
        return calculateConflictsWithCapacities(network: network, trains: trains, pathCache: &pathCache).0
    }

    func calculateConflictsWithCapacities(network: RailwayNetwork, trains: [Train]) -> ([ScheduleConflict], [String: Int]) {
        var dummyCache: [String: [Edge]]? = nil
        return calculateConflictsWithCapacities(network: network, trains: trains, pathCache: &dummyCache)
    }

    func calculateConflictsWithCapacities(network: RailwayNetwork, trains: [Train], pathCache: inout [String: [Edge]]?) -> ([ScheduleConflict], [String: Int]) {
        var newConflicts: [ScheduleConflict] = []
        // Swift.print("Starting capacity-aware conflict detection for \(trains.count) trains...")
        
        struct ResourceEvent: Comparable {
            let time: Date
            let isEntry: Bool
            let trainId: UUID
            let trainName: String
            
            static func < (lhs: ResourceEvent, rhs: ResourceEvent) -> Bool {
                if lhs.time != rhs.time { return lhs.time < rhs.time }
                return lhs.isEntry && !rhs.isEntry // Entry before exit on same time to be conservative
            }
        }
        
        struct Occupation {
            let trainId: UUID
            let trainName: String
            let entry: Date
            let exit: Date
            
            // For safety buffer: 60 seconds interval requirement
            var effectiveExit: Date {
                exit.addingTimeInterval(30) // PIGNOLO PROTOCOL: 30s buffer for stabilization
            }
        }
        
        var resourceOccupations: [String: [Occupation]] = [:]
        var resourceCapacities: [String: Int] = [:]
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        func normalizeToRefDate(_ date: Date) -> Date {
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let dateAt2000 = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour, minute: components.minute, second: components.second)) ?? date
            
            // PIGNOLO PROTOCOL: Synchronize with AI Service precision (1 second)
            // This prevents aliasing where AI resolves at 1s but local rounds to 5s.
            let roundedSeconds = floor(dateAt2000.timeIntervalSinceReferenceDate + 0.5)
            return Date(timeIntervalSinceReferenceDate: roundedSeconds)
        }
        
        // 1. Pre-calculate Resource Capacities
        // Stations have node.platforms, tracks have 1 (single) or 2 (double)
        for node in network.nodes {
            resourceCapacities["STATION::\(node.id)"] = node.platforms ?? 2
            resourceCapacities["STATION::\(node.id)::GLOBAL"] = node.platforms ?? 2
        }
        
        // Groups edges by station pairs to determine physical track capacity
        var segmentEdges: [String: [Edge]] = [:]
        for edge in network.edges {
            let s1Id = edge.from < edge.to ? edge.from : edge.to
            let s2Id = edge.from < edge.to ? edge.to : edge.from
            let key = "\(s1Id)--\(s2Id)"
            segmentEdges[key, default: []].append(edge)
        }
        
        for (key, edges) in segmentEdges {
            let resId = "SEGMENT::\(key)"
            guard let firstEdge = edges.first else { continue }
            
            // PIGNOLO PROTOCOL: Unified capacity calculation (Sync with RailwayGraphManager)
            // 1. One bidirectional pair (A->B, B->A) = 1 track by default.
            // 2. If it's a Double Track type, it's at least 2.
            let isDual = firstEdge.trackType == .double || firstEdge.trackType == .highSpeed
            var cap = isDual ? 2 : 1
            
            // 3. Parallel tracks: If we have more than 2 edges, it implies multiple physical tracks
            if edges.count > 2 {
                cap = max(cap, edges.count / 2)
            }
            
            // 4. Manual override has highest priority
            if let explicitCap = firstEdge.capacity, explicitCap > 0 {
                cap = explicitCap
            }
            
            resourceCapacities[resId] = cap
        }
        
        // 2. Generate all occupations using PRE-CALCULATED times from Train objects
        for train in trains {
            guard !train.stops.isEmpty else { continue }
            
            var prevId: String? = nil
            
            for stop in train.stops {
                // 1. Specific Track Occupation (Capacity 1)
                let track = stop.track ?? "1"
                let trackResId = "STATION::\(stop.stationId)::TRACK::\(track)"
                
                // 2. Global Station Occupation (Capacity = node.platforms)
                let stationGlobalResId = "STATION::\(stop.stationId)::GLOBAL"

                // Station Occupation window (NORMALIZED and ROUNDED)
                if let arrival = stop.arrival, let departure = stop.departure {
                    let occ = Occupation(
                        trainId: train.id, 
                        trainName: train.name, 
                        entry: normalizeToRefDate(arrival), 
                        exit: normalizeToRefDate(departure))
                    
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[stationGlobalResId, default: []].append(occ)
                    resourceCapacities[trackResId] = 1
                } else if let departure = stop.departure, stop.arrival == nil {
                    let entry = departure.addingTimeInterval(-30) 
                    let occ = Occupation(
                        trainId: train.id, 
                        trainName: train.name, 
                        entry: normalizeToRefDate(entry), 
                        exit: normalizeToRefDate(departure))
                    
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[stationGlobalResId, default: []].append(occ)
                    resourceCapacities[trackResId] = 1
                } else if let arrival = stop.arrival, stop.departure == nil {
                    let exit = arrival.addingTimeInterval(30)
                    let occ = Occupation(
                        trainId: train.id, 
                        trainName: train.name, 
                        entry: normalizeToRefDate(arrival), 
                        exit: normalizeToRefDate(exit))
                    
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[stationGlobalResId, default: []].append(occ)
                    resourceCapacities[trackResId] = 1
                }
                
                // Line Segment Occupation (Iterate through individual edges)
                if let pId = prevId, let arrival = stop.arrival, let arrivalPrev = train.stops.first(where: { $0.stationId == pId })?.departure {
                    let pathKey = "\(pId)--\(stop.stationId)"
                    let path = pathCache?[pathKey] ?? network.findPathEdges(from: pId, to: stop.stationId)
                    
                    if let actualPath = path {
                        pathCache?[pathKey] = actualPath
                        let totalDist = actualPath.reduce(0.0) { $0 + $1.distance }
                        let totalTime = arrival.timeIntervalSince(arrivalPrev)
                        let avgSpeed = totalDist > 0 ? (totalDist / (totalTime / 3600.0)) : 0.0
                        
                        var currentTime = arrivalPrev
                        for edge in actualPath {
                            let transitTime = avgSpeed > 0 ? (edge.distance / avgSpeed * 3600.0) : 0.0
                            let exitTime = currentTime.addingTimeInterval(transitTime)
                            
                            // Direction-agnostic resource ID for segments
                            let s1Id = edge.from < edge.to ? edge.from : edge.to
                            let s2Id = edge.from < edge.to ? edge.to : edge.from
                            let resId = "SEGMENT::\(s1Id)--\(s2Id)"
                            
                            let occ = Occupation(
                                trainId: train.id, 
                                trainName: train.name, 
                                entry: normalizeToRefDate(currentTime), 
                                exit: normalizeToRefDate(exitTime))
                            
                            resourceOccupations[resId, default: []].append(occ)
                            currentTime = exitTime
                        }
                    }
                }
                
                prevId = stop.stationId
            }
        }
        
        // 2. Check for capacity violations per resource
        for (resId, occupations) in resourceOccupations {
            let capacity = resourceCapacities[resId] ?? 1
            if occupations.count <= capacity { continue }
            
            var events: [ResourceEvent] = []
            for occ in occupations {
                events.append(ResourceEvent(time: occ.entry, isEntry: true, trainId: occ.trainId, trainName: occ.trainName))
                events.append(ResourceEvent(time: occ.effectiveExit, isEntry: false, trainId: occ.trainId, trainName: occ.trainName))
            }
            events.sort()
            
            var activeOccupants: Set<UUID> = []
            var activeNames: [UUID: String] = [:]
            
            for event in events {
                if event.isEntry {
                    activeOccupants.insert(event.trainId)
                    activeNames[event.trainId] = event.trainName
                    
                    if activeOccupants.count > capacity {
                        // Conflict found! Create reports between the new arrival and ALL current occupants
                        let others = activeOccupants.filter { $0 != event.trainId }
                        for otherId in others {
                            let otherName = activeNames[otherId] ?? "Train"
                            
                            // Find overlap window
                            let otherOcc = occupations.first(where: { $0.trainId == otherId && $0.entry <= event.time && $0.effectiveExit > event.time })
                            guard let occA = otherOcc else { continue }
                            
                            let startOverlap = max(occA.entry, event.time)
                            let endOverlap = occA.effectiveExit // Until the first one leaves (buffered)
                            
                            // Resolve Names for human-readable report
                            var locName = ""
                            if resId.hasPrefix("STATION") {
                                let parts = resId.components(separatedBy: "::")
                                let sid = parts.count > 1 ? parts[1] : "?"
                                let track = parts.count > 3 ? parts[3] : "1"
                                let name = network.nodes.first(where: { $0.id == sid })?.name ?? sid
                                locName = "Stazione \(name) (Bin. \(track))"
                            } else if resId.hasPrefix("SEGMENT::") {
                                let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
                                let parts = content.components(separatedBy: "--")
                                let names = parts.map { id in network.nodes.first(where: { $0.id == id })?.name ?? id }
                                locName = "Tratta \(names.joined(separator: " - "))"
                            } else {
                                locName = "Risorsa \(resId)"
                            }
                            
                            newConflicts.append(ScheduleConflict(
                                trainAId: otherId,
                                trainBId: event.trainId,
                                trainAName: otherName,
                                trainBName: event.trainName,
                                locationType: resId.hasPrefix("STATION") ? .station : .line,
                                locationName: locName,
                                locationId: resId,
                                timeStart: startOverlap,
                                timeEnd: endOverlap
                            ))
                        }
                    }
                } else {
                    activeOccupants.remove(event.trainId)
                }
            }
        }
        
        // 3. GROUP CONFLICTS: If two trains conflict on multiple contiguous line segments, 
        // count them as one "Logical Incident" to avoid overwhelming the user (28 -> ~5-8 real problems)
        var grouped: [ScheduleConflict] = []
        var seenIncidents = Set<String>() 
        
        for c in newConflicts {
            // Identifier for a pair of trains meeting in a specific time window
            // Round time to nearest 30 mins to group sequential segment conflicts
            let timeBucket = Int(c.timeStart.timeIntervalSince1970 / 1800)
            let incidentId = [c.trainAId.uuidString, c.trainBId.uuidString].sorted().joined() + "_\(timeBucket)"
            
            if c.locationType == .station {
                // Stations are always distinct critical points
                grouped.append(c)
            } else if !seenIncidents.contains(incidentId) {
                // For lines, we only report the FIRST segment where they clash in that window
                grouped.append(c)
                seenIncidents.insert(incidentId)
            }
        }
        
        return (grouped, resourceCapacities)
    }
}

