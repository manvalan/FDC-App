import Foundation
import SwiftUI
import Combine

extension RailwayScheduleOptimizer {
    // MARK: - Local Schedule Helpers (Replacing TrainManager)
    
    func refreshMultipleSchedules(_ trains: inout [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil) {
        for i in trains.indices {
            refreshSingleTrainSchedule(&trains[i], nodes: nodes, edges: edges, pathCache: &pathCache, preferredHubId: preferredHubId)
        }
    }
    
    func refreshSingleTrainSchedule(_ train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil) {
        if let (hIdx, hNode) = findHubNode(in: train, nodes: nodes, preferredId: preferredHubId) {
            refreshTaktSchedule(train: &train, hIdx: hIdx, hNode: hNode, nodes: nodes, edges: edges)
        } else {
            refreshStandardSchedule(train: &train, nodes: nodes, edges: edges)
        }
    }

    func findHubNode(in train: [RailwayTrain].Element, nodes: [RailwayNode], preferredId: String? = nil) -> (Int, RailwayNode)? {
        // Se abbiamo un preferredId, lo cerchiamo con priorità assoluta per mantenere la coerenza del Takt
        if let pid = preferredId {
            if let idx = train.stops.firstIndex(where: { $0.stationId == pid }),
               let node = nodes.first(where: { $0.id == pid && $0.taktMinutes != nil }) {
                return (idx, node)
            }
        }
        
        // Altrimenti prendiamo il primo nodo Hub Takt che incontriamo nel percorso
        for i in train.stops.indices {
            if let node = nodes.first(where: { $0.id == train.stops[i].stationId && $0.taktMinutes != nil }) {
                return (i, node)
            }
        }
        return nil
    }
    func refreshTaktSchedule(train: inout [RailwayTrain].Element, hIdx: Int, hNode: RailwayNode, nodes: [RailwayNode], edges: [Edge]) {
        let topo = RailwayTopology(nodes: nodes, edges: edges)
        let engine = TaktEngine(
            topology: topo,
            kinematicCalculator: KinematicCalculator(topology: topo)
        )
        engine.refreshTaktSchedule(train: &train, hIdx: hIdx, hNode: hNode)
    }

    func refreshStandardSchedule(train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]) {
        guard let depTime = train.departureTime else { return }
        var currentTime = depTime.normalized()
        
        for j in train.stops.indices {
            if j == 0 {
                train.stops[j].arrival = nil
                train.stops[j].departure = currentTime
            } else {
                let prevId = train.stops[j-1].stationId
                let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(from: prevId, to: train.stops[j].stationId, train: train, nodes: nodes, edges: edges, isStarting: j==1, isStopping: true)
                
                currentTime = currentTime.addingTimeInterval(tt)
                let roundedArr = roundToBusinessSeconds(currentTime)
                train.stops[j].arrival = roundedArr
                
                let extraDwell = train.stops[j].extraDwellTime ?? 0
                let dwellDuration = (Double(train.stops[j].minDwellTime) + extraDwell) * 60
                
                currentTime = roundedArr.addingTimeInterval(dwellDuration)
                let roundedDep = roundToBusinessSeconds(currentTime)
                train.stops[j].departure = (j < train.stops.count - 1) ? roundedDep : nil
                if let d = train.stops[j].departure { currentTime = d }
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// Intervalla i treni per l'elaborazione A* (Andata 1, Ritorno 1, Andata 2, Ritorno 2...)
    func interleaveTrainsForAStar(_ trains: [Train]) -> [Train] {
        guard trains.count > 1 else { return trains }
        
        let routeId = trains.first?.routeId
        let routeTrains = trains.filter { $0.routeId == routeId }
        
        let firstDest = routeTrains.first?.stops.last?.stationId
        let outward = routeTrains.filter { $0.stops.last?.stationId == firstDest }
        let returns = routeTrains.filter { $0.stops.last?.stationId != firstDest }
        
        var interleaved: [Train] = []
        let maxCount = max(outward.count, returns.count)
        
        for i in 0..<maxCount {
            if i < outward.count { interleaved.append(outward[i]) }
            if i < returns.count { interleaved.append(returns[i]) }
        }
        
        let others = trains.filter { $0.routeId != routeId }
        interleaved.append(contentsOf: others)
        
        print("   🔄 [A*] Treni intervallati (Andata: \(outward.count), Ritorno: \(returns.count)): \(interleaved.map { $0.name }.joined(separator: ", "))")
        return interleaved
    }
    
    
    func minutesDiff(_ t1: Train, _ t2: Train) -> Int {
        guard let d1 = t1.departureTime, let d2 = t2.departureTime else { return 0 }
        return Int(d2.timeIntervalSince(d1) / 60)
    }
}
