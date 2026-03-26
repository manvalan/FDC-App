import Foundation

/// A single point in a RailwayLine's altimetric profile.
///
/// Produced by `LineProfilePoint.buildProfile(for:nodes:edges:allLines:)`.
/// Each point is backed by either a Node (station/junction) or a
/// TrackControlPoint (intermediate waypoint on an edge between two stations).
///
/// The builder emits points in canonical A→B order matching
/// `RailwayLine.nodeIds`. For reversed edges (B→A stored in the model),
/// `controlPoint` indices are pre-adjusted so the caller always writes
/// `edge.controlPoints[index].altitude` directly — no direction logic needed.
public struct LineProfilePoint {

    // MARK: - Source

    /// Where in the model this point's altitude is stored.
    public enum Source {
        /// A station or junction node.
        /// Altitude is read/written via Node.altitude and
        /// NetworkModel.updateNode(_:alt:).
        case node(nodeId: String)

        /// An intermediate waypoint stored on an edge.
        /// `index` is the position in Edge.controlPoints normalised for the
        /// canonical A→B direction of the line: if buildProfile found only
        /// the reversed B→A edge, the index is already (count - 1 - j) so
        /// the caller writes `edge.controlPoints[index].altitude` directly.
        /// syncPairedControlPoints in NetworkModel.edges.didSet propagates
        /// the change to the paired edge automatically.
        case controlPoint(edgeId: String, index: Int)
    }

    // MARK: - Fields

    public var source: Source
    /// Altitude in metres (from the model, or linearly interpolated when
    /// TrackControlPoint.altitude == nil).
    public var altitude: Double
    /// Cumulative distance from the first node of the line, in km.
    /// Uses Edge.distance (not geographic great-circle distance).
    public var distanceFromStart: Double
    /// True for the very first and last points of the whole line.
    /// Rendered as a larger handle (green / red) in LineAltitudeChart.
    public var isEndpoint: Bool
    /// Non-nil only for .node sources. Used as the Alert title when
    /// the user drags a shared-station handle.
    public var stationName: String?
    /// True when the node appears in more than one RailwayLine.
    /// The LineProfileEditorView shows a confirmation Alert before
    /// committing the altitude change to the model.
    public var isShared: Bool
    /// Number of physical edges (binari) connected to this node in the
    /// network. Used in the Alert body "collegata a N binari".
    /// Always 0 for .controlPoint sources.
    public var connectedEdgesCount: Int

    // MARK: - Builder

    /// Builds the ordered altimetric profile for a RailwayLine.
    ///
    /// The sequence covers every node in `line.nodeIds` plus all
    /// TrackControlPoint intermediates of each connecting edge, in
    /// canonical A→B order.
    ///
    /// - Parameters:
    ///   - line:      The line whose profile to build.
    ///   - nodes:     `NetworkModel.nodes` — all nodes in the network.
    ///   - edges:     `NetworkModel.edges` — all edges in the network.
    ///   - allLines:  `NetworkModel.lines` — used to compute `isShared`.
    /// - Returns: Ordered array from the first to the last node.
    ///   Empty if the line has fewer than 2 nodes or all edges are missing.
    public static func buildProfile(
        for line: RailwayLine,
        nodes: [Node],
        edges: [Edge],
        allLines: [RailwayLine]
    ) -> [LineProfilePoint] {
        let nodeIds = line.nodeIds
        guard nodeIds.count >= 2 else { return [] }

        var result: [LineProfilePoint] = []
        var cumDist: Double = 0
        var appendedNodeIds: Set<String> = []

        for i in 0 ..< nodeIds.count - 1 {
            let fromId = nodeIds[i]
            let toId   = nodeIds[i + 1]
            guard let fromNode = nodes.first(where: { $0.id == fromId }) else { continue }
            let toNode = nodes.first { $0.id == toId }

            // Append fromNode if not yet in result (first segment, or after a gap).
            if !appendedNodeIds.contains(fromId) {
                let isFirst = result.isEmpty
                result.append(
                    nodePoint(fromNode, dist: cumDist, isEndpoint: isFirst,
                              edges: edges, allLines: allLines)
                )
                appendedNodeIds.insert(fromId)
            }

            // Find edge: prefer canonical A→B, fallback to reversed B→A.
            guard let (edge, isReversed) = resolveEdge(
                from: fromId, to: toId, edges: edges
            ) else {
                // Gap in the graph: no edge found, distance unknown.
                // Append toNode at current cumDist so it does not
                // overlap the fromNode in the next iteration.
                if !appendedNodeIds.contains(toId), let toNode {
                    let isLast = i == nodeIds.count - 2
                    result.append(
                        nodePoint(toNode, dist: cumDist, isEndpoint: isLast,
                                  edges: edges, allLines: allLines)
                    )
                    appendedNodeIds.insert(toId)
                }
                continue
            }

            appendControlPoints(
                of: edge, isReversed: isReversed,
                fromAlt: fromNode.altitude ?? 0,
                toAlt:   toNode?.altitude ?? 0,
                cumDist: cumDist,
                into: &result
            )

            cumDist += edge.distance

            if let toNode {
                let isLast = i == nodeIds.count - 2
                result.append(
                    nodePoint(toNode, dist: cumDist, isEndpoint: isLast,
                              edges: edges, allLines: allLines)
                )
                appendedNodeIds.insert(toId)
            }
        }

        return result
    }

    // MARK: - Private helpers

    private static func nodePoint(
        _ node: Node,
        dist: Double,
        isEndpoint: Bool,
        edges: [Edge],
        allLines: [RailwayLine]
    ) -> LineProfilePoint {
        let shared = allLines.filter { $0.nodeIds.contains(node.id) }.count > 1
        let edgeCount = edges.filter {
            $0.from == node.id || $0.to == node.id
        }.count
        return LineProfilePoint(
            source: .node(nodeId: node.id),
            altitude: node.altitude ?? 0,
            distanceFromStart: dist,
            isEndpoint: isEndpoint,
            stationName: node.name,
            isShared: shared,
            connectedEdgesCount: edgeCount
        )
    }

    private static func resolveEdge(
        from fromId: String,
        to toId: String,
        edges: [Edge]
    ) -> (Edge, isReversed: Bool)? {
        if let e = edges.first(where: { $0.from == fromId && $0.to == toId }) {
            return (e, false)
        }
        if let e = edges.first(where: { $0.from == toId && $0.to == fromId }) {
            return (e, true)
        }
        return nil
    }

    private static func appendControlPoints(
        of edge: Edge,
        isReversed: Bool,
        fromAlt: Double,
        toAlt: Double,
        cumDist: Double,
        into result: inout [LineProfilePoint]
    ) {
        let cps = edge.controlPoints
        let count = cps.count
        guard count > 0 else { return }
        for j in 0 ..< count {
            // actualIndex: position in edge.controlPoints for direct write
            let actualIndex = isReversed ? (count - 1 - j) : j
            let cp = cps[actualIndex]
            let t = Double(j + 1) / Double(count + 1)
            let alt = cp.altitude ?? (fromAlt + (toAlt - fromAlt) * t)
            result.append(LineProfilePoint(
                source: .controlPoint(
                    edgeId: edge.id.uuidString,
                    index: actualIndex
                ),
                altitude: alt,
                distanceFromStart: cumDist + t * edge.distance,
                isEndpoint: false,
                stationName: nil,
                isShared: false,
                connectedEdgesCount: 0
            ))
        }
    }
}
