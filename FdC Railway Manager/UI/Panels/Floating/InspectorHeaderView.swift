import SwiftUI

struct InspectorHeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            titleSection
            Spacer()
            backButton
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            if appState.isCreatingLine {
                Text("Crea Nuova Linea")
            } else if appState.isCreatingTrack {
                Text("Nuovo Binario")
            } else if appState.isScheduleGeneratorVisible {
                Text("Genera Orari")
            } else if appState.isVehicleManagementVisible {
                Text("Gestione Flotta")
            } else if let line = appState.selectedLine {
                Text(line.name)
            } else if let node = appState.selectedNode {
                Text(node.name)
            } else {
                defaultTitle
            }
        }
        .font(.subheadline.bold())
        .foregroundColor(appState.theme.dark)
    }
    
    @ViewBuilder
    private var defaultTitle: some View {
        switch appState.sidebarSelection {
        case .lines: Text("Linee Commerciali")
        case .stations: Text("Infrastruttura: Stazioni")
        case .tracks: Text("Infrastruttura: Binari")
        default: Text("Ispettore")
        }
    }
    
    private var backButton: some View {
        Group {
            if shouldShowBackButton {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3)
                        .foregroundColor(appState.theme.medium)
                }
            }
        }
    }
    
    private var closeButton: some View {
        Button(action: { appState.showPanel(.none) }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(appState.theme.medium)
        }
    }
    
    private var shouldShowBackButton: Bool {
        appState.isSomethingSelected || appState.isScheduleGeneratorVisible || 
        appState.isVehicleManagementVisible || appState.isCreatingTrack || appState.isCreatingLine
    }
    
    private func handleBack() {
        withAnimation {
            if appState.isCreatingLine {
                appState.isCreatingLine = false
                appState.lineDraftStations.removeAll()
                appState.stationPickingCallback = nil
            } else if appState.isCreatingTrack {
                appState.isCreatingTrack = false
            } else if appState.isScheduleGeneratorVisible {
                appState.isScheduleGeneratorVisible = false
            } else if appState.isVehicleManagementVisible {
                appState.isVehicleManagementVisible = false
            } else if !appState.selectedTrainIds.isEmpty {
                appState.selectedTrainIds = []
            } else if appState.selectedNodeId != nil {
                appState.selectedNodeId = nil
            } else if appState.selectedEdgeId != nil {
                appState.selectedEdgeId = nil
            } else if appState.selectedRouteId != nil {
                appState.selectedRouteId = nil
            }
        }
    }
}
