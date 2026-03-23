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
}
