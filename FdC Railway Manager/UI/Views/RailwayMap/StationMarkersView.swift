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
    let renderData: MapRenderData
    let canvasSize: CGSize
    let bounds: MapBounds
    let showGrid: Bool
    let coordinateGridStep: Double
    let onTap: (RailwayNode, CGPoint) -> Void
    
    var body: some View {
        ForEach(network.nodes) { node in
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
                        network.recalculateDistances(for: newNode.id)
                        // Trigger topology update to refresh Canvas links/positions
                        appState.railroad.forceUpdateTopology()
                    }
                }
            )
            
            let isDraggingCurrent = appState.isDraggingNode && appState.selectedNodeId == node.id
            
            let pos = renderData.nodePositions[node.id] ?? .zero
            
            StationNodeView(
                node: nodeBinding,
                canvasSize: canvasSize,
                isSelected: appState.selectedNodeId == node.id || appState.selectedNodeIds.contains(node.id),
                snapToGrid: showGrid,
                gridUnit: coordinateGridStep,
                bounds: bounds,
                nodePosition: pos,
                onTapAtLocation: { loc in onTap(node, loc) }
            )
            .position(pos)
            .id("node-interaction-\(node.id)")
        }
         
    }
}
