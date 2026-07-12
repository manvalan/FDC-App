import Foundation

public protocol ScheduleConflictDetecting {
    func detectConflicts(
        nodes: [Node],
        edges: [Edge],
        trains: [Train],
        pathCache: inout [String: [Edge]]?
    ) -> [ScheduleConflict]
}
