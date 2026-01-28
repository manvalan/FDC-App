import SwiftUI

enum PickerType: Identifiable {
    case start, via, end, manual
    var id: Int {
        switch self {
        case .start: return 1
        case .via: return 2
        case .end: return 3
        case .manual: return 4
        }
    }
}

struct PathPickerComponent: View {
    @EnvironmentObject var network: RailwayNetwork
    
    @Binding var startStationId: String
    @Binding var viaStationId: String
    @Binding var endStationId: String
    @Binding var stationSequence: [String]
    @Binding var manualAddition: Bool
    
    @State private var alternatives: [(path: [String], distance: Double, description: String)] = []
    @State private var selectedAlternativeIndex: Int? = nil
    @State private var errorMessage: String? = nil
    @State var useAutomaticSelection = true
    
    @Binding var activePicker: PickerType?

    var body: some View {
        Group {
            Section(header: Text("Modalità Percorso")) {
                Picker("Metodo", selection: $useAutomaticSelection) {
                    Text("Calcolo Automatico").tag(true)
                    Text("Composizione Manuale").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: useAutomaticSelection) { old, new in
                    manualAddition = !new
                    if !new {
                        stationSequence = startStationId.isEmpty ? [] : [startStationId]
                    }
                }
            }
            
            if useAutomaticSelection {
                Section(header: Text("Definisci Terminal")) {
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
                    
                    HStack {
                        Text("Arrivo")
                        Spacer()
                        Button(action: { activePicker = .end }) {
                            Text(stationName(endStationId))
                                .foregroundColor(endStationId.isEmpty ? .secondary : .primary)
                        }
                    }
                    
                    Button("Calcola Percorsi Proposti") {
                        calculatePath()
                    }
                    .disabled(startStationId.isEmpty || endStationId.isEmpty || startStationId == endStationId)
                    
                    if !alternatives.isEmpty {
                        Picker("Percorso Proposto", selection: $selectedAlternativeIndex) {
                            Text("Seleziona...").tag(Int?.none)
                            ForEach(alternatives.indices, id: \.self) { index in
                                let alt = alternatives[index]
                                Text("\(alt.description) (\(String(format: "%.1f", alt.distance)) km)").tag(Int?.some(index))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedAlternativeIndex) { old, new in
                            if let idx = new {
                                selectAlternative(idx)
                            }
                        }
                    }
                }
            } else {
                Section(header: Text("Punto di Partenza")) {
                    HStack {
                        Text("Stazione di Origine")
                        Spacer()
                        Button(action: { activePicker = .start }) {
                            Text(stationName(startStationId))
                                .foregroundColor(startStationId.isEmpty ? .secondary : .primary)
                        }
                    }
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
        }
        // Removed sheet from here
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
            let results = network.findAlternativePaths(from: startStationId, to: endStationId)
            if results.isEmpty {
                errorMessage = "Nessun percorso trovato."
            } else {
                alternatives = results
                selectedAlternativeIndex = 0
                selectAlternative(0)
            }
        } else {
            let leg1 = network.findAlternativePaths(from: startStationId, to: viaStationId)
            let leg2 = network.findAlternativePaths(from: viaStationId, to: endStationId)
            
            if leg1.isEmpty || leg2.isEmpty {
                errorMessage = "Percorso non trovato via \(stationName(viaStationId))."
                return
            }
            
            var combined: [(path: [String], distance: Double, description: String)] = []
            for l1 in leg1.prefix(2) {
                for l2 in leg2.prefix(2) {
                    let fullPath = l1.path + Array(l2.path.dropFirst())
                    let uniqueNodes = Set(fullPath)
                    if uniqueNodes.count == fullPath.count {
                        combined.append((path: fullPath, distance: l1.distance + l2.distance, description: "Via \(stationName(viaStationId))"))
                    }
                }
            }
            alternatives = combined.sorted(by: { $0.distance < $1.distance })
            if alternatives.isEmpty {
                errorMessage = "Nessun percorso semplice trovato."
            } else {
                selectedAlternativeIndex = 0
                selectAlternative(0)
            }
        }
    }
    
    private func selectAlternative(_ index: Int) {
        let alt = alternatives[index]
        stationSequence = alt.path
    }
}
