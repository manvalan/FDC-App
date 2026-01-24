import SwiftUI

struct LineCreationView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    @State private var lineName: String = ""
    @State private var lineColor: Color = .blue
    @State private var startStationId: String = ""
    @State private var viaStationId: String = "" // Added state
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    
    // Alternative routes
    @State private var alternatives: [(path: [String], distance: Double, description: String)] = []
    @State private var selectedAlternativeIndex: Int? = nil
    
    @State private var showStartPicker = false // Removed
    @State private var showEndPicker = false // Removed
    
    enum PickerType: Identifiable {
        case start, via, end // Added via
        var id: Int { hashValue }
    }
    @State private var activePicker: PickerType?

    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dettagli Linea")) {
                    TextField("Nome Linea (es. Milano-Roma)", text: $lineName)
                    ColorPicker("Colore Linea", selection: $lineColor)
                }
                
                Section(header: Text("Percorso")) {
                    HStack {
                        Text("Partenza")
                        Spacer()
                        Button(action: { activePicker = .start }) {
                            Text(stationName(startStationId))
                                .foregroundColor(startStationId.isEmpty ? .secondary : .primary)
                        }
                    }
                    
                    HStack {
                        Text("Passaggio per (Via)")
                        Spacer()
                        Button(action: { activePicker = .via }) {
                            Text(stationName(viaStationId))
                                .foregroundColor(viaStationId.isEmpty ? .secondary : .primary)
                        }
                    }
                    if !viaStationId.isEmpty {
                        Button("Rimuovi Via") { viaStationId = "" }
                            .font(.caption).foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Arrivo")
                        Spacer()
                        Button(action: { activePicker = .end }) {
                            Text(stationName(endStationId))
                                .foregroundColor(endStationId.isEmpty ? .secondary : .primary)
                        }
                    }
                    
                    Button("Calcola Percorsi") {
                        calculatePath()
                    }
                    .disabled(startStationId.isEmpty || endStationId.isEmpty || startStationId == endStationId)
                }
                
                if !alternatives.isEmpty {
                    Section(header: Text("Scegli un Percorso")) {
                        List {
                            ForEach(alternatives.indices, id: \.self) { index in
                                let alt = alternatives[index]
                                Button(action: {
                                    selectAlternative(index)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(alt.description).font(.headline)
                                            Text("\(String(format: "%.1f", alt.distance)) km - \(alt.path.count) stazioni")
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedAlternativeIndex == index {
                                            Image(systemName: "checkmark").foregroundColor(.blue)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                if !stationSequence.isEmpty {
                    Section(header: Text("Stazioni (Sequenza)")) {
                        List {
                            ForEach(stationSequence, id: \.self) { id in
                                if let node = network.nodes.first(where: { $0.id == id }) {
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(lineColor)
                                        Text(node.name)
                                    }
                                }
                            }
                            .onMove { from, to in
                                stationSequence.move(fromOffsets: from, toOffset: to)
                            }
                            .onDelete { offsets in
                                stationSequence.remove(atOffsets: offsets)
                            }
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
            .sheet(item: $activePicker) { item in
                switch item {
                case .start:
                    StationPickerView(selectedStationId: $startStationId)
                case .via:
                    StationPickerView(selectedStationId: $viaStationId)
                case .end:
                    StationPickerView(selectedStationId: $endStationId)
                }
            }
        }
    }
    

    
    private func stationName(_ id: String) -> String {
        if id.isEmpty { return "Seleziona..." }
        return network.nodes.first(where: { $0.id == id })?.name ?? "Sconosciuta"
    }
    
    private func calculatePath() {
        errorMessage = nil
        stationSequence = []
        alternatives = []
        selectedAlternativeIndex = nil
        
        guard !startStationId.isEmpty, !endStationId.isEmpty else { return }
        
        if viaStationId.isEmpty {
            // Standard search
            let results = network.findAlternativePaths(from: startStationId, to: endStationId)
            if results.isEmpty {
                 errorMessage = "Nessun percorso trovato."
            } else {
                 alternatives = results
                 selectAlternative(0)
            }
        } else {
            // Composite search
            let leg1 = network.findAlternativePaths(from: startStationId, to: viaStationId)
            let leg2 = network.findAlternativePaths(from: viaStationId, to: endStationId)
            
            if leg1.isEmpty || leg2.isEmpty {
                errorMessage = "Impossibile trovare un percorso passando per la stazione intermedia."
                return
            }
            
            // Combine top results (Limit to top 2x2 = 4 combinations max)
            var combined: [(path: [String], distance: Double, description: String)] = []
            
            for l1 in leg1.prefix(2) {
                for l2 in leg2.prefix(2) {
                    // Merge paths. l1 ends with Via, l2 starts with Via.
                    // path = l1 + l2.dropFirst()
                    let mergedPath = l1.path + l2.path.dropFirst()
                    let totalDist = l1.distance + l2.distance
                    let desc = "Via \(stationName(viaStationId))" // Simple description
                    combined.append((path: mergedPath, distance: totalDist, description: desc))
                }
            }
            
            // Deduplicate? Unlikely needed if algos are deterministic
            alternatives = combined.sorted(by: { $0.distance < $1.distance })
            
            if alternatives.isEmpty {
                 errorMessage = "Errore nella combinazione dei percorsi."
            } else {
                 selectAlternative(0)
            }
        }
    }
    
    private func selectAlternative(_ index: Int) {
        guard index < alternatives.count else { return }
        selectedAlternativeIndex = index
        let alt = alternatives[index]
        stationSequence = alt.path
        
        // Auto-name
        let startName = network.nodes.first(where: { $0.id == startStationId })?.name ?? "A"
        let endName = network.nodes.first(where: { $0.id == endStationId })?.name ?? "B"
        
        if alt.description == "Diretto" {
             lineName = "\(startName) - \(endName)"
        } else {
             lineName = "\(startName) - \(endName) (\(alt.description))"
        }
    }
    
    // Legacy save logic remains same
    private func saveLine() {
        let hexColor = lineColor.toHex()
        let newLine = RailwayLine(id: UUID().uuidString, name: lineName, color: hexColor, stations: stationSequence)
        network.lines.append(newLine)
        dismiss()
    }
}
