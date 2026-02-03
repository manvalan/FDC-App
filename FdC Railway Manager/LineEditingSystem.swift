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
            
            Divider().padding(.vertical, 4)
            
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consigliate (Tocca per aggiungere):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions) { node in
                                Button(action: {
                                    withAnimation {
                                        stationSequence.append(node.id)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text(node.name)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Text("Trascina le maniglie a destra per riordinare.").font(.caption).foregroundColor(.secondary)
        }
    }
}
