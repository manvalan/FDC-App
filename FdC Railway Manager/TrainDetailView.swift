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
                    VStack(alignment: .leading) {
                        TextField("Nome Treno", text: train.name)
                            .font(.title2).bold()
                        Picker("Tipo", selection: train.type) {
                            Text("Regionale").tag("Regionale")
                            Text("Diretto").tag("Diretto")
                            Text("Alta Velocità").tag("Alta Velocità")
                            Text("Merci").tag("Merci")
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
                    
                    if let relId = train.wrappedValue.relationId, 
                       let relIndex = network.relations.firstIndex(where: { $0.id == relId }) {
                        
                        Text("Relazione: \(network.relations[relIndex].name)").font(.headline)
                        
                        // Schedule Table with Binding to Train's Own Stops
                        ScheduleView(train: train, relation: network.relations[relIndex], network: network)
                    } else {
                        Text("Nessuna relazione assegnata").italic().foregroundColor(.secondary)
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
    let relation: TrainRelation // Now reference only
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
    
    var schedule: [ScheduleRow] {
        guard let startTime = train.departureTime else { return [] }
        var rows: [ScheduleRow] = []
        var currentTime = startTime
        
        // 1. Origin
        if let originNode = network.nodes.first(where: { $0.id == relation.originId }) {
            rows.append(ScheduleRow(index: -1, stationName: originNode.name, arrival: nil, departure: currentTime, type: "Partenza", stopIndex: nil, currentTrack: nil))
        }
        
        var previousId = relation.originId
        var destinationReached = false
        
        // 2. Stops (From Train Snapshot)
        for (index, stop) in train.stops.enumerated() {
            if stop.stationId == relation.originId { continue } // Skip if origin duplicated
            
            // Calc travel
            guard let distInfo = network.findShortestPath(from: previousId, to: stop.stationId) else { continue }
            let hours = distInfo.1 / (Double(train.maxSpeed) * 0.9)
            let arrivalTime = currentTime.addingTimeInterval(hours * 3600)
            
            let isDestination = (stop.stationId == relation.destinationId)
            if isDestination { destinationReached = true }
             
            let dwellMinutes = stop.isSkipped ? 0 : Double(stop.minDwellTime)
            let departureTime = isDestination ? nil : arrivalTime.addingTimeInterval(dwellMinutes * 60)
            
            if let node = network.nodes.first(where: { $0.id == stop.stationId }) {
                rows.append(ScheduleRow(
                    index: index,
                    stationName: node.name,
                    arrival: arrivalTime,
                    departure: stop.isSkipped ? nil : departureTime,
                    type: isDestination ? "Arrivo" : (stop.isSkipped ? "Transito" : "Fermata"),
                    stopIndex: index,
                    currentTrack: stop.track
                ))
            }
            
            if let dep = departureTime {
                currentTime = dep
            } else {
                currentTime = arrivalTime
            }
            previousId = stop.stationId
        }
        
        // 3. Destination (if separate)
        if !destinationReached && previousId != relation.destinationId {
             guard let distInfo = network.findShortestPath(from: previousId, to: relation.destinationId) else { return rows }
             let hours = distInfo.1 / (Double(train.maxSpeed) * 0.9)
             let arrivalTime = currentTime.addingTimeInterval(hours * 3600)
             
             if let dest = network.nodes.first(where: { $0.id == relation.destinationId }) {
                 rows.append(ScheduleRow(index: -99, stationName: dest.name, arrival: arrivalTime, departure: nil, type: "Arrivo", stopIndex: nil, currentTrack: nil))
             }
        }
        
        return rows
    }
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Stazione").bold()
                Text("Arr").bold()
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
                    
                    Text(format(row.arrival))
                    
                    // Editable Departure
                    if let dep = row.departure, let idx = row.stopIndex {
                         Button(action: {
                             // Open Edit Sheet
                             self.editDwell = train.stops[idx].minDwellTime
                             self.editTrack = train.stops[idx].track ?? ""
                             self.editingStopIndex = idx
                         }) {
                             Text(format(dep))
                                 .underline()
                                 .foregroundColor(.blue)
                         }
                    } else {
                        Text(format(row.departure))
                    }
                    
                    // Editable Track
                    if let idx = row.stopIndex {
                         Button(action: {
                             self.editDwell = train.stops[idx].minDwellTime
                             self.editTrack = train.stops[idx].track ?? ""
                             self.editingStopIndex = idx
                         }) {
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
                        Stepper("Sosta: \(editDwell) min", value: $editDwell, in: 0...120)
                    }
                }
                .navigationTitle("Modifica")
                .toolbar {
                    Button("Salva") {
                        // Update Train Snapshot
                        if stopIdx < train.stops.count {
                            train.stops[stopIdx].minDwellTime = editDwell
                            train.stops[stopIdx].track = editTrack.isEmpty ? nil : editTrack
                        }
                        editingStopIndex = nil
                    }
                }
            }
            .presentationDetents([.fraction(0.3)])
        }
    }
    
    func format(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
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
