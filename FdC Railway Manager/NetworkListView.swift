import SwiftUI

@MainActor
struct NetworkListView: View {
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
        GenericEntityListView(
            title: String(format: "stations_count".localized, network.nodes.count),
            items: network.sortedNodes,
            selectedItem: $selectedNode,
            onAdd: { /* Add station action */ },
            onEdit: { station in /* Edit station action */ },
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
        GenericEntityListView(
            title: String(format: "tracks_count".localized, network.edges.count),
            items: network.sortedEdges,
            selectedItem: Binding(
                get: { network.edges.first { $0.id.uuidString == selectedEdgeId } },
                set: { selectedEdgeId = $0?.id.uuidString }
            ),
            onAdd: { /* Add track action */ },
            onEdit: { track in /* Edit track action */ },
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
