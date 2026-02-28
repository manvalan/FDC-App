import SwiftUI
import Combine
import CoreLocation

@MainActor
class EditorModeViewModel: ObservableObject {
    @Published var appState: AppState
    
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState) {
        self.appState = appState
        setupBindings()
    }
    
    private func setupBindings() {
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
    var isWaitingForStationPlacement: Bool {
        appState.mapEditMode == .addStation
    }
    private var placementTimer: AnyCancellable?
    
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
        // Entra in modalità "Attesa posizionamento"
        withAnimation {
            appState.designSubMode = .infrastructure
            appState.clearSelection()
            appState.mapEditMode = .addStation
        }
        
        // Timer di 20 secondi: se non posizioni la stazione, annulla tutto
        placementTimer?.cancel()
        placementTimer = Just(())
            .delay(for: .seconds(20), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.appState.mapEditMode == .addStation {
                    withAnimation {
                        self.appState.mapEditMode = .explore
                    }
                }
            }
    }

    func placeStation(at location: CGPoint, in size: CGSize, bounds: MapBounds) {
        guard appState.mapEditMode == .addStation else { return }
        
        placementTimer?.cancel()
        withAnimation {
            appState.mapEditMode = .explore
        }
        
        // Conversione coordinate (logica simile a MapInteractionViewModel)
        let drawWidth = max(size.width - 100, 1)
        let drawHeight = max(size.height - 100, 1)
        
        let lon = bounds.minLon + ((location.x - 50) / drawWidth) * bounds.xRange
        let lat = bounds.minLat + (1.0 - (location.y - 50) / drawHeight) * bounds.yRange
        
        let id = "ST-\(Int.random(in: 1000...9999))"
        let name = "Stazione Nuova"
        
        let newStation = RailwayNode(
            id: id,
            name: name,
            type: .station,
            latitude: lat,
            longitude: lon,
            altitude: 100,
            platforms: 2
        )
        
        appState.railroad.network.createCheckpoint()
        appState.railroad.network.addNode(newStation)
        
        // Seleziona la nuova stazione
        appState.selectedNodeId = id
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
    
    func relaxNetworkLayout() {
        let network = appState.railroad.network
        guard network.nodes.count > 1 else { return }
        
        network.createCheckpoint()
        
        let iterationCount = 15
        let springStrength = 0.5
        // Obiettivo: una distanza molto indicativa in gradi (molto approssimativa)
        let targetDistanceDeg = 0.05
        
        var nodePositions = network.nodes.reduce(into: [String: (lat: Double, lon: Double)]()) { dict, node in
            dict[node.id] = (node.latitude ?? 0, node.longitude ?? 0)
        }
        
        // Calcola l'elenco dei vicini per ogni nodo
        var adjacencyList: [String: [String]] = [:]
        for edge in network.edges {
            adjacencyList[edge.from, default: []].append(edge.to)
            adjacencyList[edge.to, default: []].append(edge.from)
        }
        
        for _ in 0..<iterationCount {
            var newPositions = nodePositions
            
            for node in network.nodes {
                let neighbors = adjacencyList[node.id] ?? []
                guard !neighbors.isEmpty else { continue }
                
                var forceLat = 0.0
                var forceLon = 0.0
                
                let currentPos = nodePositions[node.id]!
                
                for neighborId in neighbors {
                    guard let targetPos = nodePositions[neighborId] else { continue }
                    
                    let dx = targetPos.lon - currentPos.lon
                    let dy = targetPos.lat - currentPos.lat
                    let dist = sqrt(dx*dx + dy*dy)
                    
                    if dist > 0.0001 { // Evita divisione per zero e sovrapposizioni perfette
                        let displacement = dist - targetDistanceDeg
                        let force = springStrength * displacement
                        
                        forceLat += force * (dy / dist)
                        forceLon += force * (dx / dist)
                    } else {
                        // Piccola forza repulsiva se sono nello stesso punto
                        forceLat += Double.random(in: -0.01...0.01)
                        forceLon += Double.random(in: -0.01...0.01)
                    }
                }
                
                // Limita lo spostamento per iterazione
                forceLat = max(min(forceLat, 0.1), -0.1)
                forceLon = max(min(forceLon, 0.1), -0.1)
                
                newPositions[node.id] = (currentPos.lat + forceLat * 0.1, currentPos.lon + forceLon * 0.1)
            }
            nodePositions = newPositions
        }
        
        // Applica le posizioni calcolate
        for (id, pos) in nodePositions {
            network.updateNode(id, lat: pos.lat, lon: pos.lon, alt: nil)
        }
        appState.objectWillChange.send()
    }
}
