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
        "Binario/Tratta occupata contemporaneamente da \(trainAName) e \(trainBName) presso \(locationName)"
    }
}

// MARK: - Conflict Manager

class ConflictManager: ObservableObject {
    @Published var conflicts: [ScheduleConflict] = []
    
    func detectConflicts(network: RailwayNetwork, trains: [Train]) {
        var newConflicts: [ScheduleConflict] = []
        Swift.print("Starting capacity-aware conflict detection for \(trains.count) trains...")
        
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
        }
        
        var resourceOccupations: [String: [Occupation]] = [:]
        var resourceCapacities: [String: Int] = [:]
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        func normalizeToRefDate(_ date: Date) -> Date {
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            return calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour, minute: components.minute, second: components.second)) ?? date
        }
        
        // 1. Generate all occupations
        for train in trains {
            guard let depTime = train.departureTime,
                  let relId = train.relationId,
                  let rel = network.relations.first(where: { $0.id == relId }) else { continue }
            
            var currentTime = normalizeToRefDate(depTime)
            var prevId = rel.originId
            
            for (index, stop) in train.stops.enumerated() {
                let isOrigin = (index == 0)
                
                // Track Leg (Macro-Resource matching AI)
                if !isOrigin {
                    if let path = network.findPathEdges(from: prevId, to: stop.stationId) {
                        let totalDuration = path.reduce(0.0) { acc, edge in
                            let speed = min(Double(train.maxSpeed), Double(edge.maxSpeed))
                            return acc + (edge.distance / speed) * 3600
                        }
                        
                        let entry = currentTime
                        let exit = currentTime.addingTimeInterval(totalDuration)
                        
                        // PHYSICAL RESOURCE ID: Matches AI station-to-station leg
                        let resId = "LINE::" + [prevId, stop.stationId].sorted().joined(separator: "-")
                        resourceOccupations[resId, default: []].append(Occupation(trainId: train.id, trainName: train.name, entry: entry, exit: exit))
                        
                        // Capacity: Minimum capacity along the path (bottleneck)
                        let minCap = path.map { ($0.trackType == .single || $0.trackType == .regional) ? 1 : ($0.capacity ?? 2) }.min() ?? 1
                        resourceCapacities[resId] = minCap
                        
                        currentTime = exit
                    }
                }
                
                // Station Platforms
                let dwell = stop.isSkipped ? 0 : (Double(stop.minDwellTime) + (stop.extraDwellTime))
                let preparationTime = 3.0 // PIGNOLO PROTOCOL: Hardcoded 3.0m base dwell
                
                // CRITICAL TIMING SYNC:
                // For the AI, 'scheduled_departure_time' is the moment the train leaves the station.
                // The train occupies the station BEFORE that moment for 3.0 minutes (Sosta Tecnica Base).
                
                var entry = currentTime
                var exit = currentTime.addingTimeInterval(max(0.5, dwell) * 60)
                
                if isOrigin {
                    // Train is at the platform BEFORE it starts moving
                    entry = currentTime.addingTimeInterval(-preparationTime * 60)
                    exit = currentTime
                }
                
                let resId = "STATION::" + stop.stationId
                resourceOccupations[resId, default: []].append(Occupation(trainId: train.id, trainName: train.name, entry: entry, exit: exit))
                
                if let node = network.nodes.first(where: { $0.id == stop.stationId }) {
                    // SYNC with AI Station capacity logic: 2 for interchange, 1 otherwise
                    let cap = node.platforms ?? (node.type == Node.NodeType.interchange ? 2 : 1)
                    resourceCapacities[resId] = cap
                } else {
                    resourceCapacities[resId] = 1
                }
                
                // For next leg, currentTime starts after dwelling at this station (unless origin)
                if !isOrigin { currentTime = exit }
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
                events.append(ResourceEvent(time: occ.exit, isEntry: false, trainId: occ.trainId, trainName: occ.trainName))
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
                            let otherOcc = occupations.first(where: { $0.trainId == otherId && $0.entry <= event.time && $0.exit > event.time })
                            guard let occA = otherOcc else { continue }
                            
                            let startOverlap = max(occA.entry, event.time)
                            let endOverlap = occA.exit // Until the first one leaves
                            
                            // Resolve Names for human-readable report
                            let parts = resId.replacingOccurrences(of: "LINE::", with: "").replacingOccurrences(of: "STATION::", with: "").components(separatedBy: "-")
                            let names = parts.map { id in network.nodes.first(where: { $0.id == id })?.name ?? id }
                            let locName = resId.hasPrefix("STATION") ? "Stazione \(names[0])" : "Tratta \(names.joined(separator: " - "))"
                            
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
        
        DispatchQueue.main.async {
            self.conflicts = Array(Set(newConflicts)) // De-duplicate if same overlap reported multiple times
        }
    }
}

