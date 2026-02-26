import Foundation
import SwiftUI
import Combine

extension RailwayScheduleOptimizer {
    // MARK: - Helpers & Step 6 Integation
    
    func performCloudOptimization(_ trains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil) async -> RailwayAIResponse? {
        var all = existingTrains + trains
        refreshMultipleSchedules(&all, nodes: nodes, edges: edges, pathCache: &pathCache, preferredHubId: preferredHubId)
        var dc: [String: [Edge]]? = pathCache
        let currentConflicts = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dc).0
        if let u = dc { pathCache = u }
        
        if currentConflicts.isEmpty { return nil }
        
        // PIGNOLO PROTOCOL: Pass fixed train IDs to AI so it treats them as immutable constraints
        // Also specify activeAgentIds (the mobile ones) to enable Focus mode on the server
        let fixedIds = Set(existingTrains.map { $0.id })
        let activeIds = Set(trains.map { $0.id })
        
        let req = aiService.createRequest(
            nodes: nodes,
            edges: edges,
            trains: all, 
            fixedTrainIds: fixedIds, 
            activeAgentIds: activeIds,
            temporalObstacles: nil,
            conflicts: currentConflicts
        )
        
        do {
            // PIGNOLO PROTOCOL: Combine Publisher to Async/Await bridge
            for try await response in aiService.optimize(request: req).values {
                return response
            }
            return nil 
        } catch {
            print("⚠️ [PIPELINE] Errore chiamata AI: \(error)")
            return nil
        }
    }
    
    func applyAIResolutions(_ trains: [Train], resolutions: [RailwayAIResolution]) -> [Train] {
        var updated = trains
        for res in resolutions {
            if let idx = updated.firstIndex(where: { aiService.getTrainUUID(optimizerId: res.train_id) == $0.id }) {
                // Applica Time Shift
                if let dep = updated[idx].departureTime {
                    updated[idx].departureTime = dep.addingTimeInterval(res.time_adjustment_min * 60)
                }
                
                if let delays = res.dwell_delays {
                    for (sIdx, delay) in delays.enumerated() where sIdx < updated[idx].stops.count {
                        if delay > 0 {
                            updated[idx].stops[sIdx].extraDwellTime += delay
                        }
                    }
                }
            }
        }
        return updated
    }
    
    func refreshPhysicalSchedules(_ trains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil) -> [RailwayTrain] {
        var result = trains
        refreshMultipleSchedules(&result, nodes: nodes, edges: edges, pathCache: &pathCache, preferredHubId: preferredHubId)
        return result
    }
    
    func detectConflicts(_ trainSubset: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) -> [ScheduleConflict] {
        let allTrains = existingTrains + trainSubset
        var dc: [String: [Edge]]? = pathCache
        let res = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: allTrains, pathCache: &dc).0
        if let u = dc { pathCache = u }
        return res
    }
    

}
