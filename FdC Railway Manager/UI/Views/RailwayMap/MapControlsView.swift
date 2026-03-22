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
    
    var onExport: (AppExportFormat) -> Void
    var onPrint: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 20) {
            
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
            .buttonStyle(.plain)

            // Bottom: Zoom Tools
            VStack(spacing: 8) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { appState.mapZoomLevel = min(appState.mapZoomLevel * 1.2, 8.0) } }) {
                    RailwayInteractionIcon(systemName: "plus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { appState.mapZoomLevel = max(appState.mapZoomLevel / 1.2, 0.2) } }) {
                    RailwayInteractionIcon(systemName: "minus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { appState.mapZoomLevel = 1.0 } }) {
                    RailwayInteractionIcon(systemName: "arrow.down.left.and.arrow.up.right", isActive: false, color: .primary)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 4)
            .buttonStyle(.plain)
        }
        .padding()
    }
}
