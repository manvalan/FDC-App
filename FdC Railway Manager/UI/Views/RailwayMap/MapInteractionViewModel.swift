import SwiftUI
import Combine
import CoreLocation

@MainActor
class MapInteractionViewModel: ObservableObject {
    @Published var appState: AppState
    
    init(appState: AppState = AppState.shared) {
        self.appState = appState
    }
    
    private var network: NetworkModel { appState.railroad.network }
    private var lines: LinesManager { appState.railroad.lines }

    func handleStationTap(_ node: RailwayNode, editMode: Binding<MapEditMode>, newTrackFrom: Binding<Node?>, newTrackTo: Binding<Node?>, newTrackDistance: Binding<Double>) {
        if let pickingCallback = appState.stationPickingCallback {
            pickingCallback(node.id)
            return
        }
        
        if editMode.wrappedValue == .addTrack {
            handleTrackDrafting(node, newTrackFrom: newTrackFrom, newTrackTo: newTrackTo, newTrackDistance: newTrackDistance)
        } else {
            selectNode(node)
        }
    }
    
    private func handleTrackDrafting(_ node: RailwayNode, newTrackFrom: Binding<Node?>, newTrackTo: Binding<Node?>, newTrackDistance: Binding<Double>) {
        if appState.trackDraftFromId == nil {
            appState.trackDraftFromId = node.id
            newTrackFrom.wrappedValue = node
        } else if appState.trackDraftFromId == node.id {
            appState.trackDraftFromId = nil
            newTrackFrom.wrappedValue = nil
        } else {
            appState.trackDraftToId = node.id
            newTrackTo.wrappedValue = node
            if let fromId = appState.trackDraftFromId,
               let n1 = network.nodes.first(where: { $0.id == fromId }) {
                let distKm = network.calculateDistance(from: n1, to: node)
                newTrackDistance.wrappedValue = max(1.0, round(distKm * 10) / 10.0)
            }
        }
    }
    
    private func selectNode(_ node: RailwayNode) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            appState.selectedNodeId = node.id
            appState.selectedRouteId = nil
            appState.selectedEdgeId = nil
            
            if appState.currentMode == .editor {
                appState.isInspectorEditingMode = true
            }
        }
    }

    func createStation(at location: CGPoint, in size: CGSize, bounds: MapBounds) -> RailwayNode {
        let drawWidth = size.width - 100
        let drawHeight = size.height - 100
        let safeDrawWidth = max(drawWidth, 1)
        let safeDrawHeight = max(drawHeight, 1)
        
        let lon = bounds.minLon + ((location.x - 50) / safeDrawWidth) * bounds.xRange
        let lat = bounds.minLat + (1.0 - (location.y - 50) / safeDrawHeight) * bounds.yRange
        
        let name = String(format: "station_default_name".localized, network.nodes.count + 1)
        let newNode = RailwayNode(id: UUID().uuidString, name: name, type: .station, latitude: lat, longitude: lon, capacity: 10, platforms: 2)
        
        network.createCheckpoint()
        network.addNode(newNode)
        return newNode
    }
    
    func createTrack(from: Node, to: Node, distance: Double, type: RailwayEdge.TrackType) {
        let speed: Int = {
            switch type {
            case .single: return Int(appState.singleTrackMaxSpeed)
            case .double: return Int(appState.doubleTrackMaxSpeed)
            case .regional: return Int(appState.regionalTrackMaxSpeed)
            case .highSpeed: return Int(appState.highSpeedTrackMaxSpeed)
            }
        }()
        
        let newEdge = RailwayEdge(from: from.id, to: to.id, distance: distance, trackType: type, maxSpeed: speed, capacity: 10)
        network.createCheckpoint()
        network.addEdge(newEdge)
        
        withAnimation {
            appState.selectedEdgeId = newEdge.id.uuidString
            appState.selectedNodeId = nil
            appState.selectedRouteId = nil
        }
    }
}
