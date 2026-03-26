import Foundation

extension RailroadNetwork {

    /// Migrates any bidirectional (`.double`, `.highSpeed`) edges in the current
    /// network to pairs of oriented single edges. Idempotent — safe to call
    /// multiple times on the same network.
    ///
    /// Does NOT create a checkpoint: the caller (IOManager) is responsible for
    /// calling `clearUndoHistory()` immediately after so no stale state leaks
    /// onto the undo stack.
    func migrateDoubleTracksToSingle() {
        let (migrated, count) = Edge.migrateDoubleTracksToSingleOriented(network.edges)
        guard count > 0 else { return }
        network.edges = migrated
        print("🔄 [Migration] \(count) edge(s) converted to paired oriented single edges")
    }

    /// Ensures every RailwayLine's nodeIds follows the actual graph topology,
    /// inserting any intermediate junction nodes that Dijkstra finds between
    /// consecutive entries.
    ///
    /// Idempotent: a line whose nodeIds already form a valid ordered path
    /// produces the same output on repeated calls.
    ///
    /// Does NOT create a checkpoint — caller owns undo history.
    func migrateLineNodeOrdering() {
        let nodes = network.nodes
        let edges = network.edges
        var fixedCount = 0
        network.lines = network.lines.map { line in
            let duplicateCount = line.nodeIds.count
                - Set(line.nodeIds).count
            if duplicateCount > 0 {
                print("⚠️ [Migration] Line '\(line.name)' had" +
                      " \(duplicateCount) duplicate node(s) in saved data")
            }
            let ordered = NetworkModel.buildOrderedPath(
                through: line.nodeIds,
                nodes: nodes,
                edges: edges,
                lineName: line.name
            )
            guard ordered != line.nodeIds else { return line }
            fixedCount += 1
            var updated = line
            updated.nodeIds = ordered
            return updated
        }
        if fixedCount > 0 {
            print("🔄 [Migration] \(fixedCount) line(s) had node ordering fixed")
        }
    }
}
