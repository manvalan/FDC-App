import SwiftUI

struct ServicesToolboxView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            Group {
                toolIcon(icon: "paintbrush.fill", help: "Pennello Percorso", active: appState.mapEditMode == .brushPath) {
                    withAnimation {
                        if appState.mapEditMode == .brushPath {
                            appState.mapEditMode = .explore
                        } else {
                            appState.mapEditMode = .brushPath
                            appState.isEraserActive = false
                        }
                    }
                }
                
                toolIcon(icon: "eraser.fill", help: "Gomma Percorso", active: appState.mapEditMode == .erasePath) {
                    withAnimation {
                        if appState.mapEditMode == .erasePath {
                            appState.mapEditMode = .explore
                        } else {
                            appState.mapEditMode = .erasePath
                            appState.isEraserActive = true
                        }
                    }
                }
                
                Divider().frame(width: 30)
                
                toolIcon(
                    icon: "plus", 
                    help: "Crea Linea", 
                    active: false, 
                    disabled: appState.selectedNodeIds.count < 2
                ) {
                    createNewRailwayLine()
                }
                
                if !appState.selectedNodeIds.isEmpty {
                    toolIcon(icon: "trash", help: "Svuota Selezione", isDestructive: true) {
                        withAnimation {
                            appState.selectedNodeIds.removeAll()
                            appState.selectedNodeIdsOrder.removeAll()
                            appState.brushStrokePoints.removeAll()
                        }
                    }
                }
                
                Divider().frame(width: 30)
                
                toolIcon(icon: "chart.xyaxis.line", help: "Altimetria", active: appState.isProfileViewVisible) {
                    withAnimation {
                        appState.isProfileViewVisible.toggle()
                    }
                }
                
                toolIcon(icon: "list.bullet", help: "Elenco Linee", active: appState.sidebarSelection == .infraLines && appState.isInspectorVisible) {
                    withAnimation {
                        if appState.sidebarSelection == .infraLines && appState.isInspectorVisible {
                            appState.showPanel(.none)
                        } else {
                            appState.sidebarSelection = .infraLines
                            appState.showPanel(.inspector)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 15, y: 5)
    }
    
    private func createNewRailwayLine() {
        let count = appState.railroad.network.lines.count + 1
        // Use the ordered selection
        let nodeIds = appState.selectedNodeIdsOrder
        
        guard nodeIds.count >= 2 else { return }
        
        appState.railroad.network.createCheckpoint()
        
        let newLine = RailwayLine(
            name: "Nuova Linea \(count)",
            color: ["#3498db", "#e74c3c", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c"][count % 6],
            nodeIds: nodeIds
        )
        
        withAnimation {
            appState.railroad.network.lines.append(newLine)
            appState.selectedInfraLineId = newLine.id
            
            // Clear brush selection after success
            appState.clearSelection()
            
            appState.showPanel(.inspector)
        }
    }
    
    private func toolIcon(icon: String, help: String, active: Bool = false, isDestructive: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .frame(width: 44, height: 44)
                .background(active ? Color.orange : (isDestructive ? Color.red.opacity(0.1) : Color.white.opacity(0.1)))
                .foregroundColor(active ? .white : (isDestructive ? .red : (disabled ? .secondary.opacity(0.3) : .primary)))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }
}
