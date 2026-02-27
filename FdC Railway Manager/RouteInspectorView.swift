import SwiftUI

struct RouteInspectorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var lines: LinesManager
    
    let route: TrainRoute
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Line properties editor at the top
                VStack(alignment: .leading, spacing: 12) {
                    Text("PROPRIETÀ LINEA")
                        .font(.caption.bold())
                    
                    TextField("Nome Linea", text: Binding(
                        get: { route.name },
                        set: { newName in
                            if let idx = lines.routes.firstIndex(where: { $0.id == route.id }) {
                                lines.routes[idx].name = newName
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        TextField("Prefisso", text: Binding(
                            get: { route.serviceCodePrefix ?? "" },
                            set: { newValue in
                                if let idx = lines.routes.firstIndex(where: { $0.id == route.id }) {
                                    lines.routes[idx].serviceCodePrefix = newValue.isEmpty ? nil : newValue
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        TextField("Numero", value: Binding(
                            get: { route.numberPrefix ?? 0 },
                            set: { newValue in
                                if let idx = lines.routes.firstIndex(where: { $0.id == route.id }) {
                                    lines.routes[idx].numberPrefix = newValue
                                }
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
                .background(appState.theme.backgroundSecondary)
                .cornerRadius(12)
                
                Divider()
                    .background(appState.theme.line.opacity(0.1))
                
                switch appState.lineInspectorMode {
                case .infrastructure:
                    VerticalTrackDiagramView(
                        line: Binding(
                            get: { appState.selectedRoute ?? route },
                            set: { newRoute in
                                if let idx = lines.routes.firstIndex(where: { $0.id == route.id }) {
                                    lines.routes[idx] = newRoute
                                }
                            }
                        ),
                        network: network,
                        externalSelectedStationID: $appState.selectedNodeId,
                        externalSelectedEdgeID: $appState.selectedEdgeId,
                        isSidebarEditMode: $appState.isLineEditing
                    )
                case .schedule:
                    LineScheduleSummaryView(line: route)
                case .vehicles:
                    LineVehiclesView(lineId: route.id)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
