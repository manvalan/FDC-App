import SwiftUI

/// Altimetric profile chart for a full RailwayLine.
///
/// Displays all `LineProfilePoint`s on a shared distance axis:
/// - Green circle = line start endpoint (fixed, not draggable)
/// - Red circle   = line end endpoint   (fixed, not draggable)
/// - Blue circles = intermediate stations/junctions (draggable;
///   `onEndNodeDrag` fires on finger-up so the caller can show
///   a confirmation Alert before writing the model)
/// - Orange circles = TrackControlPoints (draggable; writes model
///   immediately via `onChangeControlPoint`)
///
/// `pendingNodeAltitude` lets the caller visually override a node's
/// altitude during drag while the model has not yet been updated.
struct LineAltitudeChart: View {

    let points: [LineProfilePoint]
    var pendingNodeAltitude: (nodeId: String, altitude: Double)?
    let onBeginEdit: () -> Void
    let onNodeDragChanged: (String, Double) -> Void
    let onEndNodeDrag: (String, Double) -> Void
    let onChangeControlPoint: (String, Int, Double) -> Void

    @State private var dragActive = false

    var body: some View {
        GeometryReader { geo in
            let mapping = makeMapping(for: geo.size)
            ZStack(alignment: .topLeading) {
                profileCanvas(mapping: mapping)
                    .frame(width: geo.size.width, height: geo.size.height)
                handlesLayer(mapping: mapping)
            }
        }
    }

    // MARK: - Display data

    private func effectiveAlt(for point: LineProfilePoint) -> Double {
        guard case .node(let nodeId) = point.source,
              let pending = pendingNodeAltitude,
              pending.nodeId == nodeId
        else { return point.altitude }
        return pending.altitude
    }

    private var displayPoints: [(distance: Double, altitude: Double)] {
        points.map {
            (distance: $0.distanceFromStart, altitude: effectiveAlt(for: $0))
        }
    }

    // MARK: - Coordinate mapping

    private struct Mapping {
        let minAlt: Double
        let altRange: Double
        let maxDist: Double
        let size: CGSize

        func screen(d: Double, a: Double) -> CGPoint {
            CGPoint(
                x: CGFloat(d / maxDist) * size.width,
                y: size.height - CGFloat((a - minAlt) / altRange) * size.height
            )
        }

        func altitude(fromY y: CGFloat) -> Double {
            minAlt + Double((size.height - y) / size.height) * altRange
        }
    }

    private func makeMapping(for size: CGSize) -> Mapping {
        let pts  = displayPoints
        let alts = pts.map(\.altitude)
        let lo   = (alts.min() ?? 0) - 30
        let hi   = (alts.max() ?? 0) + 30
        let maxDist = max(pts.last?.distance ?? 0.001, 0.001)
        return Mapping(
            minAlt: lo,
            altRange: max(hi - lo, 1),
            maxDist: maxDist,
            size: size
        )
    }

    // MARK: - Canvas

    private func profileCanvas(mapping: Mapping) -> some View {
        let dpts = displayPoints
        return Canvas { ctx, _ in
            guard dpts.count >= 2 else { return }
            var line = Path()
            line.move(to: mapping.screen(d: dpts[0].distance, a: dpts[0].altitude))
            for pt in dpts.dropFirst() {
                line.addLine(to: mapping.screen(d: pt.distance, a: pt.altitude))
            }
            ctx.stroke(line, with: .color(.accentColor), lineWidth: 2)
            var fill = line
            // JUSTIFY: .last! safe — guarded by count >= 2 above
            fill.addLine(to: mapping.screen(d: dpts.last!.distance, a: mapping.minAlt))
            fill.addLine(to: mapping.screen(d: dpts[0].distance,    a: mapping.minAlt))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(.accentColor.opacity(0.12)))
        }
    }

    // MARK: - Handles layer

    private func handlesLayer(mapping: Mapping) -> some View {
        ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                pointHandle(point: point, index: i, mapping: mapping)
            }
        }
    }

    @ViewBuilder
    private func pointHandle(
        point: LineProfilePoint,
        index: Int,
        mapping: Mapping
    ) -> some View {
        let alt = effectiveAlt(for: point)
        let pos = mapping.screen(d: point.distanceFromStart, a: alt)
        switch point.source {
        case .node(let nodeId):
            nodeHandle(nodeId: nodeId, pos: pos,
                       isEndpoint: point.isEndpoint,
                       isFirst: index == 0,
                       mapping: mapping)
        case .controlPoint(let edgeId, let cpIndex):
            controlHandle(edgeId: edgeId, cpIndex: cpIndex,
                          pos: pos, mapping: mapping)
        }
    }

    // MARK: - Node handle

    @ViewBuilder
    private func nodeHandle(
        nodeId: String,
        pos: CGPoint,
        isEndpoint: Bool,
        isFirst: Bool,
        mapping: Mapping
    ) -> some View {
        if isEndpoint {
            Circle()
                .fill(isFirst ? Color.green : Color.red)
                .frame(width: 14, height: 14)
                .position(pos)
        } else {
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.25), radius: 3)
                .position(pos)
                .gesture(nodeDragGesture(nodeId: nodeId, mapping: mapping))
        }
    }

    private func nodeDragGesture(
        nodeId: String,
        mapping: Mapping
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !dragActive {
                    dragActive = true
                    onBeginEdit()
                }
                onNodeDragChanged(nodeId, mapping.altitude(fromY: value.location.y))
            }
            .onEnded { value in
                dragActive = false
                onEndNodeDrag(nodeId, mapping.altitude(fromY: value.location.y))
            }
    }

    // MARK: - Control point handle

    private func controlHandle(
        edgeId: String,
        cpIndex: Int,
        pos: CGPoint,
        mapping: Mapping
    ) -> some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.25), radius: 3)
            .position(pos)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragActive {
                            dragActive = true
                            onBeginEdit()
                        }
                        let alt = mapping.altitude(fromY: value.location.y)
                        onChangeControlPoint(edgeId, cpIndex, alt)
                    }
                    .onEnded { _ in dragActive = false }
            )
    }
}
