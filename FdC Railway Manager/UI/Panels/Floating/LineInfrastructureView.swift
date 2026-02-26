import SwiftUI
import UIKit

struct LineInfrastructureView: View {
    let line: TrainRoute
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Line properties editor (always visible in infrastructure mode)
                LinePropertyEditor(line: line)
                
                // Track Diagram
                VerticalTrackDiagramView(
                    line: Binding(
                        get: { appState.selectedLine ?? line },
                        set: { newLine in
                            if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                                linesManager.routes[idx] = newLine
                            }
                        }
                    ),
                    network: appState.railroad.network,
                    isMoveModeEnabled: .constant(false),
                    externalSelectedStationID: $appState.selectedNodeId,
                    externalSelectedEdgeID: $appState.selectedEdgeId,
                    isSidebarEditMode: $appState.isLineEditing
                )
            }
            .padding(.vertical, 16)
        }
    }
}
