import SwiftUI

struct LineCreationView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    @State private var lineName: String = ""
    @State private var lineColor: Color = .blue
    
    // Controlled by PathPickerComponent
    @State private var startStationId: String = ""
    @State private var viaStationId: String = ""
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = false
    
    @State private var manualStationId: String = ""
    @State private var activePicker: PickerType?
    
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dettagli Linea")) {
                    TextField("Nome Linea (es. Milano-Roma)", text: $lineName)
                    ColorPicker("Colore Linea", selection: $lineColor)
                }
                
                PathPickerComponent(
                    startStationId: $startStationId,
                    viaStationId: $viaStationId,
                    endStationId: $endStationId,
                    stationSequence: $stationSequence,
                    manualAddition: $manualAddition,
                    activePicker: $activePicker
                )
                
                if !stationSequence.isEmpty {
                    Section(header: Text("Stazioni (Sequenza)")) {
                        ForEach(stationSequence, id: \.self) { id in
                            if let node = network.nodes.first(where: { $0.id == id }) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(lineColor)
                                    Text(node.name)
                                    Spacer()
                                    let dwell = (node.type == .interchange) ? 5 : 3
                                    Text("\(dwell) min").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        .onMove { from, to in
                            stationSequence.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { offsets in
                            stationSequence.remove(atOffsets: offsets)
                        }
                        
                        Button(action: { activePicker = .manual }) {
                            Label("Aggiungi fermata successiva", systemImage: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Text("Puoi modificare l'ordine o rimuovere stazioni se necessario.").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Nuova Linea")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveLine()
                    }
                    .disabled(lineName.isEmpty || stationSequence.count < 2)
                }
            }
            .onChange(of: startStationId) { old, new in
                if !new.isEmpty && !manualAddition { stationSequence = [new] }
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    stationSequence.append(new)
                    manualStationId = "" // Reset for next selection
                }
            }
            .sheet(item: $activePicker) { item in
                Group {
                    switch item {
                    case .start:
                        StationPickerView(selectedStationId: $startStationId)
                    case .via:
                        StationPickerView(selectedStationId: $viaStationId)
                    case .end:
                        StationPickerView(selectedStationId: $endStationId)
                    case .manual:
                        StationPickerView(selectedStationId: $manualStationId, linkedToStationId: stationSequence.last)
                    }
                }
                .environmentObject(network)
            }
        }
    }
    
    private func saveLine() {
        let hexColor = lineColor.toHex()
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        let newLine = RailwayLine(
            id: UUID().uuidString,
            name: lineName,
            color: hexColor,
            originId: startStationId,
            destinationId: endStationId,
            stops: stops
        )
        network.lines.append(newLine)
        dismiss()
    }
}
