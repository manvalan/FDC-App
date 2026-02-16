import Foundation
import Combine

// MARK: - Models

struct ScheduleStop: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let stationId: String
    var arrivalTime: Date?
    var departureTime: Date?
    var platform: Int?
    var dwellsMinutes: Int = 2
    var stationName: String = "" // For UI convenience

    init(stationId: String, arrivalTime: Date?, departureTime: Date?, platform: Int? = 1, dwellsMinutes: Int = 2, stationName: String = "") {
        self.id = UUID()
        self.stationId = stationId
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.platform = platform
        self.dwellsMinutes = dwellsMinutes
        self.stationName = stationName
    }
}

@MainActor
class TrainSchedule: Identifiable, ObservableObject {
    let id: UUID = UUID()
    var trainId: UUID
    var trainName: String
    @Published var stops: [ScheduleStop] = []
    var totalDelayMinutes: Int = 0
    
    init(trainId: UUID, trainName: String, stops: [ScheduleStop] = []) {
        self.trainId = trainId
        self.trainName = trainName
        self.stops = stops
    }
}

enum ConflictType: String, Codable {
    case stationOverlap = "Station Overlap"
    case trackOverlap = "Track Overlap"
}

struct Conflict: Identifiable, Hashable {
    let id = UUID()
    let type: ConflictType
    let locationId: String
    let trainIds: [UUID]
    let trainNames: [String]
    let startTime: Date
    let endTime: Date
}

// MARK: - Scheduler Engine

@MainActor
class FDCSchedulerEngine {
    
    /// Calculate travel time in hours between two points using physics (acceleration/deceleration)
    /// Uses centralized TrainPhysicsEngine for realistic calculations
    static func calculateTravelTime(distanceKm: Double, 
                                   maxSpeedKmh: Double, 
                                   train: Train,
                                   initialSpeedKmh: Double = 0, 
                                   finalSpeedKmh: Double = 0) -> Double {
        
        // Create physics model from train
        let physics = TrainPhysicsEngine.TrainPhysics(from: train)
        
        // Use centralized physics engine
        return TrainPhysicsEngine.calculateTravelTime(
            distance: distanceKm,
            trackMaxSpeed: maxSpeedKmh,
            physics: physics,
            initialSpeed: initialSpeedKmh,
            finalSpeed: finalSpeedKmh,
            gradient: 0  // TODO: Get gradient from track data
        )
    }
    
    /// Build a full schedule for a train along a route
    static func buildSchedule(train: Train, 
                             network: RailwayNetwork, 
                             route: [String], 
                             startTime: Date) -> TrainSchedule? {
        guard route.count >= 2 else { return nil }
        
        var stops: [ScheduleStop] = []
        var currentTime = startTime
        
        for (index, stationId) in route.enumerated() {
            let stationName = network.nodes.first(where: { $0.id == stationId })?.name ?? stationId
            
            if index == 0 {
                // First station: Departure only
                let stop = ScheduleStop(stationId: stationId, 
                                       arrivalTime: nil, 
                                       departureTime: currentTime, 
                                       platform: 1, 
                                       dwellsMinutes: 0,
                                       stationName: stationName)
                stops.append(stop)
            } else {
                let prevStationId = route[index - 1]
                
                // Find edge for distance and speed limit
                guard let edge = network.edges.first(where: { ($0.from == prevStationId && $0.to == stationId) || ($0.from == stationId && $0.to == prevStationId) }) else {
                    return nil // Broken route
                }
                
                let travelTimeHours = calculateTravelTime(distanceKm: edge.distance, 
                                                         maxSpeedKmh: Double(edge.maxSpeed), 
                                                         train: train)
                
                let travelTimeSeconds = travelTimeHours * 3600.0
                let arrivalTime = currentTime.addingTimeInterval(travelTimeSeconds)
                
                let isLast = index == route.count - 1
                let dwellMinutes = isLast ? 0 : 2
                let departureTime = isLast ? nil : arrivalTime.addingTimeInterval(Double(dwellMinutes) * 60.0)
                
                let stop = ScheduleStop(stationId: stationId, 
                                       arrivalTime: arrivalTime, 
                                       departureTime: departureTime, 
                                       platform: 1, 
                                       dwellsMinutes: dwellMinutes,
                                       stationName: stationName)
                stops.append(stop)
                
                if let dt = departureTime {
                    currentTime = dt
                }
            }
        }
        
        return TrainSchedule(trainId: train.id, trainName: train.name, stops: stops)
    }
    
