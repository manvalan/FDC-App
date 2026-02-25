import SwiftUI

extension ContentView {
    @ViewBuilder
    var sidebarContent: some View {
        NavigationStack {
            if let selection = appState.sidebarSelection {
                sidebarSelectionContent(for: selection)
            } else {
                sidebarEmptyState
            }
        }
    }

    @ViewBuilder
    private func sidebarSelectionContent(for selection: AppState.SidebarCategory) -> some View {
        if selection.isNetworkCategory {
            networkSidebarContent(for: selection)
        } else {
            operationalSidebarContent(for: selection)
        }
    }

    @ViewBuilder
    private func networkSidebarContent(for selection: AppState.SidebarCategory) -> some View {
        switch selection {
        case .stations, .tracks, .ferrovie:
            networkListView(for: selection)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func operationalSidebarContent(for selection: AppState.SidebarCategory) -> some View {
        switch selection {
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
            RailwayAIView(network: network, railroadService: railroadService)
        case .simulation:
            LiveSimulationDashboard()
        case .settings:
            SettingsView(showGrid: $appState.showGrid)
        case .timetable:
            sidebarInfoText("Seleziona una stazione per vedere la tabella oraria")
        case .diagram:
            sidebarInfoText("Seleziona una linea per vedere il diagramma verticale")
        case .io:
            EmptyView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func networkListView(for selection: AppState.SidebarCategory) -> some View {
        let mode: NetworkListView.ListMode = {
            switch selection {
            case .stations: return .stations
            case .tracks: return .tracks
            case .ferrovie: return .ferrovie
            default: return .stations
            }
        }()
        
        NetworkListView(
            network: network,
            selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }),
            selectedEdgeId: $appState.selectedEdgeId,
            initialMode: mode
        )
    }

    @ViewBuilder
    private var sidebarEmptyState: some View {
        Text("select_category".localized)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sidebarInfoText(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
