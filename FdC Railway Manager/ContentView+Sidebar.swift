import SwiftUI

extension ContentView {
    @ViewBuilder
    var sidebarContent: some View {
        if let selection = appState.sidebarSelection {
            switch selection {
            case .stations:
                NetworkListView(
                    network: network,
                    selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }),
                    selectedEdgeId: $appState.selectedEdgeId
                )
            case .tracks:
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
                    railroadService: railroadService
                )
            case .io:
                IOManagementView()
            case .simulation:
                LiveSimulationDashboard()
            case .settings:
                SettingsView(showGrid: $appState.showGrid)
            case .timetable:
                Text("Seleziona una stazione per vedere la tabella oraria")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .diagram:
                Text("Seleziona una linea per vedere il diagramma verticale")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            Text("select_category".localized)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
