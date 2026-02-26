import Foundation
import Combine
import SwiftUI
import CoreLocation

struct EditorInspectorContent: View {
    @EnvironmentObject var appState: AppState
    @Binding var editingLineId: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let node = appState.selectedNode, let index = appState.railroad.network.nodes.firstIndex(where: { $0.id == node.id }) {
                    // Use unified StationInspectorView
                    StationInspectorView(
                        station: Binding(
                            get: { appState.railroad.network.nodes[index] },
                            set: { appState.railroad.network.nodes[index] = $0 }
                        ),
                        isMoveModeEnabled: .constant(false),
                        onDelete: {
                            appState.railroad.network.removeNode(node.id)
                            appState.selectedNodeId = nil
                            appState.selectedNodeIds.remove(node.id)
                        }
                    )
                } else if let edgeId = appState.selectedEdgeId,
                          let index = appState.railroad.network.edges.firstIndex(where: { $0.id.uuidString == edgeId }) {
                    TrackInspectorView(
                        edge: Binding(
                            get: { appState.railroad.network.edges[index] },
                            set: { appState.railroad.network.edges[index] = $0 }
                        ),
                        onDelete: {
                            let edge = appState.railroad.network.edges[index]
                            appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                            appState.selectedEdgeId = nil
                        },
                        onBack: nil
                    )
                } else if let routeId = appState.selectedRouteId,
                           let route = appState.railroad.lines.routes.first(where: { $0.id == routeId }) {
                    routeEditor(route: route)
                } else {
                    Text("Seleziona una stazione, binario o rotta per modificare le proprietà.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    private func addStationToRoute(node: RailwayNode, route: TrainRoute) {
        appState.railroad.network.createCheckpoint()
        var updatedRoute = route
        if !updatedRoute.stationIds.contains(node.id) {
            updatedRoute.stationIds.append(node.id)
        }
        if let idx = appState.railroad.lines.routes.firstIndex(where: { $0.id == route.id }) {
            appState.railroad.lines.routes[idx] = updatedRoute
        }
    }

    

    
    @ViewBuilder
    private func routeEditor(route: TrainRoute) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Relazione: \(route.name)")
                    .font(.headline)
                Spacer()
                Button(action: { editingLineId = route.id }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Modifica Percorso e Dettagli")
                Button(role: .destructive) {
                    appState.railroad.lines.routes.removeAll(where: { $0.id == route.id })
                    appState.selectedRouteId = nil
                } label: {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            Divider()
            
            ForEach(0..<route.stationIds.count, id: \.self) { i in
                let sid = route.stationIds[i]
                if let node = appState.railroad.network.nodes.first(where: { $0.id == sid }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(node.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Spacer()
                            TextField("Alt", value: Binding(
                                get: { node.altitude ?? 0 },
                                set: { appState.railroad.network.updateNode(node.id, alt: $0) }
                            ), format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            Text("m").font(.caption)
                        }
                        
                        // Edge to next
                        if i < route.stationIds.count - 1 {
                            let nextSid = route.stationIds[i+1]
                            if let nextNode = appState.railroad.network.nodes.first(where: { $0.id == nextSid }) {
                                let edge = appState.railroad.network.findEdge(from: node.id, to: nextNode.id)
                                let dist = edge?.distance ?? {
                                    let l1 = CLLocation(latitude: node.latitude ?? 0, longitude: node.longitude ?? 0)
                                    let l2 = CLLocation(latitude: nextNode.latitude ?? 0, longitude: nextNode.longitude ?? 0)
                                    return l1.distance(from: l2) / 1000.0
                                }()
                                
                                let currentSlope = calculateSlope(from: node, to: nextNode)
                                
                                HStack {
                                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2, height: 20).padding(.leading, 5)
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text("\(String(format: "%.1f", dist)) km")
                                            .font(.caption2).foregroundColor(.secondary)
                                        
                                        HStack(spacing: 4) {
                                            Text("Pend:")
                                                .font(.caption2)
                                            TextField("0", value: Binding(
                                                get: { currentSlope },
                                                set: { newSlope in
                                                    // Propagate altitude to next node
                                                    let deltaH = newSlope * dist // m (since slope is ‰ and dist is km, conversion cancels out: (‰/1000) * (km*1000) = ‰ * km = m? Wait.
                                                    // 10‰ * 1km = 0.01 * 1000m = 10m. Correct.
                                                    let newAlt = (node.altitude ?? 0) + deltaH
                                                    appState.railroad.network.updateNode(nextNode.id, alt: newAlt)
                                                }
                                            ), format: .number)
                                            .frame(width: 40)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.caption)
                                            Text("‰")
                                                .font(.caption2)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
    }
    
    private func calculateSlope(from: RailwayNode, to: RailwayNode) -> Double {
        guard let alt1 = from.altitude, let alt2 = to.altitude else { return 0 }
        
        // Distance
        var distM: Double = 0
        if let edge = appState.railroad.network.findEdge(from: from.id, to: to.id) {
             distM = edge.distance * 1000
        } else {
             let l1 = CLLocation(latitude: from.latitude ?? 0, longitude: from.longitude ?? 0)
             let l2 = CLLocation(latitude: to.latitude ?? 0, longitude: to.longitude ?? 0)
             distM = l1.distance(from: l2)
        }
        
        guard distM > 0 else { return 0 }
        
        let deltaH = alt2 - alt1 // meters
        return (deltaH / distM) * 1000 // Permille
    }

    private func getNodeName(_ id: String) -> String {
        appState.railroad.network.nodes.first(where: { $0.id == id })?.name ?? id
    }
}
