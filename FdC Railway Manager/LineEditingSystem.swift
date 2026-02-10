import SwiftUI

// Shared component for managing the station sequence in Line editing/creation
struct StationSequenceSection: View {
    @Binding var stationSequence: [String]
    let lineColor: Color
    let network: RailwayNetwork
    @Binding var activePicker: PickerType?
    let suggestions: [Node]
    
    var body: some View {
        Section(header: Text("Stazioni nella Sequenza")) {
            if stationSequence.isEmpty {
                Text("Nessuna stazione selezionata")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(stationSequence.enumerated()), id: \.offset) { index, stationId in
                    let node = network.nodes.first(where: { $0.id == stationId })
                    HStack {
                        Image(systemName: index == 0 ? "play.circle.fill" : (index == stationSequence.count - 1 ? "stop.circle.fill" : "mappin.circle.fill"))
                            .foregroundColor(index == 0 ? .green : (index == stationSequence.count - 1 ? .red : lineColor))
                        
                        Text(node?.name ?? "Sconosciuta")
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            withAnimation {
                                _ = stationSequence.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { from, to in
                    stationSequence.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    stationSequence.remove(atOffsets: offsets)
                }
            }
            
            Button(action: { activePicker = .manual }) {
                Label("Aggiungi fermata (Ricerca)", systemImage: "magnifyingglass.circle.fill")
                    .foregroundColor(.blue)
            }
            
            Text("Trascina le maniglie a destra per riordinare.").font(.caption).foregroundColor(.secondary)
        }
    }
}
