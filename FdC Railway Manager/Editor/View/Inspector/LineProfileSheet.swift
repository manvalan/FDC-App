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

    // 3a placeholder — replaced in 3b with actual canvases
    private func scrollableCanvas(mapping: ProfileMapping) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Color(.systemGray5)
                .frame(width: canvasWidth, height: canvasHeight)
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
        let alts = profile.map(\.altitude)
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
