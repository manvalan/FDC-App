import Foundation
import Combine
import SwiftUI
import MapKit
import CoreLocation

struct MultiSelectionEditor: View {
    @EnvironmentObject var appState: AppState
    @Binding var lockedNodeIds: Set<String>
    
    // Local state for spring simulation parameters
    @State private var springStrength: Double = 0.5
    @State private var targetDistance: Double = 5.0 // km
    @State private var iterationCount: Int = 10
    
    var selectedNodes: [Node] {
        appState.railroad.network.nodes.filter { appState.selectedNodeIds.contains($0.id) }
            .sorted { ($0.longitude ?? 0) < ($1.longitude ?? 0) } // Default West->East sort
    }
    
    var body: some View {
        GroupBox(label: Label("Multi-Selezione (\(appState.selectedNodeIds.count))", systemImage: "square.dashed.inset.filled")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // --- Layout Operations ---
                    GroupBox("Layout") {
                        VStack(spacing: 8) {
                            Button("Allinea Latitudine (Y)") { alignLatitude() }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            
                            Button("Allinea Longitudine (X)") { alignLongitude() }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            
                            Divider()
                            
                            Text("Ottimizzazione Molle")
                                .font(.caption)
                            
                            HStack {
                                Text("Dist: \(Int(targetDistance))km")
                                Slider(value: $targetDistance, in: 1...50, step: 1)
                            }
                            
                            Button("Rilassa Layout") { relaxLayout() }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // --- Constructon Operations ---
                    GroupBox("Costruzione") {
                        Button("Crea Tracciato (O->E)") {
                            createLineFromSelection()
                        }
                        .buttonStyle(.bordered)
                        .help("Collega i nodi selezionati da Ovest a Est con doppi binari")
                    }
                    
                    // --- Altimetry Editor ---
                    GroupBox("Altimetria") {
                        ForEach(selectedNodes, id: \.id) { node in
                            HStack {
                                Text(node.name).font(.caption).lineLimit(1)
                                Spacer()
                                TextField("Alt", value: Binding(
                                    get: { node.altitude ?? 0 },
                                    set: { updateAltitude(node.id, alt: $0) }
                                ), format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                Text("m").font(.caption)
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
    }
    
    // MARK: - Logic
    
    private func alignLatitude() {
        let nodes = selectedNodes
        guard !nodes.isEmpty else { return }
        let avgLat = nodes.reduce(0.0) { $0 + ($1.latitude ?? 0) } / Double(nodes.count)
        
        appState.railroad.network.createCheckpoint()
        for node in nodes {
            updateNode(node.id, lat: avgLat)
        }
    }
    
    private func alignLongitude() {
        let nodes = selectedNodes
        guard !nodes.isEmpty else { return }
        let avgLon = nodes.reduce(0.0) { $0 + ($1.longitude ?? 0) } / Double(nodes.count)
        
        appState.railroad.network.createCheckpoint()
        for node in nodes {
            updateNode(node.id, lon: avgLon)
        }
    }
    
    private func relaxLayout() {
        // Simple Spring-Embedder 1D/2D
        guard selectedNodes.count > 1 else { return }
        
        appState.railroad.network.createCheckpoint()
        
        // Iterative relaxation
        for _ in 0..<iterationCount {
            let nodes = selectedNodes
            var newPositions: [String: (lat: Double, lon: Double)] = [:]
            
            
            for i in 0..<nodes.count {
                let node = nodes[i]
                if lockedNodeIds.contains(node.id) { continue }
                
                var forceLat = 0.0
                var forceLon = 0.0
                
                // Left neighbor
                if i > 0 {
                    let left = nodes[i-1]
                    let (fLat, fLon) = calculateSpringForce(target: left, current: node)
                    forceLat += fLat
                    forceLon += fLon
                }
                
                // Right neighbor
                if i < nodes.count - 1 {
                    let right = nodes[i+1]
                    let (fLat, fLon) = calculateSpringForce(target: right, current: node)
                    forceLat += fLat
                    forceLon += fLon
                }
                
                // Apply
                let currentLat = node.latitude ?? 0
                let currentLon = node.longitude ?? 0
                
                // Anchors (First and Last fixed)
                if i == 0 || i == nodes.count - 1 {
                    newPositions[node.id] = (currentLat, currentLon)
                } else {
                    newPositions[node.id] = (currentLat + forceLat * 0.1, currentLon + forceLon * 0.1)
                }
            }
            
            // Apply updates
            for (id, pos) in newPositions {
                updateNode(id, lat: pos.lat, lon: pos.lon)
            }
        }
    }
    
    private func calculateSpringForce(target: Node, current: Node) -> (Double, Double) {
        // Vector from current to target
        let tLat = target.latitude ?? 0
        let tLon = target.longitude ?? 0
        let cLat = current.latitude ?? 0
        let cLon = current.longitude ?? 0
        
        let dx = tLon - cLon
        let dy = tLat - cLat
        let distVal: Double = sqrt(dx*dx + dy*dy) // Renamed to avoid ambiguity
        
        guard distVal > 0 else { return (0, 0) }
        
        // Desired distance in degrees approx (very rough)
        // 1 deg ~ 111km. 1 unit ~ 100km simplificaton.
        let targetDeg = targetDistance / 100.0 
        
        let displacement = distVal - targetDeg
        
        // k * displacement * direction
        let k = springStrength
        let f = k * displacement // Double
        
        // Direction unit vector: (dy/dist, dx/dist)
        let dirY = dy / distVal
        let dirX = dx / distVal
        
        return (f * dirY, f * dirX)
    }
    
    func createLineFromSelection() {
        let nodes = selectedNodes
        guard nodes.count > 1 else { return }
        
        appState.railroad.network.createCheckpoint()
        
        for i in 0..<nodes.count - 1 {
            let n1 = nodes[i]
            let n2 = nodes[i+1]
            
            // distance
            let l1 = CLLocation(latitude: n1.latitude ?? 0, longitude: n1.longitude ?? 0)
            let l2 = CLLocation(latitude: n2.latitude ?? 0, longitude: n2.longitude ?? 0)
            let distKm = l1.distance(from: l2) / 1000.0
            
            // Check if edge exists (findEdge is bidirectional-aware)
            if appState.railroad.network.findEdge(from: n1.id, to: n2.id) == nil {
                let edge = Edge(from: n1.id, to: n2.id, distance: distKm, trackType: .double, maxSpeed: 160)
                appState.railroad.network.addEdge(edge)
            }
        }
    }
    
    private func updateNode(_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil) {
        appState.railroad.network.updateNode(id, lat: lat, lon: lon, alt: alt)
        appState.objectWillChange.send()
    }
    
    private func updateAltitude(_ id: String, alt: Double) {
        appState.railroad.network.createCheckpoint()
        updateNode(id, alt: alt)
    }
}
