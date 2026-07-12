import Foundation

/// Pipeline di ottimizzazione in `Services/Scheduling` — sostituto del legacy
/// `RailwayScheduleOptimizer.shared.executePipeline`.
struct ScheduleOptimizationPipeline {
    let topology: RailwayTopology
    private let taktEngine: TaktEngine
    private let refresher: ScheduleRefresher
    private let conflictManager = ConflictManager()
    private let geneticOptimizer = GeneticOptimizer()
    private var aiResolver = ScheduleAIResolver()

    init(topology: RailwayTopology) {
        self.topology = topology
        self.taktEngine = TaktEngine(
            topology: topology,
            kinematicCalculator: KinematicCalculator(topology: topology)
        )
        self.refresher = ScheduleRefresher(topology: topology)
    }

    func execute(
        newTrains: [Train],
        existingTrains: [Train],
        useAI: Bool = false,
        useGA: Bool = true,
        preferredTaktNodeId: String? = nil,
        geneticOptimizer overrideGA: GeneticOptimizer? = nil
    ) async -> [Train] {
        if Task.isCancelled { return newTrains }

        let nodes = topology.nodes
        let edges = topology.edges
        var pathCache: [String: [Edge]] = [:]
        let hasTaktRequired = nodes.contains { $0.taktMinutes != nil }
        let effectiveUseGA = hasTaktRequired ? false : useGA

        print("\n🚀 [NEW PIPELINE] Avvio per \(newTrains.count) treni (Takt=\(hasTaktRequired), GA=\(effectiveUseGA))")

        // STEP 1: Ottimizzazione partenze
        var working = newTrains
        if effectiveUseGA {
            working = optimizeDepartureTimes(
                working, existingTrains: existingTrains, pathCache: &pathCache
            )
        }

        // STEP 2: Refresh fisico
        var refreshed = working
        refresher.refreshMultiple(&refreshed, preferredHubId: preferredTaktNodeId)

        // STEP 3-5: Allineamento Takt
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

        // STEP 6: AI Cloud
        if useAI {
            print("🧠 [NEW PIPELINE] AI Cloud Optimization...")
            refreshed = await aiResolver.optimize(
                trains: refreshed,
                existingTrains: existingTrains,
                topology: topology,
                refresher: refresher,
                conflictManager: conflictManager,
                preferredHubId: preferredTaktNodeId,
                hasTaktRequired: hasTaktRequired,
                pathCache: &pathCache
            )
        }

        // STEP 7: Genetic refinement
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

        // STEP 8: Verifica finale
        refresher.refreshMultiple(&refreshed, preferredHubId: preferredTaktNodeId)
        let finalConflicts = detectConflicts(
            refreshed, existingTrains: existingTrains, pathCache: &pathCache
        )
        logFinalReport(conflicts: finalConflicts, totalTrains: refreshed.count)

        print("🏁 [NEW PIPELINE] Completata. Output: \(refreshed.count) treni.\n")
        return refreshed
    }

    // MARK: - Conflict detection

    private func detectConflicts(
        _ trainSubset: [Train],
        existingTrains: [Train],
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

    // MARK: - Departure shift optimization

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
