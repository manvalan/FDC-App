import SwiftUI

extension ContentView {
    @ViewBuilder
    var detailContent: some View {
        ZStack {
            switch appState.sidebarSelection {
            case .stations, .tracks, .lines, .trains, .none:
                RailwayMapView(
                    selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }),
                    selectedLine: Binding(get: { appState.selectedLine }, set: { appState.selectedLineId = $0?.id }),
                    selectedEdgeId: $appState.selectedEdgeId,
                    showGrid: $showGrid,
                    isMoveModeEnabled: $isMoveModeEnabled,
                    highlightedConflictLocation: $highlightedConflictLocation,
                    mode: appState.currentMode == .design ? .network : .lines
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
            case .settings:
                SettingsView(showGrid: $showGrid)
            case .simulation:
                SimulationControlView(liveSim: appState.liveSim)
            default:
                Text("Sezione non trovata")
            }
        }
    }
    
    var isSomethingSelected: Bool {
        appState.isSomethingSelected
    }
}
