import SwiftUI

struct StationPickerView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    @Binding var selectedStationId: String
    var linkedToStationId: String? = nil
    var whitelistIds: [String]? = nil
    
    @State private var searchText = ""
    @State private var ignoreFilters = false
    
    var filteredStations: [Node] {
        var stations = network.nodes
        
        if !ignoreFilters {
            // Priority 1: Whitelist (usually means stations restricted to a Line)
            if let whitelist = whitelistIds {
                stations = stations.filter { whitelist.contains($0.id) }
            }
            
            // Priority 2: Connectivity (finding the 'next' station via tracks)
            if let originId = linkedToStationId {
                let connectedIds = network.edges.compactMap { edge -> String? in
                    if edge.from == originId { return edge.to }
                    if edge.to == originId { return edge.from }
                    return nil
                }
                stations = stations.filter { connectedIds.contains($0.id) }
            }
        }
        
        if searchText.isEmpty {
            return stations.sorted { $0.name < $1.name }
        } else {
            return stations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredStations.isEmpty {
                    VStack(spacing: 20) {
                        let isLineRestricted = whitelistIds != nil
                        let isConnectivityRestricted = linkedToStationId != nil
                        
                        ContentUnavailableView(
                            ignoreFilters ? "Nessuna Stazione" : (isLineRestricted ? "Linea Vuota" : "Nessuna Connessione"),
                            systemImage: ignoreFilters ? "mappin.slash" : (isLineRestricted ? "tray" : "point.topleft.down.to.point.bottomright.curvepath"),
                            description: Text(errorMessage(isLine: isLineRestricted, isConn: isConnectivityRestricted))
                        )
                        
                        if !ignoreFilters && !network.nodes.isEmpty {
                            Button("Mostra comunque tutte le stazioni") {
                                withAnimation {
                                    ignoreFilters = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else if network.nodes.isEmpty {
                            Text("Devi prima creare le stazioni dalla sezione 'Rete'.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else {
                    List(filteredStations) { station in
                        Button(action: {
                            selectedStationId = station.id
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: station.type == .interchange ? "star.fill" : "mappin.circle.fill")
                                    .foregroundColor(station.type == .interchange ? .yellow : .blue)
                                
                                Text(station.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedStationId == station.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Cerca stazione...")
            .navigationTitle("Seleziona Stazione")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
    
    private func errorMessage(isLine: Bool, isConn: Bool) -> String {
        if ignoreFilters { return "Non ci sono stazioni registrate nel sistema." }
        if isLine && (whitelistIds ?? []).isEmpty {
            return "Questa linea ferroviaria non ha ancora stazioni assegnate. Aggiungile nella scheda 'Linee'."
        }
        if isConn {
            return "Non ci sono binari che collegano l'ultima stazione scelta ad altri nodi. Disegna un binario o mostra tutte le stazioni."
        }
        return "Nessuna stazione corrisponde ai criteri di ricerca."
    }
}
