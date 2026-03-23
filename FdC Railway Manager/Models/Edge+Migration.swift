import Foundation

extension Edge {
    /// Converts each undirected `.highSpeed` edge (with `pairedEdgeId == nil`)
    /// into two oriented edges (A→B and B→A) with `pairedEdgeId`
    /// cross-referenced between them.
    ///
    /// `.double` was removed in Fase 3f. Legacy JSON files containing
    /// `"double"` are decoded as `.single` (see `TrackType.init(from:)`)
    /// and pass through this function unchanged (no pairedEdgeId).
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
                  edge.trackType == .highSpeed
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
