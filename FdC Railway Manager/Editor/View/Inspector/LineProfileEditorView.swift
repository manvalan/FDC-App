import SwiftUI

/// Inline altimetric profile editor for a RailwayLine.
///
/// Embeds a `LineAltitudeChart` with full drag interaction:
/// - Intermediate node handles (blue) show an Alert on finger-up
///   before writing the model, allowing the user to confirm or cancel.
/// - TrackControlPoint handles (orange) write the model immediately
///   on each drag sample; the checkpoint is created at drag start.
///
/// Rebuild is triggered both on `.onAppear` and whenever
/// `network.edges` changes (syncPairedControlPoints propagates
/// control-point changes through `edges.didSet`).
struct LineProfileEditorView: View {

    let line: RailwayLine
    @EnvironmentObject var appState: AppState

    @State private var profile: [LineProfilePoint] = []
    @State private var pendingNodeAltitude: (nodeId: String, altitude: Double)?
    @State private var isShowingNodeAlert = false
    @State private var pendingNodeName = ""
    @State private var pendingConnectedCount = 0

    var body: some View {
        chartOrPlaceholder
            .onAppear { rebuildProfile() }
            .onChange(of: appState.railroad.network.edges) { _, _ in
                rebuildProfile()
            }
            .alert("Modifica quota stazione",
                   isPresented: $isShowingNodeAlert) {
                Button("Modifica") { commitNodeAltitude() }
                Button("Annulla", role: .cancel) { cancelNodeAltitude() }
            } message: {
                Text("Stai modificando \(pendingNodeName). " +
                     "Questa stazione è collegata a " +
                     "\(pendingConnectedCount) binari. " +
                     "La modifica si applica a tutti.")
            }
    }

    // MARK: - Chart or placeholder

    @ViewBuilder
    private var chartOrPlaceholder: some View {
        if profile.count >= 2 {
            LineAltitudeChart(
                points: profile,
                pendingNodeAltitude: pendingNodeAltitude,
                onBeginEdit: {
                    appState.railroad.network.createCheckpoint()
                },
                onNodeDragChanged: { nodeId, alt in
                    pendingNodeAltitude = (nodeId, alt)
                },
                onEndNodeDrag: handleNodeDragEnd,
                onChangeControlPoint: handleControlPointChange
            )
        } else {
            Text("Aggiungi almeno due stazioni con quota " +
                 "per visualizzare il profilo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Callbacks

    private func handleNodeDragEnd(nodeId: String, altitude: Double) {
        guard let pt = profile.first(where: { point in
            if case .node(let id) = point.source { return id == nodeId }
            return false
        }) else { return }
        pendingNodeAltitude   = (nodeId, altitude)
        pendingNodeName       = pt.stationName ?? nodeId
        pendingConnectedCount = pt.connectedEdgesCount
        isShowingNodeAlert    = true
    }

    private func handleControlPointChange(
        edgeId: String, index: Int, altitude: Double
    ) {
        appState.railroad.network.updateControlPoint(
            edgeId: edgeId, index: index, altitude: altitude
        )
    }

    // MARK: - Alert actions

    private func commitNodeAltitude() {
        guard let pending = pendingNodeAltitude else { return }
        appState.railroad.network.updateNode(
            pending.nodeId, alt: pending.altitude
        )
        pendingNodeAltitude = nil
        isShowingNodeAlert  = false
        rebuildProfile()
    }

    private func cancelNodeAltitude() {
        pendingNodeAltitude = nil
        isShowingNodeAlert  = false
        appState.railroad.discardLastCheckpoint()
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
