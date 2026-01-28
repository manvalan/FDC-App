import SwiftUI

struct TrainDetailView: View {
    let train: Train
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    
    // Binding helper
    private var trainBinding: Binding<Train>? {
        guard let index = manager.trains.firstIndex(where: { $0.id == train.id }) else { return nil }
        return $manager.trains[index]
    }
    
    var body: some View {
        Group {
            if let binding = trainBinding {
                content(train: binding)
            } else {
                Text("Treno non trovato").foregroundColor(.secondary)
            }
        }
    }
    
    func content(train: Binding<Train>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header & Basic Info
                HStack {
                    Image(systemName: "train.side.front.car")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Numero", value: train.number, format: .number)
                                .font(.title2).bold()
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("Nome Treno", text: train.name)
                                .font(.title2).bold()
                        }
                        
                        Picker("Tipo", selection: train.type) {
                            Text("Regionale").tag("Regionale")
                            Text("Diretto").tag("Diretto")
                            Text("Alta Velocità").tag("Alta Velocità")
                            Text("Merci").tag("Merci")
                            Text("Supporto").tag("Supporto")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
                
                Divider()
                
                // Scheduling
                Section("Orario") {
                    DatePicker("Orario Partenza", selection: Binding(
                        get: { train.wrappedValue.departureTime ?? Date() },
                        set: { train.wrappedValue.departureTime = $0 }
                    ), displayedComponents: .hourAndMinute)
                    
                    if let lineId = train.wrappedValue.lineId, 
                       let lineIndex = network.lines.firstIndex(where: { $0.id == lineId }) {
                        
                        Text("Linea: \(network.lines[lineIndex].name)").font(.headline)
                        
                        // Schedule Table with Binding to Train's Own Stops
                        ScheduleView(train: train, line: network.lines[lineIndex], network: network)
                    } else {
                        Text("Nessuna linea assegnata").italic().foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Technical Specs
                Section("Dati Tecnici") {
                    HStack {
                        Text("Velocità Max")
                        Spacer()
                        TextField("km/h", value: train.maxSpeed, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        Text("km/h")
                    }
                    HStack {
                        Text("Accelerazione")
                        Spacer()
                        Text(String(format: "%.2f m/s²", train.wrappedValue.acceleration))
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// Subview for Schedule Calculation
struct ScheduleView: View {
    @Binding var train: Train
    let line: RailwayLine // Now reference only
    @ObservedObject var network: RailwayNetwork
    
    struct ScheduleRow: Identifiable {
        let id = UUID()
        let index: Int // Index in relation.stops (or -1 for origin/dest)
        let stationName: String
        let arrival: Date?
        let departure: Date?
        let type: String 
        let stopIndex: Int? // Index in relation.stops array if it edits a stop
        let currentTrack: String?
    }
    
    // Auxiliary State for Sheet editing
    @State private var editingStopIndex: Int? = nil
    @State private var editTrack: String = ""
    @State private var editDwell: Int = 3
    @State private var editPlannedArr: Date? = nil
    @State private var editPlannedDep: Date? = nil
    
    var schedule: [ScheduleRow] {
        var rows: [ScheduleRow] = []
        
        for (index, stop) in train.stops.enumerated() {
            let isOrigin = (index == 0)
            let isDestination = (index == train.stops.count - 1)
            let nodeName = network.nodes.first(where: { $0.id == stop.stationId })?.name ?? stop.stationId
            
            rows.append(ScheduleRow(
                index: index,
                stationName: nodeName,
                arrival: stop.arrival,
                departure: stop.departure,
                type: isOrigin ? "Partenza" : (isDestination ? "Arrivo" : (stop.isSkipped ? "Transito" : "Fermata")),
                stopIndex: index,
                currentTrack: stop.track
            ))
        }
        
        return rows
    }
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Stazione").bold()
                Text("Arr").bold()
                Text("Sos").bold()
                Text("Par").bold()
                Text("Bin").bold()
            }
            Divider()
            ForEach(schedule) { row in
                GridRow {
                    HStack {
                        if row.type == "Partenza" { Image(systemName: "flag.fill").foregroundColor(.green) }
                        else if row.type == "Arrivo" { Image(systemName: "flag.checkered").foregroundColor(.red) }
                        else if row.type == "Transito" { Image(systemName: "arrow.right").foregroundColor(.gray) }
                        else { Image(systemName: "circle.fill").font(.caption2) }
                        Text(row.stationName)
                    }
                    
                    // Arrival
                    if let arr = row.arrival, let idx = row.stopIndex {
                        Button(action: { prepareEdit(idx) }) {
                            HStack(spacing: 2) {
                                if train.stops[idx].plannedArrival != nil { Image(systemName: "clock.fill").font(.system(size: 8)) }
                                Text(format(arr))
                                    .underline(train.stops[idx].plannedArrival != nil)
                            }
                        }
                    } else {
                        Text(format(row.arrival))
                    }
                    
                    // Sosta (Dwell)
                    if let idx = row.stopIndex {
                        let stop = train.stops[idx]
                        if !stop.isSkipped && idx > 0 && idx < train.stops.count - 1 {
                            Text("\(stop.minDwellTime)m")
                                .foregroundColor(.secondary)
                        } else {
                            Text("-").foregroundColor(.secondary)
                        }
                    }
                    
                    // Departure
                    if let dep = row.departure, let idx = row.stopIndex {
                         Button(action: { prepareEdit(idx) }) {
                             HStack(spacing: 2) {
                                if train.stops[idx].plannedDeparture != nil { Image(systemName: "clock.fill").font(.system(size: 8)) }
                                Text(format(dep))
                                    .underline()
                                    .foregroundColor(.blue)
                             }
                         }
                    } else {
                        Text(format(row.departure))
                    }
                    
                    // Track
                    if let idx = row.stopIndex {
                         Button(action: { prepareEdit(idx) }) {
                             if let t = row.currentTrack, !t.isEmpty {
                                 Text(t).padding(4).background(Color.orange.opacity(0.2)).cornerRadius(4)
                             } else {
                                 Text("1").foregroundColor(.secondary).italic()
                             }
                         }
                    } else {
                        Text("-")
                    }
                }
                .font(.callout)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.5))
        .cornerRadius(8)
        .sheet(item: $editingStopIndex) { stopIdx in
            NavigationStack {
                Form {
                    Section("Modifica Fermata") {
                        TextField("Binario", text: $editTrack)
                        Stepper("Sosta Minima: \(editDwell) min", value: $editDwell, in: 0...120)
                    }
                    
                    Section("Orari Pianificati (Vincoli)") {
                        Toggle("Arrivo Pianificato", isOn: Binding(
                            get: { editPlannedArr != nil },
                            set: { if $0 { editPlannedArr = train.stops[stopIdx].arrival ?? Date() } else { editPlannedArr = nil } }
                        ))
                        if let arr = editPlannedArr {
                            DatePicker("Ora Arrivo", selection: Binding(get: { arr }, set: { editPlannedArr = $0 }), displayedComponents: .hourAndMinute)
                        }
                        
                        Toggle("Partenza Pianificata", isOn: Binding(
                            get: { editPlannedDep != nil },
                            set: { if $0 { editPlannedDep = train.stops[stopIdx].departure ?? Date() } else { editPlannedDep = nil } }
                        ))
                        if let dep = editPlannedDep {
                            DatePicker("Ora Partenza", selection: Binding(get: { dep }, set: { editPlannedDep = $0 }), displayedComponents: .hourAndMinute)
                        }
                    }
                }
                .navigationTitle("Modifica Fermata")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") {
                            if stopIdx < train.stops.count {
                                train.stops[stopIdx].minDwellTime = editDwell
                                train.stops[stopIdx].track = editTrack.isEmpty ? nil : editTrack
                                train.stops[stopIdx].plannedArrival = editPlannedArr
                                train.stops[stopIdx].plannedDeparture = editPlannedDep
                            }
                            editingStopIndex = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func prepareEdit(_ idx: Int) {
        let stop = train.stops[idx]
        self.editDwell = stop.minDwellTime
        self.editTrack = stop.track ?? ""
        self.editPlannedArr = stop.plannedArrival
        self.editPlannedDep = stop.plannedDeparture
        self.editingStopIndex = idx
    }
    
    func format(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0) // SYNC UTC
        return f.string(from: date)
    }
}
// Helper for Int to be Identifiable for Sheet
extension Int: Identifiable {
    public var id: Int { self }
}

struct MetricView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.subheadline).bold()
        }
    }
}
