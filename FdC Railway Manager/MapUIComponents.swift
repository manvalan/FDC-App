import SwiftUI

/// Icona interattiva per la toolbar della mappa.
struct InteractionIcon: View {
    var systemName: String
    var isActive: Bool
    var color: Color = .primary
    var activeColor: Color = .accentColor
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(isActive ? (activeColor) : color)
            .frame(width: 38, height: 38)
            .background(isActive ? activeColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Controlli flottanti della mappa (Zoom, Edit, Export).
struct MapControlsView: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    
    @Binding var isEditToolbarVisible: Bool
    @Binding var editMode: SchematicRailwayView.EditMode
    @Binding var isMoveModeEnabled: Bool
    @Binding var zoomLevel: CGFloat
    var onExport: (RailwayMapView.ExportFormat) -> Void
    var onPrint: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            // Edit Toolbar
            if isEditToolbarVisible {
                VStack(spacing: 8) {
                    ForEach(SchematicRailwayView.EditMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.spring(response: MapConstants.springResponse, dampingFraction: MapConstants.springDamping)) {
                                editMode = mode
                                if mode != .explore { isMoveModeEnabled = false }
                            }
                        }) {
                            InteractionIcon(
                                systemName: mode == .explore ? "cursorarrow" : (mode == .addTrack ? "plus.square.on.square" : "building.2.fill"),
                                isActive: editMode == mode
                            )
                        }
                        .help(mode.localizedName)
                    }
                    
                    Divider().background(Color.white.opacity(0.3)).frame(width: 30)
                    
                    Button(action: { 
                        withAnimation { 
                            isMoveModeEnabled.toggle()
                            if isMoveModeEnabled { editMode = .explore }
                        }
                    }) {
                        InteractionIcon(systemName: isMoveModeEnabled ? "hand.draw.fill" : "hand.draw", isActive: isMoveModeEnabled, activeColor: .blue)
                    }
                    .help("Sposta Stazioni")
                    
                    Divider().background(Color.white.opacity(0.3)).frame(width: 30)
                    
                    Button(action: { network.undo() }) {
                        InteractionIcon(systemName: "arrow.uturn.backward.circle", isActive: false, color: network.canUndo ? .primary : .secondary)
                    }
                    .disabled(!network.canUndo)
                    .help("undo".localized)
                    
                    Button(action: { network.redo() }) {
                        InteractionIcon(systemName: "arrow.uturn.forward.circle", isActive: false, color: network.canRedo ? .primary : .secondary)
                    }
                    .disabled(!network.canRedo)
                    .help("redo".localized)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(radius: 4)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Middle: Export Tools
            VStack(spacing: 8) {
                Button(action: { onExport(.jpeg) }) {
                    InteractionIcon(systemName: "photo", isActive: false, color: .primary)
                }
                .help("Esporta JPG")
                
                Button(action: { onExport(.pdf) }) {
                    InteractionIcon(systemName: "doc.text", isActive: false, color: .primary)
                }
                .help("Esporta PDF")
                
                Button(action: { onPrint() }) {
                    InteractionIcon(systemName: "printer", isActive: false, color: .primary)
                }
                .help("print".localized)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 4)

            // Bottom: Zoom Tools
            VStack(spacing: 8) {
                Button(action: { withAnimation { zoomLevel = min(zoomLevel + MapConstants.zoomStep, MapConstants.maxZoom) } }) {
                    InteractionIcon(systemName: "plus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = max(zoomLevel - MapConstants.zoomStep, MapConstants.minZoom) } }) {
                    InteractionIcon(systemName: "minus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = MapConstants.minZoom } }) {
                    InteractionIcon(systemName: "arrow.down.left.and.arrow.up.right", isActive: false, color: .purple)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 4)
        }
        .padding()
    }
}
