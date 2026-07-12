import Foundation
import FDCDomain

/// Pipeline di ottimizzazione in `Services/Scheduling` — sostituto del legacy
/// `RailwayScheduleOptimizer.shared.executePipeline`.
public struct ScheduleOptimizationPipeline {
    public let topology: RailwayTopology
    private let taktEngine: TaktEngine
    private let refresher: ScheduleRefresher
    private let conflictDetector: ScheduleConflictDetecting
    private let geneticOptimizer: ScheduleGeneticOptimizing
    private let aiOptimizer: ScheduleAIOptimizing?

    public init(
        topology: RailwayTopology,
        conflictDetector: ScheduleConflictDetecting,
        geneticOptimizer: ScheduleGeneticOptimizing,
        travelTimeCalculator: TrainTravelTimeCalculating,
        aiOptimizer: ScheduleAIOptimizing? = nil
    ) {
        self.topology = topology
        self.conflictDetector = conflictDetector
        self.geneticOptimizer = geneticOptimizer
        self.aiOptimizer = aiOptimizer
        let kinematic = KinematicCalculator(topology: topology, travelTimeCalculator: travelTimeCalculator)
        self.taktEngine = TaktEngine(
            topology: topology,
            kinematicCalculator: kinematic,
            travelTimeCalculator: travelTimeCalculator
        )
        self.refresher = ScheduleRefresher(topology: topology, travelTimeCalculator: travelTimeCalculator)
    }

    public func execute(
        newTrains: [Train],
        existingTrains: [Train],
        useAI: Bool = false,
        useGA: Bool = true,
        preferredTaktNodeId: String? = nil,
        geneticOptimizer overrideGA: ScheduleGeneticOptimizing? = nil
    ) async -> [Train] {
        if Task.isCancelled { return newTrains }

        let nodes = topology.nodes
        let edges = topology.edges
        var pathCache: [String: [Edge]] = [:]
        let hasTaktRequired = nodes.contains { $0.taktMinutes != nil }
        let effectiveUseGA = hasTaktRequired ? false : useGA

        print("\n🚀 [NEW PIPELINE] Avvio per \(newTrains.count) treni (Takt=\(hasTaktRequired), GA=\(effectiveUseGA))")

        var working = newTrains
        if effectiveUseGA {
            working = optimizeDepartureTimes(
                working, existingTrains: existingTrains, pathCache: &pathCache
            )
        }

        var refreshed = working
        refresher.refreshMultiple(&refreshed, preferredHubId: preferredTaktNodeId)

        let conflicts = detectConflicts(
            refreshed, existingTrains: existingTrains, pathCache: &pathCache
        )
        if !conflicts.isEmpty || hasTaktRequired {
            if hasTaktRequired {
                refreshed = await taktEngine.generaOrarioCadenzato(
                    newTrains: refreshed,
                    existingTrains: existingTrains,
                    preferredTaktNodeId: preferredTaktNodeId,
                    conflictDetector: { subset, existing, cache in
                        detectConflicts(subset, existingTrains: existing, pathCache: &cache)
                    }
                )
            }
        }

        if useAI, let aiOptimizer {
            print("🧠 [NEW PIPELINE] AI Cloud Optimization...")
            refreshed = await aiOptimizer.optimize(
                trains: refreshed,
                existingTrains: existingTrains,
                nodes: nodes,
                edges: edges,
                preferredHubId: preferredTaktNodeId,
                hasTaktRequired: hasTaktRequired,
                pathCache: &pathCache,
                conflictDetector: conflictDetector,
                refreshTrains: { trains, hubId in
                    refresher.refreshMultiple(&trains, preferredHubId: hubId)
                }
            )
        }

        if effectiveUseGA {
            let ga = overrideGA ?? geneticOptimizer
            refreshed = await ga.optimize(
                newTrains: refreshed,
                existingTrains: existingTrains,
                nodes: nodes,
                edges: edges,
                iterations: 250
            )
        }

        refresher.refreshMultiple(&refreshed, preferredHubId: preferredTaktNodeId)
        let finalConflicts = detectConflicts(
            refreshed, existingTrains: existingTrains, pathCache: &pathCache
        )
        logFinalReport(conflicts: finalConflicts, totalTrains: refreshed.count)

        print("🏁 [NEW PIPELINE] Completata. Output: \(refreshed.count) treni.\n")
        return refreshed
    }

