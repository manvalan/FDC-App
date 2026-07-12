import Foundation

public protocol ScheduleGeneticOptimizing {
    func optimize(
        newTrains: [Train],
        existingTrains: [Train],
        nodes: [Node],
        edges: [Edge],
        iterations: Int
    ) async -> [Train]
}
