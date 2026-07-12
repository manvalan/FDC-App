import Foundation

/// Step AI della pipeline: implementato nell'app (RailwayAIService).
public protocol ScheduleAIOptimizing {
    func optimize(
        trains: [Train],
        existingTrains: [Train],
        nodes: [Node],
        edges: [Edge],
        preferredHubId: String?,
        hasTaktRequired: Bool,
        pathCache: inout [String: [Edge]],
        conflictDetector: ScheduleConflictDetecting,
        refreshTrains: (_ trains: inout [Train], _ preferredHubId: String?) -> Void
    ) async -> [Train]
}
