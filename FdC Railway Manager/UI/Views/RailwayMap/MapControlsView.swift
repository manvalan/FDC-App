import SwiftUI
import Combine
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct MapControlsView: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    
    @Binding var isEditToolbarVisible: Bool
    @Binding var editMode: MapEditMode
    @Binding var zoomLevel: CGFloat
    
    var onExport: (RailwayMapView.ExportFormat) -> Void
    var onPrint: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 20) {
            
            // Edit Mode Toggle (Always Visible)
            Button(action: {
                withAnimation {
                    isEditToolbarVisible.toggle()
                    if !isEditToolbarVisible {
                        editMode = .explore
                    }
                }
            }) {
                RailwayInteractionIcon(
                    systemName: isEditToolbarVisible ? "pencil.circle.fill" : "pencil.circle",
                    isActive: isEditToolbarVisible,
                    activeColor: .blue
                )
            }
            .help(isEditToolbarVisible ? "Nascondi Strumenti" : "Mostra Strumenti Modifica")
            .buttonStyle(.plain)
            
            // Top: Edit Tools (Only visible when toggled)
            if isEditToolbarVisible {
                VStack(spacing: 8) {
                    Button(action: {
                        editMode = .addStation
                    }) {
                        RailwayInteractionIcon(systemName: "building.2.fill", isActive: editMode == .addStation, activeColor: .green)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        editMode = .addTrack
                        appState.isCreatingTrack = true
                        appState.showPanel(.inspector)
                    }) {
                        RailwayInteractionIcon(systemName: "point.topleft.down.curvedto.point.bottomright.up", isActive: editMode == .addTrack, activeColor: .orange)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().background(Color.white.opacity(0.3)).frame(width: 30)
                    
                    // Undo/Redo Integrated
                    Button(action: { network.undo() }) {
                        RailwayInteractionIcon(systemName: "arrow.uturn.backward.circle", isActive: false, color: network.canUndo ? .primary : .secondary)
                    }
                    .disabled(!network.canUndo)
                    .help("undo".localized)
                    
                    Button(action: { network.redo() }) {
                        RailwayInteractionIcon(systemName: "arrow.uturn.forward.circle", isActive: false, color: network.canRedo ? .primary : .secondary)
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
                    RailwayInteractionIcon(systemName: "photo", isActive: false, color: .primary)
                }
                .help("Esporta JPG")
                
                Button(action: { onExport(.pdf) }) {
                    RailwayInteractionIcon(systemName: "doc.text", isActive: false, color: .primary)
                }
                .help("Esporta PDF")
                
                Button(action: { onPrint() }) {
                    RailwayInteractionIcon(systemName: "printer", isActive: false, color: .primary)
                }
                .help("print".localized)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 4)

            // Bottom: Zoom Tools
            VStack(spacing: 8) {
                Button(action: { withAnimation { zoomLevel = min(zoomLevel + 0.5, 5.0) } }) {
                    RailwayInteractionIcon(systemName: "plus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = max(zoomLevel - 0.5, 1.0) } }) {
                    RailwayInteractionIcon(systemName: "minus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = 1.0 } }) {
                    RailwayInteractionIcon(systemName: "arrow.down.left.and.arrow.up.right", isActive: false, color: .purple)
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
