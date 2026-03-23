import SwiftUI

/// Altimetric profile chart with draggable control-point handles.
///
/// Endpoint altitudes (from/to node) are shown as fixed green/red
/// anchors. Intermediate `TrackControlPoint`s appear as orange
/// draggable handles; dragging changes only the altitude.
/// `onBeginEdit` is called once at the start of each drag (for undo).
struct InteractiveAltitudeChart: View {
    @Binding var controlPoints: [TrackControlPoint]
    let fromAltitude: Double
    let toAltitude: Double
    let totalDistance: Double
    var onBeginEdit: () -> Void

    @State private var dragActive = false

    var body: some View {
        GeometryReader { geo in
            let mapping = makeMapping(for: geo.size)
            ZStack(alignment: .topLeading) {
                backgroundCanvas(mapping: mapping)
                    .frame(width: geo.size.width, height: geo.size.height)
                endpointDots(mapping: mapping)
                controlHandles(mapping: mapping)
            }
        }
    }

    // MARK: - Data

    var allProfilePoints: [(distance: Double, altitude: Double)] {
        let total = max(totalDistance, 0.001)
        let count = controlPoints.count
        var pts: [(Double, Double)] = [(0, fromAltitude)]
        for (i, cp) in controlPoints.enumerated() {
            let t   = Double(i + 1) / Double(count + 1)
            let alt = cp.altitude ?? (fromAltitude + (toAltitude - fromAltitude) * t)
            pts.append((t * total, alt))
        }
        pts.append((total, toAltitude))
        return pts
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
        let pts  = allProfilePoints
        let alts = pts.map(\.altitude)
        let lo   = (alts.min() ?? 0) - 30
        let hi   = (alts.max() ?? 0) + 30
        let maxDist = max(pts.last?.distance ?? 0.001, 0.001)
        return Mapping(minAlt: lo, altRange: max(hi - lo, 1),
                       maxDist: maxDist, size: size)
    }

    // MARK: - Sub-views

    private func backgroundCanvas(mapping: Mapping) -> some View {
        let pts = allProfilePoints
        return Canvas { ctx, size in
            guard pts.count >= 2 else { return }
            var line = Path()
            line.move(to: mapping.screen(d: pts[0].distance, a: pts[0].altitude))
            for pt in pts.dropFirst() {
                line.addLine(to: mapping.screen(d: pt.distance, a: pt.altitude))
            }
            ctx.stroke(line, with: .color(.accentColor), lineWidth: 2)
            var fill = line
            // JUSTIFY: pts.last! safe — guarded by count >= 2 above
            fill.addLine(to: mapping.screen(d: pts.last!.distance, a: mapping.minAlt))
            fill.addLine(to: mapping.screen(d: pts[0].distance,    a: mapping.minAlt))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(.accentColor.opacity(0.12)))
        }
    }

    private func endpointDots(mapping: Mapping) -> some View {
        let pts = allProfilePoints
        return ZStack {
            Circle().fill(Color.green).frame(width: 10, height: 10)
                .position(mapping.screen(d: 0, a: fromAltitude))
            Circle().fill(Color.red).frame(width: 10, height: 10)
                .position(
                    mapping.screen(d: pts.last?.distance ?? 0, a: toAltitude)
                )
        }
    }

    private func controlHandles(mapping: Mapping) -> some View {
        let pts = allProfilePoints
        return ForEach(
            Array(controlPoints.enumerated()), id: \.element.id
        ) { index, _ in
            let pt = pts[index + 1]  // +1: pts[0] is the from-endpoint
            Circle()
                .fill(Color.orange)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.25), radius: 3)
                .position(mapping.screen(d: pt.distance, a: pt.altitude))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !dragActive {
                                dragActive = true
                                onBeginEdit()
                            }
                            controlPoints[index].altitude =
                                mapping.altitude(fromY: value.location.y)
                        }
                        .onEnded { _ in dragActive = false }
                )
        }
    }
}
