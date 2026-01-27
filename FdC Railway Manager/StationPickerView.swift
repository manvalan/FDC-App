import SwiftUI

struct StationPickerView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    @Binding var selectedStationId: String
    var linkedToStationId: String? = nil
    
    @State private var searchText = ""
    
    var filteredStations: [Node] {
        var stations = network.nodes
        
        // Connectivity filter
        if let originId = linkedToStationId {
            let connectedIds = network.edges.compactMap { edge -> String? in
                if edge.from == originId { return edge.to }
                if edge.trackType == .single && edge.to == originId { return edge.from }
                return nil
            }
            stations = stations.filter { connectedIds.contains($0.id) }
        }
        
        if searchText.isEmpty {
            return stations
        } else {
            return stations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredStations) { station in
                Button(action: {
                    selectedStationId = station.id
                    dismiss()
                }) {
                    HStack {
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
            .searchable(text: $searchText, prompt: "Cerca stazione...")
            .navigationTitle("Seleziona Stazione")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}
