import Foundation

extension Edge {
    /// Converts each undirected `.highSpeed` edge (with `pairedEdgeId == nil`)
    /// **or** any legacy edge flagged with `needsPairedMigration`
    /// into two oriented edges (A→B and B→A) with `pairedEdgeId`
    /// cross-referenced between them.
    ///
    /// `needsPairedMigration` is set by `Edge.init(from:)` when the raw
    /// JSON value is `"double"` (written by the app before Fase 3f).
    ///
    /// Idempotent: edges that already have `pairedEdgeId != nil` are passed
    /// through unchanged. Call this once after deserialisation.
    ///
    /// - Returns: The migrated edge list and the number of edges converted.
    static func migrateDoubleTracksToSingleOriented(
        _ edges: [Edge]
    ) -> (result: [Edge], convertedCount: Int) {
        var result: [Edge] = []
        var convertedCount = 0
        for edge in edges {
            guard edge.pairedEdgeId == nil,
                  edge.trackType == .highSpeed || edge.needsPairedMigration
            else {
                result.append(edge)
                continue
            }
            let fwdId = UUID()
            let bwdId = UUID()
            result.append(makeOrientedEdge(from: edge, id: fwdId, pairedId: bwdId, reversed: false))
            result.append(makeOrientedEdge(from: edge, id: bwdId, pairedId: fwdId, reversed: true))
            convertedCount += 1
        }
        return (result, convertedCount)
    }

    // MARK: - Private helpers

    private static func orientedTrackType(for type: TrackType) -> TrackType {
        type == .highSpeed ? .highSpeed : .single
    }

    private static func makeOrientedEdge(
        from source: Edge,
        id: UUID,
        pairedId: UUID,
        reversed: Bool
    ) -> Edge {
        var edge        = source
        edge.id         = id
        edge.pairedEdgeId = pairedId
        edge.trackType  = orientedTrackType(for: source.trackType)
        if reversed {
            edge.from          = source.to
            edge.to            = source.from
            edge.controlPoints = Array(source.controlPoints.reversed())
        }
        return edge
    }
}
