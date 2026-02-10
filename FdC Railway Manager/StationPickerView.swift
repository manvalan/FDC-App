import SwiftUI

struct StationPickerView: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    @Environment(\.dismiss) var dismiss
    @Binding var selectedStationId: String
    var linkedToStationId: String? = nil
    var whitelistIds: [String]? = nil
    
    @State private var searchText = ""
    @State private var ignoreFilters = false
    
    var filteredStations: [Node] {
        var allStations = network.nodes.sorted { $0.name < $1.name }
        
        if ignoreFilters {
            return searchText.isEmpty ? allStations : allStations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        var connectionFiltered = allStations
        var isFiltering = false
        
        // Priority 1: Whitelist (specific Line stations)
        if let whitelist = whitelistIds {
            connectionFiltered = connectionFiltered.filter { whitelist.contains($0.id) }
            isFiltering = true
        }
        
        // Priority 2: Connectivity
        if let originId = linkedToStationId {
            let connectedIds = network.getNeighborStations(for: originId)
            let result = connectionFiltered.filter { connectedIds.contains($0.id) }
            
            // PIGNOLO: Se il filtro di connettività non produce nulla, 
            // mostriamo tutte le stazioni (altrimenti l'utente è bloccato)
            // ma indichiamo che il filtro è fallito.
            if result.isEmpty && !connectionFiltered.isEmpty {
                // Return all but maybe they will be sorted differently? 
                // For now just return all available.
                return filterBySearch(connectionFiltered)
            }
            return filterBySearch(result)
        }
        
        return filterBySearch(connectionFiltered)
    }
    
    private func filterBySearch(_ list: [Node]) -> [Node] {
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredStations.isEmpty {
                    VStack(spacing: 20) {
                        let isLineRestricted = whitelistIds != nil
                        let isConnectivityRestricted = linkedToStationId != nil
                        
                        ContentUnavailableView(
                            ignoreFilters ? "no_stations".localized : (isLineRestricted ? "empty_line".localized : "no_connection".localized),
                            systemImage: ignoreFilters ? "mappin.slash" : (isLineRestricted ? "tray" : "point.topleft.down.to.point.bottomright.curvepath"),
                            description: Text(errorMessage(isLine: isLineRestricted, isConn: isConnectivityRestricted))
                        )
                        
                        if !ignoreFilters && !network.nodes.isEmpty {
                            Button("show_all_anyway".localized) {
                                withAnimation {
                                    ignoreFilters = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else if network.nodes.isEmpty {
                            Text("must_create_stations".localized)
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
            .searchable(text: $searchText, prompt: "search_station".localized)
            .navigationTitle("select_station".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(ignoreFilters ? "filter".localized : "show_all".localized) {
                        ignoreFilters.toggle()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
            }
        }
    }
    
    private func errorMessage(isLine: Bool, isConn: Bool) -> String {
        if ignoreFilters { return "no_stations_system".localized }
        if isLine && (whitelistIds ?? []).isEmpty {
            return "line_no_stations".localized
        }
        if isConn {
            return "no_connected_tracks".localized
        }
        return "no_stations_criteria".localized
    }
}
