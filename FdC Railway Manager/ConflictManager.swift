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
            let dateAt2000 = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour, minute: components.minute, second: components.second)) ?? date
            
            // PIGNOLO PROTOCOL: MUST round to nearest minute for absolute sync with manager & AI
            let roundedSeconds = floor((dateAt2000.timeIntervalSinceReferenceDate + 30) / 60) * 60
            return Date(timeIntervalSinceReferenceDate: roundedSeconds)
        }
        
        // 1. Generate all occupations using PRE-CALCULATED times from Train objects
        for train in trains {
            guard !train.stops.isEmpty else { continue }
            
            var prevId: String? = nil
            
            for stop in train.stops {
                // Station Occupation window (NORMALIZED and ROUNDED)
                if let arrival = stop.arrival, let departure = stop.departure {
                    let resId = "STATION::" + stop.stationId
                    resourceOccupations[resId, default: []].append(Occupation(
                        trainId: train.id, 
                        trainName: train.name, 
                        entry: normalizeToRefDate(arrival), 
                        exit: normalizeToRefDate(departure))
                    )
                    
                    if let node = network.nodes.first(where: { $0.id == stop.stationId }) {
                        let cap = node.platforms ?? (node.type == .interchange ? 2 : 1)
                        resourceCapacities[resId] = cap
                    }
                } else if let departure = stop.departure, stop.arrival == nil {
                    // Origin Station: define a preparation window (e.g., 3 mins before departure)
                    let entry = departure.addingTimeInterval(-180) 
                    let resId = "STATION::" + stop.stationId
                    resourceOccupations[resId, default: []].append(Occupation(
                        trainId: train.id, 
                        trainName: train.name, 
                        entry: normalizeToRefDate(entry), 
                        exit: normalizeToRefDate(departure))
                    )
                    resourceCapacities[resId] = network.nodes.first(where: { $0.id == stop.stationId })?.platforms ?? 1
                } else if let arrival = stop.arrival, stop.departure == nil {
                    // Destination Station: define a clear-out window (e.g., 3 mins after arrival)
                    let exit = arrival.addingTimeInterval(180)
                    let resId = "STATION::" + stop.stationId
                    resourceOccupations[resId, default: []].append(Occupation(
                        trainId: train.id, 
                        trainName: train.name, 
                        entry: normalizeToRefDate(arrival), 
                        exit: normalizeToRefDate(exit))
                    )
                    resourceCapacities[resId] = network.nodes.first(where: { $0.id == stop.stationId })?.platforms ?? 1
                }
                
                // Line Segment Occupation (between this and previous station)
                if let pId = prevId, let arrival = stop.arrival {
                    // A train occupies the segment from when it departs the previous station until it arrives here
                    if let prevStop = train.stops.first(where: { $0.stationId == pId }), let departure = prevStop.departure {
                        let resId = "LINE::" + [pId, stop.stationId].sorted().joined(separator: "-")
                        resourceOccupations[resId, default: []].append(Occupation(
                            trainId: train.id, 
                            trainName: train.name, 
                            entry: normalizeToRefDate(departure), 
                            exit: normalizeToRefDate(arrival))
                        )
                        
                        // Capacity check for segment
                        if let path = network.findPathEdges(from: pId, to: stop.stationId) {
                            let minCap = path.map { ($0.trackType == .single || $0.trackType == .regional) ? 1 : ($0.capacity ?? 2) }.min() ?? 1
                            resourceCapacities[resId] = minCap
                        } else {
                            resourceCapacities[resId] = 1
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

