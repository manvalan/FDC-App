import Foundation

/// Bridge legacy: delega al motore unificato `TaktEngine` in Services/Scheduling.
extension RailwayScheduleOptimizer {

    private func makeTaktEngine(
        nodes: [RailwayNode], edges: [Edge]
    ) -> TaktEngine {
        let topo = RailwayTopology(nodes: nodes, edges: edges)
        return TaktEngine(
            topology: topo,
            kinematicCalculator: KinematicCalculator(topology: topo)
        )
    }

    func generaOrarioCadenzato(
        newTrains: [RailwayTrain],
        existingTrains: [RailwayTrain],
        nodes: [RailwayNode],
        edges: [Edge],
        preferredTaktNodeId: String? = nil
    ) async -> [RailwayTrain] {
        let engine = makeTaktEngine(nodes: nodes, edges: edges)
        return await engine.generaOrarioCadenzato(
            newTrains: newTrains,
            existingTrains: existingTrains,
            preferredTaktNodeId: preferredTaktNodeId,
            conflictDetector: { [self] subset, existing, cache in
                detectConflicts(
                    subset, existingTrains: existing,
                    nodes: nodes, edges: edges, pathCache: &cache
                )
            }
        )
    }

    func taktHubTimes(
        train: Train, base: Date, calendar: Calendar
    ) -> (Date, Date) {
        let engine = TaktEngine(
            topology: RailwayTopology(),
            kinematicCalculator: KinematicCalculator(topology: RailwayTopology())
        )
        return engine.taktHubTimes(train: train, base: base, calendar: calendar)
    }

    func roundToBusinessSeconds(_ date: Date) -> Date {
        TaktEngine.roundToBusinessSeconds(date)
    }
}
