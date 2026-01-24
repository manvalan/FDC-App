import SwiftUI

struct StationPickerView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    @Binding var selectedStationId: String
    
    @State private var searchText = ""
    
    var filteredStations: [Node] {
        if searchText.isEmpty {
            return network.nodes
        } else {
            return network.nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
