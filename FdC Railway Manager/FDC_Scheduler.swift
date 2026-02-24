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
    nonisolated static func calculateTravelTime(distanceKm: Double, 
                                   maxSpeedKmh: Double, 
                                   train: RailwayTrain,
                                   initialSpeedKmh: Double = 0, 
                                   finalSpeedKmh: Double = 0,
                                   gradient: Double = 0) -> Double {
        
        let physics = TrainPhysicsEngine.TrainPhysics(from: train)
        return TrainPhysicsEngine.calculateTravelTime(
            distance: distanceKm,
            trackMaxSpeed: maxSpeedKmh,
            physics: physics,
            initialSpeed: initialSpeedKmh,
            finalSpeed: finalSpeedKmh,
            gradient: gradient
        )
    }
    
    /// Centralized method to calculate realistic travel time for a sequence of edges
    /// Using arrays for nodes/edges to allow nonisolated access (avoids MainActor isolation)
    nonisolated static func calculatePathTravelTime(edges: [Edge], train: RailwayTrain, nodes: [RailwayNode], isStarting: Bool = false, isStopping: Bool = false, startNodeId: String, endNodeId: String) -> Double {
        guard !edges.isEmpty else { return 0 }
        
        let totalDistance = edges.reduce(0.0) { $0 + $1.distance }
        let minTrackSpeed = edges.map { Double($0.maxSpeed) }.min() ?? 100.0
        let effectiveMaxSpeed = min(minTrackSpeed, train.maxSpeed)
        
        var avgGradient: Double = 0
        if let fromNode = nodes.first(where: { $0.id == startNodeId }),
           let toNode = nodes.first(where: { $0.id == endNodeId }),
           let fromAlt = fromNode.altitude,
           let toAlt = toNode.altitude,
           totalDistance > 0 {
            avgGradient = ((toAlt - fromAlt) / (totalDistance * 1000.0)) * 100.0
        }
        
        return calculateTravelTime(
            distanceKm: totalDistance,
            maxSpeedKmh: effectiveMaxSpeed,
            train: train,
            initialSpeedKmh: isStarting ? 0 : effectiveMaxSpeed,
            finalSpeedKmh: isStopping ? 0 : effectiveMaxSpeed,
            gradient: avgGradient
        ) * 3600.0
    }

    /// Centralized method to calculate realistic travel time between two connected nodes
    nonisolated static func calculateTravelTimeBetweenNodes(from fromId: String, to toId: String, train: RailwayTrain, nodes: [RailwayNode], edges: [Edge], isStarting: Bool = false, isStopping: Bool = false) -> Double {
        guard let edge = edges.first(where: { ($0.from == fromId && $0.to == toId) || ($0.from == toId && $0.to == fromId) }) else { return 0 }
        return calculatePathTravelTime(edges: [edge], train: train, nodes: nodes, isStarting: isStarting, isStopping: isStopping, startNodeId: fromId, endNodeId: toId)
    }

    /// Build a full schedule for a train along a route
    static func buildSchedule(train: RailwayTrain, network: RailwayNetwork, route: [String], startTime: Date) -> TrainSchedule? {
        guard route.count >= 2 else { return nil }
        
        var stops: [ScheduleStop] = []
        var currentTime = startTime
        
        for (index, stationId) in route.enumerated() {
            let stationName = network.nodes.first(where: { $0.id == stationId })?.name ?? stationId
            
            if index == 0 {
                stops.append(ScheduleStop(stationId: stationId, arrivalTime: nil, departureTime: currentTime, platform: 1, dwellsMinutes: 0, stationName: stationName))
            } else {
                let prevStationId = route[index - 1]
                let isLast = index == route.count - 1
                
                let travelTimeSeconds = calculateTravelTimeBetweenNodes(
                    from: prevStationId, 
                    to: stationId, 
                    train: train, 
                    nodes: network.nodes,
                    edges: network.edges,
                    isStarting: index == 1, 
                    isStopping: isLast
                )
                
                let arrivalTime = currentTime.addingTimeInterval(travelTimeSeconds)
                let dwellMinutes = isLast ? 0 : 2
                let departureTime = isLast ? nil : arrivalTime.addingTimeInterval(Double(dwellMinutes) * 60.0)
                
                stops.append(ScheduleStop(stationId: stationId, arrivalTime: arrivalTime, departureTime: departureTime, platform: 1, dwellsMinutes: dwellMinutes, stationName: stationName))
                if let dt = departureTime { currentTime = dt }
            }
        }
        
        return TrainSchedule(trainId: train.id, trainName: train.name, stops: stops)
    }
    
    /// Find all operational conflicts in a set of schedules
    static func checkConflicts(schedules: [TrainSchedule], network: RailwayNetwork) -> [Conflict] {
        var conflicts: [Conflict] = []
        
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
                    let involvedNames = usages.filter { activeTrains.contains($0.2) }.map { $0.3 }
                    conflicts.append(Conflict(type: .stationOverlap, locationId: stationId, trainIds: Array(activeTrains), trainNames: involvedNames, startTime: lastTime, endTime: event.0))
                }
                if event.1 == 1 { activeTrains.insert(event.2) }
                else { activeTrains.remove(event.2) }
                lastTime = event.0
            }
        }
        
        var trackUsage: [String: [(Date, Date, UUID, String)]] = [:]
        for sch in schedules {
            guard sch.stops.count >= 2 else { continue }
            for i in 0..<(sch.stops.count - 1) {
                let s1 = sch.stops[i]
                let s2 = sch.stops[i+1]
                guard let dep = s1.departureTime, let arr = s2.arrivalTime else { continue }
                
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
                        conflicts.append(Conflict(type: .trackOverlap, locationId: edgeKey, trainIds: [u1.2, u2.2], trainNames: [u1.3, u2.3], startTime: max(u1.0, u2.0), endTime: min(u1.1, u2.1)))
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
    
    func resolveConflicts(trains: [RailwayTrain], network: RailwayNetwork) {
        activeConflicts = FDCSchedulerEngine.checkConflicts(schedules: schedules, network: network)
        
        var iterations = 0
        while !activeConflicts.isEmpty && iterations < 20 {
            iterations += 1
            guard let conflict = activeConflicts.first else { break }
            let involvedTrains = trains.filter { t in conflict.trainIds.contains(t.id) }
            let sortedByPriority = involvedTrains.sorted(by: { $0.priority < $1.priority })
            
            guard let lowPriorityTrain = sortedByPriority.first,
                  let scheduleToDelay = schedules.first(where: { $0.trainId == lowPriorityTrain.id }) else {
                activeConflicts.removeFirst()
                continue
            }
            
            if conflict.type == .stationOverlap {
                applyDelay(to: scheduleToDelay, minutes: 2, startingFrom: conflict.locationId)
            } else if conflict.type == .trackOverlap {
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
            if stationIds.contains(s1) && stationIds.contains(s2) { return s1 }
        }
        return nil
    }
    
    func applyDelay(to schedule: TrainSchedule, minutes: Int, startingFrom stationId: String) {
        schedule.totalDelayMinutes += minutes
        var foundStart = false
        for i in 0..<schedule.stops.count {
            if schedule.stops[i].stationId == stationId { foundStart = true }
            if foundStart {
                if let arrival = schedule.stops[i].arrivalTime { schedule.stops[i].arrivalTime = arrival.addingTimeInterval(Double(minutes) * 60.0) }
                if let departure = schedule.stops[i].departureTime { schedule.stops[i].departureTime = departure.addingTimeInterval(Double(minutes) * 60.0) }
            }
        }
        schedule.objectWillChange.send()
        self.objectWillChange.send()
    }
}
