import SwiftUI

@MainActor
struct NetworkListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var network: NetworkModel
    @Binding var selectedNode: Node?
    @Binding var selectedEdgeId: String?
    
    let initialMode: NetworkListMode?
    @State private var mode: NetworkListMode = .stations
    @State private var showDeleteAllConfirmation = false
    
    init(network: NetworkModel, selectedNode: Binding<Node?>, selectedEdgeId: Binding<String?>, initialMode: NetworkListMode? = nil) {
        self.network = network
        self._selectedNode = selectedNode
        self._selectedEdgeId = selectedEdgeId
        self.initialMode = initialMode
        self._mode = State(initialValue: initialMode ?? .stations)
    }
    
    enum NetworkListMode: String, CaseIterable, Identifiable {
        case stations = "stations"
        case tracks = "tracks"
        var id: String { rawValue }
        
        var localizedName: String {
            self.rawValue.localized
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("visualization".localized, selection: $mode) {
                ForEach(NetworkListMode.allCases) { m in
                    Text(m.localizedName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            if mode == .stations {
                stationsListView
            } else {
                tracksListView
            }
        }
    }
    
    private var stationsListView: some View {
        FdCEntityList(
            title: String(format: "stations_count".localized, network.nodes.count),
            items: network.sortedNodes,
            selectedItemId: Binding(
                get: { selectedNode?.id },
                set: { _ in }
            ),
            rowContent: { node in
                HStack {
                    Circle()
                        .fill(node.type == .station ? Color.blue : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(node.name ?? node.id)
                        .font(.subheadline)
                    Spacer()
                    if let platforms = node.platforms, platforms > 0 {
                        Text("\(platforms) bin.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            },
            searchText: { $0.name ?? $0.id },
            onSelect: { station in
                selectedNode = station
                appState.showPanel(.inspector)
            },
            onAdd: {
                let newStation = Node(
                    id: UUID().uuidString,
                    name: String(format: "station_default_name".localized, network.nodes.count + 1),
                    type: .station,
                    latitude: 42.0,
                    longitude: 12.5,
                    platforms: 2
                )
                network.nodes.append(newStation)
                selectedNode = newStation
                network.createCheckpoint()
                appState.showPanel(.inspector)
            },
            onDelete: { station in
                network.removeNode(station.id)
                if selectedNode?.id == station.id {
                    selectedNode = nil
                }
                network.createCheckpoint()
            },
            onDeleteAll: {
                network.nodes.removeAll()
                network.edges.removeAll()
                selectedNode = nil
                network.createCheckpoint()
            }
        )
    }
    
    private var tracksListView: some View {
        FdCEntityList(
            title: String(format: "tracks_count".localized, network.edges.count),
            items: network.sortedEdges,
            selectedItemId: Binding(
                get: { selectedEdgeId },
                set: { selectedEdgeId = $0 }
            ),
            rowContent: { edge in
                HStack {
                    let fromName = network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
                    let toName = network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
                    Text("\(fromName) → \(toName)")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f km", edge.distance))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            },
            searchText: { edge in
                let fromName = network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
                let toName = network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
                return "\(fromName) \(toName)"
            },
            onSelect: { track in
                selectedEdgeId = track.id.uuidString
                appState.showPanel(.inspector)
            },
            onAdd: { 
                appState.isCreatingTrack = true
                appState.showPanel(.inspector)
            },
            onDelete: { track in
                network.removeEdge(from: track.from, to: track.to)
                if selectedEdgeId == track.id.uuidString {
                    selectedEdgeId = nil
                }
                network.createCheckpoint()
            },
            onDeleteAll: {
                network.edges.removeAll()
                selectedEdgeId = nil
                network.createCheckpoint()
            }
        )
    }
}
