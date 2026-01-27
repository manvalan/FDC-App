import SwiftUI

struct TrainRelationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var network: RailwayNetwork
    
    // If nil, we are creating a new relation for the specific line
    var line: RailwayLine
    @State var relation: TrainRelation?
    
    // Binding for creating new relation
    var onSave: (TrainRelation) -> Void
    
    // Editing State
    @State private var name: String = ""
    @State private var originId: String = ""
    @State private var destinationId: String = ""
    @State private var stops: [RelationStop] = [] 
    @State private var createOpposite: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dettagli Relazione")) {
                    TextField("Nome Relazione (es. Milano-Roma)", text: $name)
                    
                    Picker("Origine", selection: $originId) {
                        Text("Seleziona...").tag("")
                        ForEach(line.stations, id: \.self) { stationId in
                            Text(stationName(stationId)).tag(stationId)
                        }
                    }
                    .onChange(of: originId) { _ in updateRoute() }
                    
                    Picker("Destinazione", selection: $destinationId) {
                        Text("Seleziona...").tag("")
                        ForEach(line.stations, id: \.self) { stationId in
                            Text(stationName(stationId)).tag(stationId)
                        }
                    }
                    .onChange(of: destinationId) { _ in updateRoute() }
                }
                
                Section(header: Text("Fermate (\(stops.count))")) {
                    if stops.isEmpty {
                        Text("Seleziona Origine e Destinazione per calcolare le fermate.").foregroundColor(.secondary)
                    } else {
                        List {
                            ForEach($stops) { $stop in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "circle.fill").font(.caption2).foregroundColor(.blue)
                                        Text(stationName(stop.stationId)).font(.headline)
                                        Spacer()
                                    }
                                    
                                    // Dwell Time Editor
                                    if !stop.isSkipped {
                                        HStack {
                                            Text("Sosta (min):")
                                            Stepper("\(stop.minDwellTime)", value: $stop.minDwellTime, in: 0...120) // Allowed 0
                                        }
                                        .font(.subheadline)
                                    } else {
                                        Text("Transito").font(.caption).italic().foregroundColor(.secondary)
                                    }
                                    
                                    Toggle("Ferma qui", isOn: Binding(
                                        get: { !stop.isSkipped },
                                        set: { stop.isSkipped = !$0 }
                                    ))
                                    .font(.caption)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete { idx in
                                stops.remove(atOffsets: idx)
                            }
                        }
                        Text("Puoi rimuovere le fermate o modificare i tempi di sosta (min. 3 min).").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                if relation == nil { // Only for new relations
                    Section {
                        Toggle("Crea anche relazione di ritorno (B -> A)", isOn: $createOpposite)
                    }
                }
                
                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle(relation == nil ? "Nuova Relazione" : "Modifica Relazione")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveRelation()
                    }
                    .disabled(name.isEmpty || originId.isEmpty || destinationId.isEmpty || stops.count < 2)
                }
            }
            .onAppear {
                if let existing = relation {
                    name = existing.name
                    originId = existing.originId
                    destinationId = existing.destinationId
                    stops = existing.stops
                }
            }
        }
    }
    
    private func stationName(_ id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? id
    }
    
    private func updateRoute() {
        guard !originId.isEmpty, !destinationId.isEmpty else { return }
        
        // Find path on the LINE (just sub-array)
        guard let startIdx = line.stations.firstIndex(of: originId),
              let endIdx = line.stations.firstIndex(of: destinationId) else {
            errorMessage = "Stazioni non trovate sulla linea."
            return
        }
        
        errorMessage = nil
        
        var stations: [String] = []
        // Determine direction
        if startIdx <= endIdx {
            stations = Array(line.stations[startIdx...endIdx])
        } else {
            stations = Array(line.stations[endIdx...startIdx].reversed())
        }
        
        // Convert to RelationStop
        // Preserve existing edits if station present? Too complex for now. Resetting.
        stops = stations.map { RelationStop(stationId: $0, minDwellTime: 3, track: "1") }
        
        // Auto-name if empty
        if name.isEmpty {
            let startName = stationName(originId)
            let endName = stationName(destinationId)
            name = "\(startName) - \(endName)"
        }
    }
    
    private func saveRelation() {
        let newRel = TrainRelation(
            id: relation?.id ?? UUID(),
            lineId: line.id,
            name: name,
            originId: originId,
            destinationId: destinationId,
            stops: stops
        )
        onSave(newRel)
        
        if createOpposite && relation == nil {
             let reverseStops = stops.reversed().map { stop in
                var newStop = stop
                newStop.id = UUID() 
                return newStop
            }
            let startName = stationName(destinationId)
            let endName = stationName(originId)
            let reverseName = "\(startName) - \(endName)"
            
            let reverseRel = TrainRelation(
                id: UUID(),
                lineId: line.id,
                name: reverseName,
                originId: destinationId, // Swapped
                destinationId: originId, // Swapped
                stops: Array(reverseStops)
            )
            onSave(reverseRel)
        }
        
        dismiss()
    }
}
