import Foundation
import Combine

/// Step 6 della pipeline: ottimizzazione AI Cloud e applicazione risoluzioni.
struct ScheduleAIResolver {
    var aiService: RailwayAIService = .shared

    func optimize(
        trains: [Train],
        existingTrains: [Train],
        topology: RailwayTopology,
        refresher: ScheduleRefresher,
        conflictManager: ConflictManager,
        preferredHubId: String?,
        hasTaktRequired: Bool,
        pathCache: inout [String: [Edge]]
    ) async -> [Train] {
        let conflictsBefore = detectConflicts(
            trains, existingTrains: existingTrains,
            topology: topology, conflictManager: conflictManager,
            pathCache: &pathCache
        ).count

        guard let response = await performCloudOptimization(
            trains: trains, existingTrains: existingTrains,
            topology: topology, refresher: refresher,
            conflictManager: conflictManager,
            preferredHubId: preferredHubId, pathCache: &pathCache
        ),
        let resolutions = response.resolutions, !resolutions.isEmpty else {
            return trains
        }

        let avgConfidence = resolutions.compactMap(\.confidence).reduce(0.0, +)
            / Double(max(resolutions.count, 1))
        let confidence = response.ml_confidence ?? avgConfidence
        print("   📥 AI: \(resolutions.count) risoluzioni (confidenza \(Int(confidence * 100))%)")

        guard confidence >= 0.15 else {
            print("   ⚠️ Confidenza AI troppo bassa, soluzione scartata.")
            return trains
        }

        var results = applyResolutions(trains, resolutions: resolutions)
        if !hasTaktRequired {
            refresher.refreshMultiple(&results, preferredHubId: preferredHubId)
        }

        let conflictsAfter = detectConflicts(
            results, existingTrains: existingTrains,
            topology: topology, conflictManager: conflictManager,
            pathCache: &pathCache
        ).count

        if conflictsAfter > conflictsBefore + 2 {
            print("   ❌ [ROLLBACK] AI peggiora scenario (\(conflictsBefore) -> \(conflictsAfter)).")
            return trains
        }

        print("   ✅ Conflitti post-AI: \(conflictsAfter) (Δ \(conflictsAfter - conflictsBefore))")
        return results
    }

    private func performCloudOptimization(
        trains: [Train], existingTrains: [Train],
        topology: RailwayTopology, refresher: ScheduleRefresher,
        conflictManager: ConflictManager,
        preferredHubId: String?, pathCache: inout [String: [Edge]]
    ) async -> RailwayAIResponse? {
        var all = existingTrains + trains
        refresher.refreshMultiple(&all, preferredHubId: preferredHubId)

        var dc: [String: [Edge]]? = pathCache
        let currentConflicts = conflictManager.calculateConflictsWithCapacities(
            nodes: topology.nodes, edges: topology.edges,
            trains: all, pathCache: &dc
        ).0
        if let updated = dc { pathCache = updated }

        guard !currentConflicts.isEmpty else { return nil }

        let req = aiService.createRequest(
            nodes: topology.nodes, edges: topology.edges, trains: all,
            fixedTrainIds: Set(existingTrains.map(\.id)),
            activeAgentIds: Set(trains.map(\.id)),
            temporalObstacles: nil, conflicts: currentConflicts
        )

        do {
            for try await response in aiService.optimize(request: req).values {
                return response
            }
            return nil
        } catch {
            print("⚠️ [NEW PIPELINE] Errore chiamata AI: \(error)")
            return nil
        }
    }

    private func applyResolutions(
        _ trains: [Train], resolutions: [RailwayAIResolution]
    ) -> [Train] {
        var updated = trains
        for res in resolutions {
            guard let idx = updated.firstIndex(where: {
                aiService.getTrainUUID(optimizerId: res.train_id) == $0.id
            }) else { continue }

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
        return updated
    }

    private func detectConflicts(
        _ trainSubset: [Train], existingTrains: [Train],
        topology: RailwayTopology, conflictManager: ConflictManager,
        pathCache: inout [String: [Edge]]
    ) -> [ScheduleConflict] {
        let allTrains = existingTrains + trainSubset
        var dc: [String: [Edge]]? = pathCache
        let result = conflictManager.calculateConflictsWithCapacities(
            nodes: topology.nodes, edges: topology.edges,
            trains: allTrains, pathCache: &dc
        ).0
        if let updated = dc { pathCache = updated }
        return result
    }
}
