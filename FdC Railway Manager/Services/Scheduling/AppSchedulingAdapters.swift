import Foundation

struct FDCSchedulerTravelTimeAdapter: TrainTravelTimeCalculating {
    func travelTimeHours(
        distanceKm: Double,
        maxSpeedKmh: Double,
        train: Train,
        initialSpeedKmh: Double,
        finalSpeedKmh: Double,
        gradient: Double
    ) -> Double {
        FDCSchedulerEngine.calculateTravelTime(
            distanceKm: distanceKm,
            maxSpeedKmh: maxSpeedKmh,
            train: train,
            initialSpeedKmh: initialSpeedKmh,
            finalSpeedKmh: finalSpeedKmh,
            gradient: gradient
        )
    }

    func travelTimeBetweenNodes(
        from: String,
        to: String,
        train: Train,
        nodes: [Node],
        edges: [Edge],
        isStarting: Bool,
        isStopping: Bool
    ) -> TimeInterval {
        FDCSchedulerEngine.calculateTravelTimeBetweenNodes(
            from: from,
            to: to,
            train: train,
            nodes: nodes,
            edges: edges,
            isStarting: isStarting,
            isStopping: isStopping
        )
    }
}

struct ConflictManagerAdapter: ScheduleConflictDetecting {
    private let manager = ConflictManager()

    func detectConflicts(
        nodes: [Node],
        edges: [Edge],
        trains: [Train],
        pathCache: inout [String: [Edge]]?
    ) -> [ScheduleConflict] {
        var cache = pathCache
        let result = manager.calculateConflictsWithCapacities(
            nodes: nodes,
            edges: edges,
            trains: trains,
            pathCache: &cache
        ).0
        pathCache = cache
        return result
    }
}

@MainActor
struct GeneticOptimizerAdapter: ScheduleGeneticOptimizing {
    private let optimizer = GeneticOptimizer()

    func optimize(
        newTrains: [Train],
        existingTrains: [Train],
        nodes: [Node],
        edges: [Edge],
        iterations: Int
    ) async -> [Train] {
        await optimizer.optimize(
            newTrains: newTrains,
            existingTrains: existingTrains,
            nodes: nodes,
            edges: edges,
            iterations: iterations
        )
    }
}

struct ScheduleAIResolverAdapter: ScheduleAIOptimizing {
    private var resolver = ScheduleAIResolver()

    func optimize(
        trains: [Train],
        existingTrains: [Train],
        nodes: [Node],
        edges: [Edge],
        preferredHubId: String?,
        hasTaktRequired: Bool,
        pathCache: inout [String: [Edge]],
        conflictDetector: ScheduleConflictDetecting,
        refreshTrains: (inout [Train], String?) -> Void
    ) async -> [Train] {
        let topology = RailwayTopology(nodes: nodes, edges: edges)
        let travel = FDCSchedulerTravelTimeAdapter()
        let refresher = ScheduleRefresher(topology: topology, travelTimeCalculator: travel)
        return await resolver.optimize(
            trains: trains,
            existingTrains: existingTrains,
            topology: topology,
            refresher: refresher,
            conflictDetector: conflictDetector,
            preferredHubId: preferredHubId,
            hasTaktRequired: hasTaktRequired,
            pathCache: &pathCache,
            refreshTrains: refreshTrains
        )
    }
}

extension ScheduleOptimizationPipeline {
    init(topology: RailwayTopology) {
        let travel = FDCSchedulerTravelTimeAdapter()
        self.init(
            topology: topology,
            conflictDetector: ConflictManagerAdapter(),
            geneticOptimizer: GeneticOptimizerAdapter(),
            travelTimeCalculator: travel,
            aiOptimizer: ScheduleAIResolverAdapter()
        )
    }
}

extension PathResolver {
    init(network: NetworkModel) {
        self.init(topology: RailwayTopology(nodes: network.nodes, edges: network.edges))
    }
}

extension KinematicCalculator {
    init(network: NetworkModel, travelTimeCalculator: TrainTravelTimeCalculating = FDCSchedulerTravelTimeAdapter()) {
        self.init(
            topology: RailwayTopology(nodes: network.nodes, edges: network.edges),
            travelTimeCalculator: travelTimeCalculator
        )
    }
}

extension TaktEngine {
    init(network: NetworkModel, kinematicCalculator: KinematicCalculator) {
        self.init(topology: kinematicCalculator.topology, kinematicCalculator: kinematicCalculator, travelTimeCalculator: kinematicCalculator.travelTimeCalculator)
    }
}
