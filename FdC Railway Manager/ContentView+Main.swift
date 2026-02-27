import SwiftUI

extension ContentView {
    @ViewBuilder
    var detailContent: some View {
        ZStack {
            if appState.currentMode == .design || appState.currentMode == .editor {
                EditorModeView()
            } else {
                mainAreaContent
            }
        }
    }

    @ViewBuilder
    private var mainAreaContent: some View {
        if let selection = appState.sidebarSelection, isUtilitySelection(selection) {
            utilityArea(for: selection)
        } else {
            mapBasedArea
        }
    }

    private func isUtilitySelection(_ selection: SidebarItem) -> Bool {
        switch selection {
        case .timetable, .diagram, .ai, .settings, .simulation:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var mapBasedArea: some View {
        switch appState.sidebarSelection {
        case .timetable:
            stationTimetableView
        case .diagram:
            lineDiagramView
        default:
            mapDetailView
        }
    }

    @ViewBuilder
    private func utilityArea(for selection: SidebarItem) -> some View {
        switch selection {
        case .ai:
            RailwayAIView(network: network, railroadService: railroadService)
        case .settings:
            SettingsView(showGrid: $appState.showGrid)
        case .simulation:
            SimulationControlView(liveSim: appState.liveSim)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var mapDetailView: some View {
        RailwayMapView(
            selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }),
            selectedLine: Binding(get: { appState.selectedInfraLine }, set: { appState.selectedInfraLineId = $0?.id }),
            selectedEdgeId: $appState.selectedEdgeId,
            showGrid: $appState.showGrid,
            highlightedConflictLocation: $highlightedConflictLocation,
            mode: $appState.mapVisualizationMode
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var stationTimetableView: some View {
        if let node = appState.selectedNode {
            StationScheduleView(station: node)
                .environmentObject(lines)
        } else {
            placeholderView(image: "building.2.crop.circle", text: "Seleziona una stazione per visualizzare l'orario")
        }
    }

    @ViewBuilder
    private var lineDiagramView: some View {
        if let line = appState.selectedLine,
           let index = lines.lines.firstIndex(where: { $0.id == line.id }) {
            LineScheduleView(line: lines.lines[index])
        } else {
            placeholderView(image: "chart.xyaxis.line", text: "Seleziona una linea per visualizzare il grafico spazio-tempo")
        }
    }

    @ViewBuilder
    private func placeholderView(image: String, text: String) -> some View {
        VStack {
            Image(systemName: image)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(text)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    var isSomethingSelected: Bool {
        appState.isSomethingSelected
    }
}

