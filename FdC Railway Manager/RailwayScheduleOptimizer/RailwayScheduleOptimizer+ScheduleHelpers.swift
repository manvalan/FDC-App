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
        let (hArr, hDep) = calculateHubTimes(for: train, hIdx: hIdx, hNode: hNode)
        
        train.stops[hIdx].arrival = hArr
        train.stops[hIdx].departure = (hIdx < train.stops.count - 1) ? hDep : nil
        
        propagateBackward(from: hIdx, arrival: hArr, train: &train, nodes: nodes, edges: edges)
        propagateForward(from: hIdx, departure: hDep, train: &train, nodes: nodes, edges: edges)
        
        train.departureTime = train.stops.first?.departure ?? train.stops.first?.arrival
    }

    func calculateHubTimes(for train: [RailwayTrain].Element, hIdx: Int, hNode: RailwayNode) -> (Date, Date) {
        let calendar = Calendar.current
        let takt = hNode.taktMinutes ?? 0
        let isT1 = (train.number ?? 0) % 2 == 1

        let referenceTime = train.stops[hIdx].arrival ?? train.departureTime ?? Date()
        let ttToHub = (train.stops[hIdx].arrival == nil) ? Double(hIdx) * 180.0 : 0
        let estArrAtHub = referenceTime.addingTimeInterval(ttToHub)
        
        var anchorBase = calendar.date(bySetting: .minute, value: takt, of: estArrAtHub) ?? estArrAtHub
        if anchorBase < estArrAtHub.addingTimeInterval(-1800) { anchorBase = calendar.date(byAdding: .hour, value: 1, to: anchorBase) ?? anchorBase }
        if anchorBase > estArrAtHub.addingTimeInterval(1800) { anchorBase = calendar.date(byAdding: .hour, value: -1, to: anchorBase) ?? anchorBase }

        var hArr: Date
        var hDep: Date

        if train.isMainTrain {
            // Treni principali: crossing stretto ±2-3 min
            if isT1 {
                hArr = calendar.date(bySetting: .minute, value: (takt - 2 + 60) % 60, of: anchorBase) ?? anchorBase
            } else {
                hArr = calendar.date(bySetting: .minute, value: (takt - 3 + 60) % 60, of: anchorBase) ?? anchorBase
            }
            hArr = calendar.date(bySetting: .second, value: 0, of: hArr) ?? hArr
            hDep = hArr.addingTimeInterval((isT1 ? 3 : 5) * 60)
        } else {
            // Treni non principali: posizionamento "a cavallo" della finestra dei principali.
            // Regola semplificata: Arrival = Takt - 10, Departure = Takt + 10.
            // Non usiamo più la parità numero treno per evitare inversioni illogiche.
            hArr = calendar.date(bySetting: .minute, value: (takt - 10 + 60) % 60, of: anchorBase) ?? anchorBase
            hArr = calendar.date(bySetting: .second, value: 0, of: hArr) ?? hArr
            hDep = calendar.date(bySetting: .minute, value: (takt + 10 + 60) % 60, of: anchorBase) ?? anchorBase
            hDep = calendar.date(bySetting: .second, value: 0, of: hDep) ?? hDep
            
            // Se Departure è prima di Arrival (raro con ±60min anchor), aggiustiamo
            if hDep < hArr { hDep = calendar.date(byAdding: .hour, value: 1, to: hDep) ?? hDep }
        }
        
        #if DEBUG
        print("🔄 [Refresh Takt] \(train.name) [\(train.isMainTrain ? "MAIN" : "SEC ")] Hub: \(hNode.id) (#\(hIdx)) -> EstArrAtHub: \(formatTime(estArrAtHub)), Arr: \(formatTime(hArr)), Dep: \(formatTime(hDep))")
        #endif

        return (hArr, hDep)
    }

    func propagateBackward(from hIdx: Int, arrival: Date, train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]) {
        guard hIdx > 0 else { return }
        var nextArrivalAtTarget = arrival
        for j in (0..<hIdx).reversed() {
            let idNext = train.stops[j+1].stationId
            let idCur = train.stops[j].stationId
            let isStoppingAtNext = !train.stops[j+1].isSkipped
            let isStartingAtCur = (j == 0)
            
            let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(from: idCur, to: idNext, train: train, nodes: nodes, edges: edges, isStarting: isStartingAtCur, isStopping: isStoppingAtNext)
            
            let depTime = nextArrivalAtTarget.addingTimeInterval(-tt)
            train.stops[j].departure = roundToBusinessSeconds(depTime)
            
            let dwellMinutes = train.stops[j].isSkipped ? 0.0 : Double(train.stops[j].minDwellTime)
            let extraDwell = train.stops[j].extraDwellTime ?? 0
            let dwell = train.stops[j].isSkipped ? 0.0 : max(120.0, (dwellMinutes + extraDwell) * 60.0)
            
            let arrTime = (train.stops[j].departure ?? depTime).addingTimeInterval(-dwell)
            train.stops[j].arrival = (j > 0) ? roundToBusinessSeconds(arrTime) : nil
            
            nextArrivalAtTarget = train.stops[j].arrival ?? (train.stops[j].departure!.addingTimeInterval(-60))
        }
    }

    func propagateForward(from hIdx: Int, departure: Date, train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]) {
        guard hIdx < train.stops.count - 1 else { return }
        var currentDeparture = departure
        for j in (hIdx + 1)..<train.stops.count {
            let idPrev = train.stops[j-1].stationId
            let idCur = train.stops[j].stationId
            let isStoppingAtCur = !train.stops[j].isSkipped
            let isStartingAtPrev = (j-1 == 0) && !train.stops[j-1].isSkipped
            
            let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(from: idPrev, to: idCur, train: train, nodes: nodes, edges: edges, isStarting: isStartingAtPrev, isStopping: isStoppingAtCur)
            
            let arrTime = currentDeparture.addingTimeInterval(tt)
            train.stops[j].arrival = roundToBusinessSeconds(arrTime)
            
            let dwellMinutes = train.stops[j].isSkipped ? 0.0 : Double(train.stops[j].minDwellTime)
            let extraDwell = train.stops[j].extraDwellTime ?? 0
            let dwell = train.stops[j].isSkipped ? 0.0 : max(120.0, (dwellMinutes + extraDwell) * 60.0)
            
            let depTime = (train.stops[j].arrival ?? arrTime).addingTimeInterval(dwell)
            train.stops[j].departure = (j < train.stops.count - 1) ? roundToBusinessSeconds(depTime) : nil
            
            if let d = train.stops[j].departure { currentDeparture = d } 
            else { currentDeparture = (train.stops[j].arrival ?? arrTime).addingTimeInterval(60) }
        }
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
