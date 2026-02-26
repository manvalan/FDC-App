import Foundation
import SwiftUI
import Combine

extension RailwayScheduleOptimizer {
    // MARK: - Step 1: Time Optimization
    
    func optimizeDepartureTimes(_ newTrains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) -> [RailwayTrain] {
        var optimized: [RailwayTrain] = []
        
        // PIGNOLO BOOST: 2-Phase Optimization (Coarse -> Fine)
        // Drastically reduces simulations from ~32 per train to ~10 per train
        
        for (idx, train) in newTrains.enumerated() {
            if Task.isCancelled { break }
            var bestTrain = train
            var minConflicts = Int.max
            var initialConflicts = 0
            
            // Baseline calculation
            var candidate = train
            refreshSingleTrainSchedule(&candidate, nodes: nodes, edges: edges, pathCache: &pathCache)
            let all = existingTrains + optimized + [candidate]
            var dummyCache: [String: [Edge]]? = pathCache
            initialConflicts = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dummyCache).0.count
            if let updated = dummyCache { pathCache = updated }
            minConflicts = initialConflicts
            
            // IF base is perfect, skip optimization
            if minConflicts == 0 {
                optimized.append(bestTrain)
                continue
            }
            
            // Phase 1: Coarse Search (Steps of 10 mins)
            // Range: -60 to +60
            let coarseShifts = [-10, 10, -20, 20, -30, 30, -50, 50]
            var bestCoarseShift = 0
            
            for shift in coarseShifts {
                var candidate = train
                if let dep = train.departureTime {
                    candidate.departureTime = Calendar.current.date(byAdding: .minute, value: shift, to: dep)
                }
                
                refreshSingleTrainSchedule(&candidate, nodes: nodes, edges: edges, pathCache: &pathCache)
                let all = existingTrains + optimized + [candidate]
                var dc: [String: [Edge]]? = pathCache
                let count = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dc).0.count
                if let u = dc { pathCache = u }
                
                if count < minConflicts {
                    minConflicts = count
                    bestTrain = candidate
                    bestCoarseShift = shift
                }
            }
            
            // Phase 2: Fine Refinement (Around best coarse shift)
            // Range: +/- 5 mins around the winner
            if minConflicts > 0 {
                 let fineShifts = [-5, -2, -1, 1, 2, 5]
                 for fine in fineShifts {
                     let totalShift = bestCoarseShift + fine
                     var candidate = train
                     if let dep = train.departureTime {
                         candidate.departureTime = Calendar.current.date(byAdding: .minute, value: totalShift, to: dep)
                     }
                     
                     refreshSingleTrainSchedule(&candidate, nodes: nodes, edges: edges, pathCache: &pathCache)
                     let all = existingTrains + optimized + [candidate]
                     var dc: [String: [Edge]]? = pathCache
                     let count = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dc).0.count
                     if let u = dc { pathCache = u }
                     
                     if count < minConflicts {
                         minConflicts = count
                         bestTrain = candidate
                     }
                 }
            }
            
            optimized.append(bestTrain)
            
            let finalShift = minutesDiff(train, bestTrain)
            if finalShift != 0 || minConflicts != initialConflicts {
                print("   🔹 Treno \(idx+1)/\(newTrains.count): Shift \(finalShift)m (Conf: \(initialConflicts)->\(minConflicts))")
            }
        }
        
        return optimized
    }
    
    func analyzeHotspots(conflicts: [ScheduleConflict], nodes: [RailwayNode]) -> [String: Int] {
        var heatmap: [String: Int] = [:]
        
        for conflict in conflicts {
            let resId = conflict.locationId
            let name = conflict.locationName
            
            if resId.hasPrefix("SEGMENT::") {
                let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
                let parts = content.components(separatedBy: "--")
                for stationId in parts {
                    let stationName = nodes.first(where: { $0.id == stationId })?.name ?? stationId
                    heatmap[stationName, default: 0] += 1
                }
            } else if resId.hasPrefix("STATION::") {
                let stationId = resId.components(separatedBy: "::")[1]
                let stationName = nodes.first(where: { $0.id == stationId })?.name ?? stationId
                heatmap[stationName, default: 0] += 1
            } else {
                heatmap[name, default: 0] += 1
            }
        }
        return heatmap
    }
    

}
