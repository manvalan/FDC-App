import SwiftUI

struct TrainCreationView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @Environment(\.dismiss) var dismiss
    
    // If we are creating a train "for a line", we prefill information
    var line: RailwayLine? = nil
    
    @State private var trainNumber: Int = 0
    @State private var trainName: String = ""
    @State private var trainType: String = "Regionale"
    @State private var maxSpeed: Int = 120
    @State private var departureTime: Date = Date()
    
    // Path picking
    @State private var startStationId: String = ""
    @State private var viaStationId: String = ""
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = false
    
    @State private var activePicker: PickerType?
    @State private var manualStationId: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dettagli Treno")) {
                    HStack {
                        Text("Numero")
                        TextField("1234", value: $trainNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("Nome (opzionale)", text: $trainName)
                    
                    Picker("Tipo", selection: $trainType) {
                        Text("Regionale").tag("Regionale")
                        Text("Diretto").tag("Diretto")
                        Text("Alta Velocità").tag("Alta Velocità")
                        Text("Merci").tag("Merci")
                        Text("Supporto").tag("Supporto")
                    }
                    
                    HStack {
                        Text("Velocità Max")
                        TextField("120", value: $maxSpeed, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("km/h")
                    }
                    
                    DatePicker("Partenza", selection: $departureTime, displayedComponents: .hourAndMinute)
                }
                
                PathPickerComponent(
                    startStationId: $startStationId,
                    viaStationId: $viaStationId,
                    endStationId: $endStationId,
                    stationSequence: $stationSequence,
                    manualAddition: $manualAddition,
                    activePicker: $activePicker
                )
                
                Section(header: Text("Sequenza Fermate")) {
                    if stationSequence.isEmpty {
                        Text("Seleziona i terminal o aggiungi manualmente").font(.caption).foregroundColor(.secondary)
                    }
                    
                    ForEach(stationSequence, id: \.self) { id in
                        let node = network.nodes.first(where: { $0.id == id })
                        HStack {
                            Image(systemName: "smallcircle.filled.circle")
                                .foregroundColor(.blue)
                            Text(node?.name ?? id)
                            Spacer()
                            if let node = node {
                                let dwell = (node.type == .interchange) ? 5 : 3
                                Text("\(dwell) min").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { stationSequence.remove(atOffsets: $0) }
                    .onMove { stationSequence.move(fromOffsets: $0, toOffset: $1) }
                    
                    Button(action: { activePicker = .manual }) {
                        Label("Aggiungi fermata manuale", systemImage: "plus.circle")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Nuova Corsa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crea") {
                        saveTrain()
                    }
                    .disabled(stationSequence.count < 2)
                }
            }
            .onAppear {
                if let line = line {
                    trainName = line.name
                    startStationId = line.originId
                    endStationId = line.destinationId
                    stationSequence = line.stops.map { $0.stationId }
                    // Try to guess next number
                    let existing = manager.trains.map { $0.number }
                    trainNumber = (existing.max() ?? 1000) + 1
                }
            }
            .onChange(of: startStationId) { old, new in
                if !new.isEmpty && !manualAddition {
                    stationSequence = [new]
                }
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    stationSequence.append(new)
                    manualStationId = "" // Clear for next one
                }
            }
            .sheet(item: $activePicker) { item in
                Group {
                    switch item {
                    case .start:
                        StationPickerView(selectedStationId: $startStationId, whitelistIds: line?.stations)
                    case .via:
                        StationPickerView(selectedStationId: $viaStationId, whitelistIds: line?.stations)
                    case .end:
                        StationPickerView(selectedStationId: $endStationId, whitelistIds: line?.stations)
                    case .manual:
                        StationPickerView(selectedStationId: $manualStationId, linkedToStationId: stationSequence.last, whitelistIds: line?.stations)
                    }
                }
                .environmentObject(network)
                .environmentObject(manager)
            }
        }
    }
    
    private func saveTrain() {
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        let newTrain = Train(
            id: UUID(),
            number: trainNumber,
            name: trainName.isEmpty ? "Treno \(trainNumber)" : trainName,
            type: trainType,
            maxSpeed: maxSpeed,
            priority: (trainType == "Alta Velocità" ? 10 : (trainType == "Merci" ? 2 : (trainType == "Supporto" ? 3 : 5))),
            lineId: line?.id,
            departureTime: departureTime.normalized(),
            stops: stops
        )
        manager.trains.append(newTrain)
        dismiss()
    }
}
