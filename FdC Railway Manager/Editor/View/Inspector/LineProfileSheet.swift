import SwiftUI

/// Full-screen sheet for editing a RailwayLine's altimetric profile.
///
/// Presented at 75 % screen height from FerroviaInspectorView.
/// Y-axis labels (altitude) are fixed on the left; the profile canvas
/// scrolls horizontally. Build sequence:
///   3a — layout shell (this)      3b — grid + slope zones + curve
///   3c — zoom + viewport Y        3d — draggable handles + undo/alert
///   3e — station name labels      3f — FerroviaInspectorView integration
struct LineProfileSheet: View {

    let line: RailwayLine
    @EnvironmentObject var appState: AppState

    // MARK: - Layout constants

    private let canvasHeight: CGFloat = 280   // adjust after visual test
    private let yAxisWidth:   CGFloat = 44

    // MARK: - State

    @State private var profile: [LineProfilePoint] = []
    @State private var zoomX: CGFloat = 1.0
    @State private var availableWidth: CGFloat = 300
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScale: CGFloat = 1.0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chartRow
                Spacer()
            }
            .navigationTitle(line.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.75)])
        .presentationDragIndicator(.visible)
        .onAppear { rebuildProfile() }
        .onChange(of: appState.railroad.network.edges) { _, _ in
            rebuildProfile()
        }
    }

    // MARK: - Chart layout

    private var chartRow: some View {
        let m = mapping
        return HStack(spacing: 0) {
            yAxisView(mapping: m)
                .frame(width: yAxisWidth, height: canvasHeight)
            scrollableCanvas(mapping: m)
        }
        .frame(height: canvasHeight)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        availableWidth = max(geo.size.width - yAxisWidth, 1)
                    }
                    .onChange(of: geo.size.width) { _, w in
                        availableWidth = max(w - yAxisWidth, 1)
                    }
            }
        )
    }

    private func scrollableCanvas(mapping: ProfileMapping) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                slopeBandsCanvas(mapping: mapping)
                gridCanvas(mapping: mapping)
                curveCanvas(mapping: mapping)
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .background(Color(.systemBackground))
            .background(scrollOffsetTracker)
        }
        .coordinateSpace(name: "profileScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
        .simultaneousGesture(pinchGesture)
    }

    private var scrollOffsetTracker: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ScrollOffsetKey.self,
                value: -geo.frame(in: .named("profileScroll")).minX
            )
        }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let delta = scale / lastScale
                lastScale = scale
                zoomX = min(max(zoomX * delta, 1.0), 8.0)
            }
            .onEnded { _ in lastScale = 1.0 }
    }

    // MARK: - Canvas layers

    /// Red background bands where abs(slope) > electrification-based limit.
    private func slopeBandsCanvas(mapping: ProfileMapping) -> some View {
        let limit = slopeLimit(for: line.electrification)
        let pts   = profile
        return Canvas { ctx, _ in
            for i in 0 ..< pts.count - 1 {
                let p1 = pts[i], p2 = pts[i + 1]
                let dDistM = (p2.distanceFromStart - p1.distanceFromStart) * 1000
                guard dDistM > 0 else { continue }
                let slope = abs((p2.altitude - p1.altitude) / dDistM * 1000)
                guard slope > limit else { continue }
                let x1 = mapping.screenX(d: p1.distanceFromStart)
                let x2 = mapping.screenX(d: p2.distanceFromStart)
                let r  = CGRect(x: x1, y: 0,
                                width: x2 - x1, height: mapping.canvasSize.height)
                ctx.fill(Path(r), with: .color(.red.opacity(0.15)))
            }
        }
    }

    /// Horizontal altitude grid lines + vertical km lines with labels.
    private func gridCanvas(mapping: ProfileMapping) -> some View {
        let altTicks = altitudeTicks(for: mapping)
        let kmTicks  = self.kmTicks(for: mapping)
        return Canvas { ctx, _ in
            for alt in altTicks {
                let y = mapping.screenY(a: Double(alt))
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: mapping.canvasSize.width, y: y))
                ctx.stroke(p, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)
            }
            for km in kmTicks {
                let x = mapping.screenX(d: km)
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: mapping.canvasSize.height))
                ctx.stroke(p, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
                let label = Text("\(Int(km))km")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondary)
                ctx.draw(label, at: CGPoint(x: x + 2, y: 4), anchor: .topLeading)
            }
        }
    }

    /// Profile line + translucent fill in the line's colour.
    private func curveCanvas(mapping: ProfileMapping) -> some View {
        let pts       = profile
        let curveColor = line.displayColor
        return Canvas { ctx, _ in
            guard pts.count >= 2 else { return }
            var path = Path()
            path.move(to: mapping.screen(d: pts[0].distanceFromStart,
                                          a: pts[0].altitude))
            for pt in pts.dropFirst() {
                path.addLine(to: mapping.screen(d: pt.distanceFromStart,
                                                 a: pt.altitude))
            }
            ctx.stroke(path, with: .color(curveColor), lineWidth: 2)
            var fill = path
            // JUSTIFY: .last! safe — guarded by count >= 2 above
            fill.addLine(to: mapping.screen(d: pts.last!.distanceFromStart,
                                             a: mapping.minAlt))
            fill.addLine(to: mapping.screen(d: pts[0].distanceFromStart,
                                             a: mapping.minAlt))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(curveColor.opacity(0.12)))
        }
    }

    // MARK: - Grid helpers

    private func kmTicks(for mapping: ProfileMapping) -> [Double] {
        let step: Double
        switch zoomX {
        case ..<1.5: step = 50
        case ..<3.0: step = 20
        case ..<6.0: step = 10
        default:     step = 5
        }
        let count = Int(mapping.totalDist / step) + 1
        return (0...count).map { Double($0) * step }
            .filter { $0 <= mapping.totalDist }
    }

    // MARK: - Slope limit (Opzione B — derived from electrification)

    private func slopeLimit(for e: ElectrificationType) -> Double {
        switch e {
        case .dc950v: return 35.0   // tramvie / FdC
        case .dc3kv:  return 25.0   // rete ordinaria
        case .ac25kv: return 20.0   // alta velocità
        case .none:   return 30.0   // non elettrificato
        }
    }

    // MARK: - Y-axis labels (fixed, not scrollable)

    private func yAxisView(mapping: ProfileMapping) -> some View {
        ZStack {
            ForEach(altitudeTicks(for: mapping), id: \.self) { alt in
                Text("\(alt)m")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .position(
                        x: yAxisWidth / 2,
                        y: mapping.screenY(a: Double(alt))
                    )
            }
        }
        .frame(width: yAxisWidth, height: canvasHeight)
        .clipped()
    }

    private func altitudeTicks(for mapping: ProfileMapping) -> [Int] {
        let lo = Int(ceil(mapping.minAlt / 100.0)) * 100
        let hi = Int(mapping.minAlt + mapping.altRange)
        return stride(from: lo, through: hi, by: 100).map { $0 }
    }

    // MARK: - Geometry

    private var totalDistanceKm: Double {
        max(profile.last?.distanceFromStart ?? 1.0, 0.001)
    }

    /// At zoomX == 1.0 the whole line fills the viewport exactly.
    private var canvasWidth: CGFloat {
        availableWidth * zoomX
    }

    private var mapping: ProfileMapping {
        makeMapping(canvasWidth: canvasWidth)
    }

    // MARK: - ProfileMapping

    struct ProfileMapping {
        let minAlt: Double
        let altRange: Double
        let totalDist: Double
        let canvasSize: CGSize

        func screenX(d: Double) -> CGFloat {
            CGFloat(d / totalDist) * canvasSize.width
        }

        func screenY(a: Double) -> CGFloat {
            canvasSize.height -
                CGFloat((a - minAlt) / altRange) * canvasSize.height
        }

        func altitude(fromY y: CGFloat) -> Double {
            minAlt + Double(
                (canvasSize.height - y) / canvasSize.height
            ) * altRange
        }

        func screen(d: Double, a: Double) -> CGPoint {
            CGPoint(x: screenX(d: d), y: screenY(a: a))
        }
    }

    private func makeMapping(canvasWidth: CGFloat) -> ProfileMapping {
        let alts = viewportAltitudes(canvasWidth: canvasWidth)
        let lo   = alts.min() ?? 0
        let hi   = alts.max() ?? 100
        let pad  = max((hi - lo) * 0.15, 10)
        return ProfileMapping(
            minAlt: lo - pad,
            altRange: max(hi - lo + 2 * pad, 1),
            totalDist: totalDistanceKm,
            canvasSize: CGSize(width: canvasWidth, height: canvasHeight)
        )
    }

    /// Returns altitudes of points currently visible in the horizontal viewport.
    /// Falls back to all points when viewport has no coverage (zoom 1 or empty).
    private func viewportAltitudes(canvasWidth: CGFloat) -> [Double] {
        guard canvasWidth > 0, !profile.isEmpty else {
            return profile.map(\.altitude)
        }
        let ratio   = Double(canvasWidth) == 0 ? 0 : totalDistanceKm / Double(canvasWidth)
        let startD  = Double(scrollOffset) * ratio
        let endD    = Double(scrollOffset + availableWidth) * ratio
        let visible = profile.filter {
            $0.distanceFromStart >= startD && $0.distanceFromStart <= endD
        }
        return visible.isEmpty ? profile.map(\.altitude) : visible.map(\.altitude)
    }

    // MARK: - Profile builder

    private func rebuildProfile() {
        let net = appState.railroad.network
        profile = LineProfilePoint.buildProfile(
            for: line,
            nodes: net.nodes,
            edges: net.edges,
            allLines: net.lines
        )
    }
}

// MARK: - PreferenceKey for scroll offset tracking

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
