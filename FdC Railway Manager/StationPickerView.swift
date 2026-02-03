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
        
        let result = stations.sorted { $0.name < $1.name }
        if searchText.isEmpty {
            return result
        } else {
            return result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
