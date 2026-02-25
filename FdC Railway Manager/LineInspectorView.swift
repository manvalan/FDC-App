import SwiftUI

struct LineInspectorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var lines: LinesManager
    
    let line: RailwayLine
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Line properties editor at the top
                VStack(alignment: .leading, spacing: 12) {
                    Text("PROPRIETÀ LINEA")
                        .font(.caption.bold())
                    
                    TextField("Nome Linea", text: Binding(
                        get: { line.name },
                        set: { newName in
                            if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                                lines.lines[idx].name = newName
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        TextField("Prefisso", text: Binding(
                            get: { line.codePrefix ?? "" },
                            set: { newValue in
                                if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                                    lines.lines[idx].codePrefix = newValue.isEmpty ? nil : newValue
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        TextField("Numero", value: Binding(
                            get: { line.numberPrefix ?? 0 },
                            set: { newValue in
                                if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                                    lines.lines[idx].numberPrefix = newValue
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
                            get: { appState.selectedLine ?? line },
                            set: { newLine in
                                if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                                    lines.lines[idx] = newLine
                                }
                            }
                        ),
                        network: network,
                        isMoveModeEnabled: .constant(false),
                        externalSelectedStationID: $appState.selectedNodeId,
                        externalSelectedEdgeID: $appState.selectedEdgeId,
                        isSidebarEditMode: $appState.isLineEditing
                    )
                case .schedule:
                    LineScheduleSummaryView(line: line)
                case .vehicles:
                    LineVehiclesView(lineId: line.id)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
