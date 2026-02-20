import SwiftUI

extension ContentView {
    @ViewBuilder
    var detailContent: some View {
        ZStack {
            if appState.currentMode == .design {
                EditorModeView()
            } else {
                switch appState.sidebarSelection {
                case .stations, .tracks, .lines, .trains, .vehicles, .none:
                    RailwayMapView(
                        selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }),
                        selectedLine: Binding(get: { appState.selectedLine }, set: { appState.selectedLineId = $0?.id }),
                        selectedEdgeId: $appState.selectedEdgeId,
                        showGrid: $appState.showGrid,
                        isMoveModeEnabled: $appState.isMoveModeEnabled,
                        highlightedConflictLocation: $highlightedConflictLocation,
                        mode: $appState.mapVisualizationMode
                    )
                    .ignoresSafeArea()
                case .timetable:
                     if let node = appState.selectedNode {
                         StationScheduleView(station: node)
                             .environmentObject(lines)
                     } else {
                         VStack {
                             Image(systemName: "building.2.crop.circle")
                                 .font(.system(size: 50))
                                 .foregroundColor(.gray)
                             Text("Seleziona una stazione per visualizzare l'orario")
                                 .font(.headline)
                                 .foregroundColor(.secondary)
                         }
                     }
                case .diagram:
                    if let line = appState.selectedLine,
                       let index = lines.lines.firstIndex(where: { $0.id == line.id }) {
                         LineScheduleView(line: lines.lines[index])
                    } else {
                         VStack {
                             Image(systemName: "chart.xyaxis.line")
                                 .font(.system(size: 50))
                                 .foregroundColor(.gray)
                             Text("Seleziona una linea per visualizzare il grafico spazio-tempo")
                                 .font(.headline)
                                 .foregroundColor(.secondary)
                         }
                    }

                case .ai:
                    RailwayAIView(
                        network: network,
                        railroadService: railroadService
                    )
                case .io:
                    EmptyView()
                case .settings:
                    SettingsView(showGrid: $appState.showGrid)
                case .simulation:
                    SimulationControlView(liveSim: appState.liveSim)
                default:
                    Text("Sezione non trovata")
                }
            }
        }
    }
    
    var isSomethingSelected: Bool {
        appState.isSomethingSelected
    }
}

