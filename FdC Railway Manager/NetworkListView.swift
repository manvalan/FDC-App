import SwiftUI

@MainActor
struct NetworkListView: View {
    @ObservedObject var network: NetworkModel
    @Binding var selectedNode: Node?
    @Binding var selectedEdgeId: String?
    
    @State private var mode: NetworkListMode = .stations
    
    enum NetworkListMode: String, CaseIterable, Identifiable {
        case stations = "stations"
        case tracks = "tracks"
        var id: String { rawValue }
        
        var localizedName: String {
            self.rawValue.localized
        }
    }
    
    private func stationName(for id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? "Unknown (\(id.prefix(4)))"
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
            
            List {
                if mode == .stations {
                    Section(String(format: "stations_count".localized, network.nodes.count)) {
                        ForEach(network.sortedNodes) { node in
                            StationRowView(node: node, selectedNode: $selectedNode)
                        }
                        .onDelete { indexSet in
                            let sorted = network.sortedNodes
                            for index in indexSet {
                                let node = sorted[index]
                                network.removeNode(node.id)
                                if selectedNode?.id == node.id {
                                    selectedNode = nil
                                }
                            }
                        }
                    }
                } else {
                    Section(String(format: "tracks_count".localized, network.edges.count)) {
                        ForEach(network.sortedEdges) { edge in
                            EdgeRowView(
                                edge: edge,
                                selectedEdgeId: $selectedEdgeId,
                                fromName: stationName(for: edge.from),
                                toName: stationName(for: edge.to)
                            )
                        }
                        .onDelete { indexSet in
                            let sorted = network.sortedEdges
                            for index in indexSet {
                                let edge = network.sortedEdges[index]
                                network.removeEdge(from: edge.from, to: edge.to)
                                if selectedEdgeId == edge.id.uuidString {
                                    selectedEdgeId = nil
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("network".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive, action: { showDeleteAllConfirmation = true }) {
                        Label("delete_all".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(
            mode == .stations ? "delete_all_stations".localized : "delete_all_tracks".localized,
            isPresented: $showDeleteAllConfirmation
        ) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                if mode == .stations {
                    network.nodes.removeAll()
                    network.edges.removeAll() // Cannot have edges without nodes
                    selectedNode = nil
                } else {
                    network.edges.removeAll()
                    selectedEdgeId = nil
                }
                network.createCheckpoint()
            }
        } message: {
            Text(mode == .stations ? "delete_all_stations_confirm".localized : "delete_all_tracks_confirm".localized)
        }
    }
    
    @State private var showDeleteAllConfirmation = false
}
