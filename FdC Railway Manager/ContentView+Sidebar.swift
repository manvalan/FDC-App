import SwiftUI

extension ContentView {
    @ViewBuilder
    var sidebarContent: some View {
        if let selection = appState.sidebarSelection {
            switch selection {
            case .network:
                NetworkListView(
                    network: network,
                    selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }),
                    selectedEdgeId: $appState.selectedEdgeId
                )
            case .lines:
                LinesListView(
                    network: network,
                    lines: lines,
                    selectedLine: Binding(get: { appState.selectedLine }, set: { appState.selectedLineId = $0?.id })
                )
            case .trains:
                TrainsListView(selectedTrains: $appState.selectedTrainIds)
            case .vehicles:
                RollingStockView(manager: lines)
            case .ai:
                RailwayAIView(
                    network: network,
                    backgroundGA: backgroundGA,
                    isOptimizingInBackground: $isOptimizingInBackground,
                    backgroundOptimizationTask: $backgroundOptimizationTask,
                    showOptimizationResultAlert: $showOptimizationResultAlert,
                    pendingOptimizedTrains: $pendingOptimizedTrains,
                    optimizationConflictDelta: $optimizationConflictDelta
                )
            case .io:
                IOManagementView()
            case .simulation:
                LiveSimulationDashboard()
            case .settings:
                SettingsView(showGrid: $showGrid)
            }
        } else {
            Text("select_category".localized)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
