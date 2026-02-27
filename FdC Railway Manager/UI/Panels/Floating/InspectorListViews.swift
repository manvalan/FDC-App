import SwiftUI

struct InspectorListViews: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @Binding var isListEditMode: EditMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch appState.sidebarSelection {
            case .stations:
                stationsList
            case .tracks:
                tracksList
            case .lines:
                linesList
            case .vehicles:
                RollingStockView(manager: linesManager)
            case .io:
                IOPanelView()
            default:
                EmptyView()
            }
        }
    }
    
    // Abstracting lists into sub-components would be even better, 
    // but for now keeping them here for clarity of migration.
    
    private var stationsList: some View {
        let sortedNodes = appState.railroad.network.sortedNodes
        return List {
            ForEach(sortedNodes) { node in
                StationRowContent(node: node)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.selectedNodeId = node.id }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    appState.railroad.network.removeNode(sortedNodes[index].id)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $isListEditMode)
    }
    
    private var tracksList: some View {
        let sortedEdges = appState.railroad.network.sortedEdges
        return List {
            ForEach(sortedEdges) { edge in
                TrackRowContent(edge: edge, network: appState.railroad.network)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.selectedEdgeId = edge.id.uuidString }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    appState.railroad.network.removeEdge(sortedEdges[index].id)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $isListEditMode)
    }
    
    private var linesList: some View {
        let sortedRoutes = linesManager.routes // Simplified sorting for brevity
        return List {
            ForEach(sortedRoutes) { route in
                LineRowContent(line: route)
                    .onTapGesture { appState.selectedRouteId = route.id }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    linesManager.routes.remove(at: index)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $isListEditMode)
    }
}

struct IOPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var ioTab: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $ioTab) {
                Text("Esportazione").tag(0)
                Text("Importazione").tag(1)
            }
            .pickerStyle(.segmented).padding()
            
            if ioTab == 0 {
                Button("Esporta JSON") { /* Logic */ }.buttonStyle(.borderedProminent)
            } else {
                Text("Logica Importazione...")
            }
            Spacer()
        }
    }
}
