import SwiftUI

extension ContentView {
    @ViewBuilder
    var detailContent: some View {
        RailwayMapView(
            selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }),
            selectedLine: Binding(get: { appState.selectedLine }, set: { appState.selectedLineId = $0?.id }),
            selectedEdgeId: $appState.selectedEdgeId,
            showGrid: $showGrid,
            isMoveModeEnabled: $isMoveModeEnabled,
            highlightedConflictLocation: $highlightedConflictLocation,
            mode: (appState.sidebarSelection == .lines || appState.sidebarSelection == .trains || appState.sidebarSelection == .io) ? .lines : .network
        )
    }
    
    var isSomethingSelected: Bool {
        appState.selectedLineId != nil || appState.selectedNodeId != nil || appState.selectedEdgeId != nil || !appState.selectedTrainIds.isEmpty
    }
}
