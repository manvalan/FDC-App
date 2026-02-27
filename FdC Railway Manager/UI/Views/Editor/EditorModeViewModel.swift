import SwiftUI
import Combine
import CoreLocation

@MainActor
class EditorModeViewModel: ObservableObject {
    @Published var appState: AppState
    
    init(appState: AppState = AppState.shared) {
        self.appState = appState
    }
    
    var hasSelection: Bool {
        !appState.selectedNodeIds.isEmpty || 
        appState.selectedNodeId != nil || 
        appState.selectedEdgeId != nil || 
        appState.selectedInfraLineId != nil
    }
    
    func clearSelection() {
        appState.selectedNodeId = nil
        appState.selectedEdgeId = nil
        appState.selectedInfraLineId = nil
    }
    
    func createStation() {
        let id = "ST-\(Int.random(in: 1000...9999))"
        let latOffset = Double.random(in: -0.02...0.02)
        let lonOffset = Double.random(in: -0.02...0.02)
        
        let newStation = RailwayNode(
            id: id,
            name: "Stazione Nuova",
            type: .station,
            latitude: 45.4642 + latOffset,
            longitude: 9.1900 + lonOffset,
            altitude: 100,
            platforms: 2
        )
        
        appState.railroad.network.createCheckpoint()
        appState.railroad.network.addNode(newStation)
    }
    
    func createNewRailwayLine() {
        let count = appState.railroad.network.lines.count + 1
        let nodeIds = appState.selectedNodeIdsOrder.isEmpty ? Array(appState.selectedNodeIds) : appState.selectedNodeIdsOrder
        
        appState.railroad.network.createCheckpoint()
        
        let newLine = RailwayLine(
            name: "Linea \(count)",
            color: ["#3498db", "#e74c3c", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c"][count % 6],
            nodeIds: nodeIds
        )
        appState.railroad.network.lines.append(newLine)
        appState.selectedInfraLineId = newLine.id
        appState.selectedNodeIds = Set(newLine.nodeIds)
        appState.selectedNodeIdsOrder = Array(newLine.nodeIds)
        appState.isMultiSelectMode = false
    }
    
    func deleteSelectedItems() {
        appState.railroad.network.createCheckpoint()
        
        if !appState.selectedNodeIds.isEmpty {
            for nodeId in appState.selectedNodeIds {
                appState.railroad.network.removeNode(nodeId)
            }
            appState.selectedNodeIds.removeAll()
        }
        
        if let nodeId = appState.selectedNodeId {
            appState.railroad.network.removeNode(nodeId)
            appState.selectedNodeId = nil
        }
        
        if let edgeId = appState.selectedEdgeId, let id = UUID(uuidString: edgeId) {
            appState.railroad.network.removeEdge(id)
            appState.selectedEdgeId = nil
        }
        
        appState.selectedRouteId = nil
    }
    
    func toggleMultiSelect() {
        appState.isMultiSelectMode.toggle()
        if !appState.isMultiSelectMode {
            appState.selectedNodeIds.removeAll()
            appState.selectedNodeIdsOrder.removeAll()
        }
    }
}
