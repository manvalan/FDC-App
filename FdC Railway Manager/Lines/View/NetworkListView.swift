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
    @State private var showNodes: Bool = false
    
    // ViewModels
    private var stationVM: StationListViewModel {
        StationListViewModel(network: network, appState: appState, selectedNode: $selectedNode)
    }
    
    private var trackVM: TrackListViewModel {
        TrackListViewModel(network: network, appState: appState, selectedEdgeId: $selectedEdgeId)
    }
    
    private var ferroviaVM: FerroviaListViewModel {
        FerroviaListViewModel(network: network, appState: appState)
    }
    
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
        case ferrovie = "ferrovie"
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .stations: return "Stazioni"
            case .tracks: return "Binari"
            case .ferrovie: return "Ferrovie"
            }
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
            
            switch mode {
            case .stations:
                stationsListView
            case .tracks:
                tracksListView
            case .ferrovie:
                ferrovieListView
            }
        }
    }
    
    private var stationsListView: some View {
        let visibleItems = stationVM.items.filter {
            showNodes || $0.type != .junction
        }
        return VStack(spacing: 0) {
            FdCEntityList(
                title: String(format: "stations_count".localized, visibleItems.count),
                items: visibleItems,
                selectedItemId: Binding(
                    get: { selectedNode?.id },
                    set: { _ in }
                ),
                rowContent: { node in
                    HStack {
                        NetworkSymbols.stationSymbol(for: node, size: 12)
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
                searchText: stationVM.searchText,
                onSelect: stationVM.onSelect,
                onAdd: stationVM.onAdd,
                onDelete: stationVM.onDelete,
                onDeleteAll: stationVM.onDeleteAll
            )

            Divider()

            Button {
                showNodes.toggle()
            } label: {
                Label(
                    showNodes ? "Nascondi Nodi" : "Mostra Nodi",
                    systemImage: showNodes ? "eye.slash" : "eye"
                )
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
    }
    
    private var tracksListView: some View {
        FdCEntityList(
            title: String(format: "tracks_count".localized, trackVM.items.count),
            items: trackVM.items,
            selectedItemId: Binding(
                get: { selectedEdgeId },
                set: { selectedEdgeId = $0 }
            ),
            rowContent: { edge in
                HStack(spacing: 8) {
                    NetworkSymbols.trackSymbol(for: edge.trackType, width: 24, height: 12)
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
            searchText: trackVM.searchText,
            onSelect: trackVM.onSelect,
            onAdd: trackVM.onAdd,
            onDelete: trackVM.onDelete,
            onDeleteAll: trackVM.onDeleteAll
        )
    }
    
    private var ferrovieListView: some View {
        FdCEntityList(
            title: String(format: "Ferrovie: %d", ferroviaVM.items.count),
            items: ferroviaVM.items,
            selectedItemId: Binding(
                get: { appState.selectedInfraLineId },
                set: { appState.selectedInfraLineId = $0 }
            ),
            rowContent: { ferrovia in
                HStack {
                    NetworkSymbols.ferroviaSymbol(color: ferrovia.color, size: 12)
                    Text(ferrovia.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(ferrovia.nodeIds.count) stazioni")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            },
            searchText: ferroviaVM.searchText,
            onSelect: ferroviaVM.onSelect,
            onAdd: ferroviaVM.onAdd,
            onDelete: ferroviaVM.onDelete,
            onDeleteAll: ferroviaVM.onDeleteAll
        )
    }
}