    /// Find all operational conflicts in a set of schedules
    static func checkConflicts(schedules: [TrainSchedule], network: RailwayNetwork) -> [Conflict] {
        var conflicts: [Conflict] = []
        
        // 1. Station Platform Overlaps
        // Key: stationId -> [(startTime, endTime, trainId, trainName, platform)]
        var stationUsage: [String: [(Date, Date, UUID, String, Int)]] = [:]
        
        for sch in schedules {
            for stop in sch.stops {
                guard let arrival = stop.arrivalTime, let departure = stop.departureTime else { continue }
                stationUsage[stop.stationId, default: []].append((arrival, departure, sch.trainId, sch.trainName, stop.platform ?? 1))
            }
        }
        
        for (stationId, usages) in stationUsage {
            let node = network.nodes.first(where: { $0.id == stationId })
            let maxPlatforms = node?.platforms ?? 1
            
            // Sweep-line algorithm to find overlapping occupation
            var events: [(Date, Int, UUID, String)] = []
            for u in usages {
                events.append((u.0, 1, u.2, u.3))
                events.append((u.1, -1, u.2, u.3))
            }
            events.sort { $0.0 < $1.0 || ($0.0 == $1.0 && $0.1 < $1.1) }
            
            var activeTrains = Set<UUID>()
            var lastTime = events.first?.0 ?? Date()
            
            for event in events {
                if activeTrains.count > maxPlatforms && event.0 > lastTime {
                    // Conflict window
                    let involvedNames = usages.filter { activeTrains.contains($0.2) }.map { $0.3 }
                    conflicts.append(Conflict(type: .stationOverlap,
                                           locationId: stationId,
                                           trainIds: Array(activeTrains),
                                           trainNames: involvedNames,
                                           startTime: lastTime,
                                           endTime: event.0))
                }
                
                if event.1 == 1 { activeTrains.insert(event.2) }
                else { activeTrains.remove(event.2) }
                lastTime = event.0
            }
        }
        
        // 2. Track Overlaps (Single Track Sections)
        var trackUsage: [String: [(Date, Date, UUID, String)]] = [:]
        
        for sch in schedules {
            guard sch.stops.count >= 2 else { continue }
            for i in 0..<(sch.stops.count - 1) {
                let s1 = sch.stops[i]
                let s2 = sch.stops[i+1]
                guard let dep = s1.departureTime, let arr = s2.arrivalTime else { continue }
                
                // Check if the edge between s1 and s2 is a single track
                if let edge = network.edges.first(where: { ($0.from == s1.stationId && $0.to == s2.stationId) || ($0.from == s2.stationId && $0.to == s1.stationId) }),
                   edge.trackType == .single {
                    let edgeKey = [s1.stationId, s2.stationId].sorted().joined(separator: "-")
                    trackUsage[edgeKey, default: []].append((dep, arr, sch.trainId, sch.trainName))
                }
            }
        }
        
        for (edgeKey, usages) in trackUsage {
            let sorted = usages.sorted(by: { $0.0 < $1.0 })
            for i in 0..<sorted.count {
                for j in (i+1)..<sorted.count {
                    let u1 = sorted[i]
                    let u2 = sorted[j]
                    
                    if u1.0 < u2.1 && u2.0 < u1.1 {
                        conflicts.append(Conflict(type: .trackOverlap,
                                               locationId: edgeKey,
                                               trainIds: [u1.2, u2.2],
                                               trainNames: [u1.3, u2.3],
                                               startTime: max(u1.0, u2.0),
                                               endTime: min(u1.1, u2.1)))
                    }
                }
            }
        }
        
        return conflicts
    }
}

// MARK: - Advanced Simulator

@MainActor
class FDCSimulator: ObservableObject {
    @Published var schedules: [TrainSchedule] = []
    @Published var activeConflicts: [Conflict] = []
    
    /// Resolve conflicts by delaying lower priority trains first
    func resolveConflicts(trains: [Train], network: RailwayNetwork) {
        activeConflicts = FDCSchedulerEngine.checkConflicts(schedules: schedules, network: network)
        
        var iterations = 0
        while !activeConflicts.isEmpty && iterations < 20 {
            iterations += 1
            
            // Take the first conflict and resolve it
            guard let conflict = activeConflicts.first else { break }
            
            let involvedTrains = trains.filter { t in conflict.trainIds.contains(t.id) }
            let sortedByPriority = involvedTrains.sorted(by: { $0.priority < $1.priority })
            
            guard let lowPriorityTrain = sortedByPriority.first,
                  let scheduleToDelay = schedules.first(where: { $0.trainId == lowPriorityTrain.id }) else {
                activeConflicts.removeFirst()
                continue
            }
            
            if conflict.type == .stationOverlap {
                // Try platform re-assignment first (logic refinement needed)
                // For now, delay by 2 minutes
                applyDelay(to: scheduleToDelay, minutes: 2, startingFrom: conflict.locationId)
            } else if conflict.type == .trackOverlap {
                // For track overlaps, we must delay BEFORE entering the section
                let stationPriorToTrack = findStationBeforeTrack(schedule: scheduleToDelay, edgeKey: conflict.locationId)
                applyDelay(to: scheduleToDelay, minutes: 5, startingFrom: stationPriorToTrack ?? conflict.locationId)
            }
            
            activeConflicts = FDCSchedulerEngine.checkConflicts(schedules: schedules, network: network)
        }
    }
    
    private func findStationBeforeTrack(schedule: TrainSchedule, edgeKey: String) -> String? {
        let stationIds = edgeKey.components(separatedBy: "-")
        guard schedule.stops.count >= 2 else { return nil }
        for i in 0..<(schedule.stops.count - 1) {
            let s1 = schedule.stops[i].stationId
            let s2 = schedule.stops[i+1].stationId
            if stationIds.contains(s1) && stationIds.contains(s2) {
                return s1
            }
        }
        return nil
    }
    
    func applyDelay(to schedule: TrainSchedule, minutes: Int, startingFrom stationId: String) {
        schedule.totalDelayMinutes += minutes
        
        var foundStart = false
        for i in 0..<schedule.stops.count {
            if schedule.stops[i].stationId == stationId {
                foundStart = true
            }
            
            if foundStart {
                if let arrival = schedule.stops[i].arrivalTime {
                    schedule.stops[i].arrivalTime = arrival.addingTimeInterval(Double(minutes) * 60.0)
                }
                if let departure = schedule.stops[i].departureTime {
                    schedule.stops[i].departureTime = departure.addingTimeInterval(Double(minutes) * 60.0)
                }
            }
        }
        
        // Notify UI
        schedule.objectWillChange.send()
        self.objectWillChange.send()
    }
}
