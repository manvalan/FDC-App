import Foundation
import SwiftUI
import Combine

extension RailwayAIService {
    // MARK: - WebSocket Monitoring
    
    
    func connectMonitoring() {
        let wsURLString = baseURL.absoluteString
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "/api/v1", with: "") + "/ws/monitoring"
        
        guard let url = URL(string: wsURLString) else { return }
        
        print("[WS] Connecting to: \(url)")
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        isWsConnected = true
        receiveWSMessage()
    }
    
    func disconnectMonitoring() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        isWsConnected = false
    }
    
    func receiveWSMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        do {
                            let wsMessage = try JSONDecoder().decode(WSMessage.self, from: data)
                            DispatchQueue.main.async {
                                self?.wsMessages.append(wsMessage)
                                // Keep only last 100 messages for performance
                                if (self?.wsMessages.count ?? 0) > 100 {
                                    self?.wsMessages.removeFirst()
                                }
                            }
                        } catch {
                            print("[WS] Error decoding: \(error)")
                        }
                    }
                default: break
                }
                self?.receiveWSMessage()
            case .failure(let error):
                print("[WS] Error: \(error)")
                self?.isWsConnected = false
            }
        }
    }
    
    func getMinutesFromMidnight(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    
    /// Helper to convert current app state to RailwayAIRequest
    func createRequest(nodes: [RailwayNode], edges: [RailwayEdge], trains: [RailwayTrain], fixedTrainIds: Set<UUID> = [], activeAgentIds: Set<UUID>? = nil, temporalObstacles: [TemporalObstacle]? = nil, conflicts: [ScheduleConflict]) -> RailwayAIRequest {
        let aiStations = mapAIStations(nodes: nodes)
        let uniqueTracks = mapAIUniqueTracks(edges: edges)
        
        let focusTrains = (activeAgentIds == nil) ? trains : trains.filter { activeAgentIds!.contains($0.id) }
        let bgTrains = (activeAgentIds == nil) ? [] : trains.filter { !activeAgentIds!.contains($0.id) }
        
        let mergedObstacles = processTemporalObstacles(focusTrains: focusTrains, bgTrains: bgTrains, edges: edges, initialObstacles: temporalObstacles ?? [])
        let aiTrains = mapAITrains(focusTrains: focusTrains, nodes: nodes, edges: edges, fixedTrainIds: fixedTrainIds, conflicts: conflicts)
        
        let activeNumericIds: [Int]? = activeAgentIds?.compactMap { trainMapping[$0] }
        
        let finalRequest = RailwayAIRequest(
            trains: aiTrains,
            tracks: uniqueTracks,
            stations: aiStations,
            max_iterations: 1000,
            ga_max_iterations: nil,
            ga_population_size: nil,
            active_agent_ids: activeNumericIds,
            temporal_obstacles: mergedObstacles,
            current_time_minutes: self.getMinutesFromMidnight(for: Date())
        )
        
        self.lastRequestJSON = (try? String(data: JSONEncoder().encode(finalRequest), encoding: .utf8)) ?? ""
        return finalRequest
    }

    func mapAIStations(nodes: [Node]) -> [RailwayAIStationInfo] {
        let sortedNodes = nodes.sorted(by: { $0.id < $1.id })
        return sortedNodes.enumerated().map { index, node in
            stationMapping[node.id] = index
            let platforms = node.platforms ?? (node.type == .interchange ? 4 : 2)
            return RailwayAIStationInfo(id: index, name: node.name, num_platforms: platforms)
        }
    }

    func mapAIUniqueTracks(edges: [Edge]) -> [RailwayAITrackInfo] {
        var uniqueTracks: [RailwayAITrackInfo] = []
        var segmentToTrackId: [String: Int] = [:] 
        
        for edge in edges {
            let s1 = stationMapping[edge.from] ?? 0
            let s2 = stationMapping[edge.to] ?? 0
            let key = [s1, s2].sorted().map{String($0)}.joined(separator: "-")
            
            if let trackId = segmentToTrackId[key] {
                trackMapping[edge.id.uuidString] = trackId
            } else {
                let trackId = uniqueTracks.count
                segmentToTrackId[key] = trackId
                trackMapping[edge.id.uuidString] = trackId
                uniqueTracks.append(createAITrackInfo(id: trackId, s1: s1, s2: s2, edge: edge))
            }
        }
        return uniqueTracks
    }

    func createAITrackInfo(id: Int, s1: Int, s2: Int, edge: Edge) -> RailwayAITrackInfo {
        let isSingle = edge.trackType == .single || edge.trackType == .regional
        return RailwayAITrackInfo(
            id: id,
            station_ids: [s1, s2],
            length_km: edge.distance,
            is_single_track: isSingle,
            capacity: isSingle ? 1 : 2,
            max_speed_kmh: edge.maxSpeed
        )
    }

    func processTemporalObstacles(focusTrains: [Train], bgTrains: [Train], edges: [Edge], initialObstacles: [TemporalObstacle]) -> [TemporalObstacle] {
        var rawObstacles = initialObstacles
        let focusTrackIds = identifyFocusTrackIds(focusTrains: focusTrains, edges: edges)
        
        for bgTrain in bgTrains {
            rawObstacles.append(contentsOf: createObstaclesForTrain(bgTrain, edges: edges, focusTrackIds: focusTrackIds))
        }
        
        return mergeObstacles(rawObstacles)
    }

    func identifyFocusTrackIds(focusTrains: [Train], edges: [Edge]) -> Set<Int> {
        var ids = Set<Int>()
        for ft in focusTrains {
            guard ft.stops.count >= 2 else { continue }
            for i in 0..<(ft.stops.count - 1) {
                let s1 = ft.stops[i].stationId
                let s2 = ft.stops[i+1].stationId
                if let edge = edges.first(where: { ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1) }),
                   let tId = trackMapping[edge.id.uuidString] {
                    ids.insert(tId)
                }
            }
        }
        return ids
    }

    func createObstaclesForTrain(_ train: Train, edges: [Edge], focusTrackIds: Set<Int>) -> [TemporalObstacle] {
        var obstacles: [TemporalObstacle] = []
        guard train.stops.count >= 2 else { return [] }
        
        for i in 0..<(train.stops.count - 1) {
            let s1 = train.stops[i].stationId
            let s2 = train.stops[i+1].stationId
            guard let dep = train.stops[i].departure, let arr = train.stops[i+1].arrival else { continue }
            
            if let edge = edges.first(where: { ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1) }),
               let tId = trackMapping[edge.id.uuidString], focusTrackIds.contains(tId) {
                obstacles.append(contentsOf: buildObstacle(trackId: tId, dep: dep, arr: arr, trainName: train.name))
            }
        }
        return obstacles
    }

    func buildObstacle(trackId: Int, dep: Date, arr: Date, trainName: String) -> [TemporalObstacle] {
        let startMin = getMinutesFromMidnight(for: dep)
        let endMin = getMinutesFromMidnight(for: arr)
        if startMin <= endMin {
            return [TemporalObstacle(track_id: trackId, start_minute: startMin, end_minute: endMin, reason: "Traffico: \(trainName)")]
        } else {
            return [
                TemporalObstacle(track_id: trackId, start_minute: startMin, end_minute: 1440, reason: "Traffico: \(trainName) (Pre-Midnight)"),
                TemporalObstacle(track_id: trackId, start_minute: 0, end_minute: endMin, reason: "Traffico: \(trainName) (Post-Midnight)")
            ]
        }
    }

    func mapAITrains(focusTrains: [Train], nodes: [Node], edges: [Edge], fixedTrainIds: Set<UUID>, conflicts: [ScheduleConflict]) -> [RailwayAITrainInfo] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return focusTrains.enumerated().map { index, train in
            trainMapping[train.id] = index
            return createAITrainInfo(index: index, train: train, nodes: nodes, edges: edges, fixedTrainIds: fixedTrainIds, conflicts: conflicts, formatter: timeFormatter)
        }
    }

    func createAITrainInfo(index: Int, train: Train, nodes: [Node], edges: [Edge], fixedTrainIds: Set<UUID>, conflicts: [ScheduleConflict], formatter: DateFormatter) -> RailwayAITrainInfo {
        let routeIds = calculateRouteIds(for: train, edges: edges)
        let depTime = normalizeDate(train.departureTime)
        let actualVelocity = calculateVelocity(for: train, nodes: nodes, edges: edges)
        
        let isFixed = fixedTrainIds.contains(train.id)
        let isDelayed = isFixed ? false : conflicts.contains(where: { $0.trainAId == train.id || $0.trainBId == train.id })
        let avgDwell = train.stops.isEmpty ? 2 : Double(train.stops.reduce(0) { $0 + $1.minDwellTime }) / Double(train.stops.count)
        
        return RailwayAITrainInfo(
            id: index,
            priority: train.priority,
            position_km: 0.0,
            velocity_kmh: actualVelocity,
            current_track: routeIds.first ?? 0,
            destination_station: stationMapping[train.stops.last?.stationId ?? ""] ?? 0,
            delay_minutes: 0,
            is_delayed: isDelayed,
            origin_station: stationMapping[train.stops.first?.stationId ?? ""] ?? 0,
            scheduled_departure_time: formatter.string(from: depTime),
            planned_route: routeIds,
            min_dwell_minutes: Int(round(avgDwell))
        )
    }

    func calculateRouteIds(for train: Train, edges: [Edge]) -> [Int] {
        var routeIds: [Int] = []
        guard train.stops.count >= 2 else { return [] }
        for i in 0..<(train.stops.count - 1) {
            let s1 = train.stops[i].stationId
            let s2 = train.stops[i+1].stationId
            if let edge = edges.first(where: { ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1) }),
               let tId = trackMapping[edge.id.uuidString] {
                routeIds.append(tId)
            }
        }
        return routeIds
    }

    func calculateVelocity(for train: Train, nodes: [Node], edges: [Edge]) -> Double {
        guard let firstDep = train.stops.first?.departure, let lastArr = train.stops.last?.arrival else {
            return Double(train.maxSpeed) * 0.9
        }
        
        let totalTripSeconds = lastArr.timeIntervalSince(firstDep)
        let totalDwellSeconds = train.stops.reduce(0.0) { $0 + Double($1.minDwellTime * 60) }
        let movingSeconds = totalTripSeconds - totalDwellSeconds
        
        var totalDist = 0.0
        if train.stops.count >= 2 {
            for i in 0..<(train.stops.count - 1) {
                if let path = NetworkModel.findPathEdges(from: train.stops[i].stationId, to: train.stops[i+1].stationId, nodes: nodes, edges: edges) {
                    totalDist += path.reduce(0.0) { $0 + $1.distance }
                }
            }
        }
        
        if movingSeconds > 30 && totalDist > 0 {
            return min(totalDist / (movingSeconds / 3600.0), Double(train.maxSpeed))
        }
        return Double(train.maxSpeed) * 0.9
    }

    func normalizeDate(_ date: Date?) -> Date {
        let calendar = Calendar.current
        let d = date ?? Date()
        let components = calendar.dateComponents([.hour, .minute, .second], from: d)
        let dateAt2000 = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour, minute: components.minute, second: components.second)) ?? d
        return Date(timeIntervalSinceReferenceDate: floor(dateAt2000.timeIntervalSinceReferenceDate + 0.5))
    }
    
    func saveRequestToFile(_ request: RailwayAIRequest) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(formatter)
            
            let data = try encoder.encode(request)
            let path = "/Users/michelebigi/Documents/Develop/XCode/FdC/FdC Railway Manager/last_ai_request.json"
            try data.write(to: URL(fileURLWithPath: path))
            print("[PIGNOLO] Request salvata in: \(path)")
        } catch {
            print("[PIGNOLO] Errore salvataggio file: \(error)")
        }
    }
    
    /// Translates integer results back to original UUIDs
    func getTrainUUID(optimizerId: Int) -> UUID? {
        return trainMapping.first(where: { $0.value == optimizerId })?.key
    }
    
    func mergeObstacles(_ obstacles: [TemporalObstacle]) -> [TemporalObstacle] {
        var byTrack: [Int: [TemporalObstacle]] = [:]
        for o in obstacles { byTrack[o.track_id, default: []].append(o) }
        
        var result: [TemporalObstacle] = []
        for (trackId, group) in byTrack {
            let sorted = group.sorted { $0.start_minute < $1.start_minute }
            if sorted.isEmpty { continue }
            
            var current = sorted[0]
            for i in 1..<sorted.count {
                let next = sorted[i]
                if next.start_minute <= current.end_minute {
                    current = TemporalObstacle(
                        track_id: trackId,
                        start_minute: current.start_minute,
                        end_minute: max(current.end_minute, next.end_minute),
                        reason: "Merged Traffic"
                    )
                } else {
                    result.append(current)
                    current = next
                }
            }
            result.append(current)
        }
        return result
    }
    
    func getTrainMapping() -> [UUID: Int] {
        return trainMapping
    }
}