    private func detectConflicts(
        _ trainSubset: [Train],
        existingTrains: [Train],
        pathCache: inout [String: [Edge]]
    ) -> [ScheduleConflict] {
        let allTrains = existingTrains + trainSubset
        var cache: [String: [Edge]]? = pathCache
        let result = conflictDetector.detectConflicts(
            nodes: topology.nodes,
            edges: topology.edges,
            trains: allTrains,
            pathCache: &cache
        )
        if let updated = cache { pathCache = updated }
        return result
    }

    private func optimizeDepartureTimes(
        _ newTrains: [Train],
        existingTrains: [Train],
        pathCache: inout [String: [Edge]]
    ) -> [Train] {
        var optimized: [Train] = []
        let coarseShifts = [-10, 10, -20, 20, -30, 30, -50, 50]
        let fineShifts = [-5, -2, -1, 1, 2, 5]

        for (idx, train) in newTrains.enumerated() {
            if Task.isCancelled { break }
            var bestTrain = train
            var minConflicts = Int.max

            var candidate = train
            refresher.refreshSingle(&candidate)
            minConflicts = conflictCount(
                for: candidate, optimized: optimized,
                existingTrains: existingTrains, pathCache: &pathCache
            )
            if minConflicts == 0 {
                optimized.append(bestTrain)
                continue
            }

            var bestCoarseShift = 0
            for shift in coarseShifts {
                var c = train
                if let dep = train.departureTime {
                    c.departureTime = Calendar.current.date(byAdding: .minute, value: shift, to: dep)
                }
                refresher.refreshSingle(&c)
                let count = conflictCount(
                    for: c, optimized: optimized,
                    existingTrains: existingTrains, pathCache: &pathCache
                )
                if count < minConflicts {
                    minConflicts = count
                    bestTrain = c
                    bestCoarseShift = shift
                }
            }

            if minConflicts > 0 {
                for fine in fineShifts {
                    let totalShift = bestCoarseShift + fine
                    var c = train
                    if let dep = train.departureTime {
                        c.departureTime = Calendar.current.date(
                            byAdding: .minute, value: totalShift, to: dep
                        )
                    }
                    refresher.refreshSingle(&c)
                    let count = conflictCount(
                        for: c, optimized: optimized,
                        existingTrains: existingTrains, pathCache: &pathCache
                    )
                    if count < minConflicts {
                        minConflicts = count
                        bestTrain = c
                    }
                }
            }

            optimized.append(bestTrain)
            let shift = minutesDiff(train, bestTrain)
            if shift != 0 {
                print("   🔹 Treno \(idx + 1)/\(newTrains.count): Shift \(shift)m (Conf: \(minConflicts))")
            }
        }
        return optimized
    }

    private func conflictCount(
        for candidate: Train, optimized: [Train],
        existingTrains: [Train], pathCache: inout [String: [Edge]]
    ) -> Int {
        detectConflicts([candidate] + optimized, existingTrains: existingTrains, pathCache: &pathCache).count
    }

    private func minutesDiff(_ t1: Train, _ t2: Train) -> Int {
        guard let d1 = t1.departureTime, let d2 = t2.departureTime else { return 0 }
        return Int(d2.timeIntervalSince(d1) / 60)
    }

    private func logFinalReport(conflicts: [ScheduleConflict], totalTrains: Int) {
        if conflicts.isEmpty {
            print("\n✨ 🏆 [NEW PIPELINE] 0 conflitti residui. 🏆 ✨")
        } else {
            print("\n⚠️ [NEW PIPELINE] \(conflicts.count) conflitti residui su \(totalTrains) treni.")
        }
    }
}
