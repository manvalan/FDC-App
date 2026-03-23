import SwiftUI

/// Bottom sheet: altimetric profile editor for a single track.
/// Presented from TrackInspectorView; the map remains visible above.
struct TrackProfileSheet: View {
    @Binding var edge: Edge
    @EnvironmentObject var appState: AppState

    private var fromNode: Node? { appState.railroad.network.findNode(id: edge.from) }
    private var toNode:   Node? { appState.railroad.network.findNode(id: edge.to) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    altitudeSummary
                    Divider()
                    chartSection
                    Divider()
                    controlPointsList
                }
                .padding()
            }
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { addPointButton }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sub-views

    private var altitudeSummary: some View {
        HStack(spacing: 24) {
            altitudeStat("Quota Da", value: fromNode?.altitude)
            altitudeStat("Quota A",  value: toNode?.altitude)
            altitudeStat("Pendenza", text: averageSlopeText)
        }
    }

    private func altitudeStat(_ label: String, value: Double? = nil, text: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(text ?? (value.map { "\(Int($0)) m" } ?? "— m"))
                .font(.subheadline.bold())
        }
    }

    private var chartSection: some View {
        TrackAltitudeChart(profilePoints: profilePoints)
            .frame(height: 100)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }

    private var controlPointsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Punti di controllo").font(.subheadline.bold())
            if edge.controlPoints.isEmpty {
                Text("Nessun punto intermedio — usa + per aggiungerne uno.")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            } else {
                ForEach($edge.controlPoints) { $cp in
                    TrackControlPointRow(controlPoint: $cp) {
                        appState.railroad.network.createCheckpoint()
                        edge.controlPoints.removeAll { $0.id == cp.id }
                    }
                    Divider()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var addPointButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { addMidpoint() } label: { Image(systemName: "plus") }
        }
    }

    // MARK: - Computed data

    private var sheetTitle: String {
        "\(fromNode?.name ?? "?") → \(toNode?.name ?? "?")"
    }

    private var averageSlopeText: String {
        let dAlt = (toNode?.altitude ?? 0) - (fromNode?.altitude ?? 0)
        let distM = edge.distance * 1000.0
        guard distM > 0 else { return "—" }
        return String(format: "%.1f ‰", (dAlt / distM) * 1000.0)
    }

    /// Profile points: (cumulative distance km, altitude m).
    /// Control points are distributed evenly by index (approximation).
    var profilePoints: [(distance: Double, altitude: Double)] {
        let fromAlt = fromNode?.altitude ?? 0
        let toAlt   = toNode?.altitude   ?? 0
        let total   = max(edge.distance, 0.001)
        let count   = edge.controlPoints.count

        var pts: [(Double, Double)] = [(0, fromAlt)]
        for (i, cp) in edge.controlPoints.enumerated() {
            let t   = Double(i + 1) / Double(count + 1)
            let alt = cp.altitude ?? (fromAlt + (toAlt - fromAlt) * t)
            pts.append((t * total, alt))
        }
        pts.append((total, toAlt))
        return pts
    }

    // MARK: - Actions

    private func addMidpoint() {
        guard let f = fromNode, let fromLat = f.latitude, let fromLon = f.longitude,
              let t = toNode,   let toLat   = t.latitude, let toLon   = t.longitude
        else { return }
        appState.railroad.network.createCheckpoint()
        let midAlt = ((f.altitude ?? 0) + (t.altitude ?? 0)) / 2.0
        edge.controlPoints.append(
            TrackControlPoint(latitude:  (fromLat + toLat) / 2.0,
                              longitude: (fromLon + toLon) / 2.0,
                              altitude:  midAlt)
        )
    }
}

// MARK: - TrackControlPointRow

/// One editable row for a single TrackControlPoint inside TrackProfileSheet.
private struct TrackControlPointRow: View {
    @Binding var controlPoint: TrackControlPoint
    @EnvironmentObject var appState: AppState
    var onDelete: () -> Void

    @State private var altitudeText: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "diamond.fill")
                .foregroundStyle(.orange).font(.caption2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Quota (m)").font(.caption).foregroundStyle(.secondary)
                TextField("—", text: $altitudeText)
                    .keyboardType(.decimalPad)
                    .font(.subheadline.bold())
                    .onSubmit(commitAltitude)
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash").font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .onAppear {
            altitudeText = controlPoint.altitude.map { "\(Int($0))" } ?? ""
        }
    }

    private func commitAltitude() {
        appState.railroad.network.createCheckpoint()
        controlPoint.altitude = Double(altitudeText)
    }
}
