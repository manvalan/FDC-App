import SwiftUI
import Combine
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct StationMarkersView: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String?
    let canvasSize: CGSize
    let bounds: SchematicRailwayView.MapBounds
    let showGrid: Bool
    let coordinateGridStep: Double
    @Binding var isMoveModeEnabled: Bool
    let onTap: (RailwayNode) -> Void
    
    var body: some View {
        ForEach(network.nodes) { node in
            // Safe binding creation to avoid Index out of range
            let nodeBinding = Binding<RailwayNode>(
                get: {
                    if let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        return network.nodes[index]
                    }
                    return node
                },
                set: { newNode in
                    if let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        network.nodes[index] = newNode
                    }
                }
            )
            
            StationNodeView(
                node: nodeBinding,
                canvasSize: canvasSize,
                isSelected: selectedNode?.id == node.id || appState.selectedNodeIds.contains(node.id),
                snapToGrid: showGrid,
                gridUnit: coordinateGridStep,
                bounds: bounds,
                onTap: { onTap(node) },
                isMoveModeEnabled: $isMoveModeEnabled,
                onDragStarted: { network.createCheckpoint() }
            )
            .position(MapGeometryEngine.finalPosition(for: node, in: canvasSize, bounds: bounds, network: network))
            .id("node-\(node.id)")
        }
         
    }
}
