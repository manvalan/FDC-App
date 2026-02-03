import SwiftUI
import Combine

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
                Text("train_not_found".localized).foregroundColor(.secondary)
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
                            TextField("number_label".localized, value: train.number, format: .number)
                                .font(.title2).bold()
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("train_name".localized, text: train.name)
                                .font(.title2).bold()
                        }
                        
                        Picker("type_label".localized, selection: train.type) {
                            Text("regional_type".localized).tag("Regionale")
                            Text("direct_type".localized).tag("Diretto")
                            Text("high_speed_type".localized).tag("Alta Velocità")
                            Text("merci_type".localized).tag("Merci")
                            Text("support_type".localized).tag("Supporto")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
                
                Divider()
                
                // Scheduling
                Section("timetable_itinerary".localized) {
                    DatePicker("departure_time".localized, selection: Binding(
                        get: { train.wrappedValue.departureTime ?? Date() },
                        set: { train.wrappedValue.departureTime = $0 }
                    ), displayedComponents: .hourAndMinute)
                    
                    if let lineId = train.wrappedValue.lineId, 
                       let line = network.lines.first(where: { $0.id == lineId }) {
                        
                        Divider()
                        Text(String(format: "line_label_fmt".localized, line.name)).font(.headline)
                        
                        RailwayItineraryView(
                            stations: train.wrappedValue.stops.map { $0.stationId },
                            network: network,
                            trainStops: train.wrappedValue.stops,
                            lineColor: Color(hex: line.color ?? "")
                        )
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // Schedule Table with Binding to Train's Own Stops (for editing)
                        ScheduleView(train: train, line: line, network: network)
                    } else {
                        Text("no_line_assigned".localized).italic().foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Technical Specs
                Section("technical_data".localized) {
                    HStack {
                        Text("max_speed".localized)
                        Spacer()
                        TextField("kmh_placeholder".localized, value: train.maxSpeed, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        Text("km/h")
                    }
                    HStack {
                        Text("acceleration".localized)
                        Spacer()
                        Text(String(format: "acceleration_val_fmt".localized, train.wrappedValue.acceleration))
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
                type: isOrigin ? "departure_marker".localized : (isDestination ? "arrival_marker".localized : (stop.isSkipped || stop.minDwellTime == 0 ? "transit_marker".localized : "stop_marker".localized)),
                stopIndex: index,
                currentTrack: stop.track
            ))
        }
        
        return rows
    }
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("station_label".localized).bold()
                Text("arr_label".localized).bold()
                Text("sos_label".localized).bold()
                Text("par_label".localized).bold()
                Text("bin_label".localized).bold()
            }
            Divider()
            ForEach(schedule) { row in
                GridRow {
                    HStack {
                        if row.type == "departure_marker".localized { Image(systemName: "flag.fill").foregroundColor(.green) }
                        else if row.type == "arrival_marker".localized { Image(systemName: "flag.checkered").foregroundColor(.red) }
                        else if row.type == "transit_marker".localized { Image(systemName: "arrow.right").foregroundColor(.gray) }
                        else { Image(systemName: "circle.fill").font(.caption2) }
                        Text(row.stationName)
                    }
                    
                    // Arrival
                    if let arr = row.arrival, let idx = row.stopIndex, row.index > 0 {
                        Button(action: { prepareEdit(idx) }) {
                            HStack(spacing: 2) {
                                if train.stops[idx].plannedArrival != nil { Image(systemName: "clock.fill").font(.system(size: 8)) }
                                Text(format(arr))
                                    .underline(train.stops[idx].plannedArrival != nil)
                            }
                        }
                    } else {
                        Text("-").foregroundColor(.secondary)
                    }
                    
                    // Sosta (Dwell)
                    if let idx = row.stopIndex {
                        let stop = train.stops[idx]
                        if idx > 0 && idx < train.stops.count - 1 {
                            if stop.minDwellTime == 0 {
                                Text("transit_marker".localized).foregroundColor(.gray).italic()
                            } else if !stop.isSkipped {
                                Text(String(format: "dwell_time_min".localized, stop.minDwellTime))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("-").foregroundColor(.secondary)
                            }
                        } else {
                            Text("-").foregroundColor(.secondary)
                        }
                    }
                    
                    // Departure
                    if let dep = row.departure, let idx = row.stopIndex, row.index < schedule.count - 1 {
                         Button(action: { prepareEdit(idx) }) {
                             HStack(spacing: 2) {
                                if train.stops[idx].plannedDeparture != nil { Image(systemName: "clock.fill").font(.system(size: 8)) }
                                Text(format(dep))
                                    .underline()
                                    .foregroundColor(.blue)
                             }
                         }
                    } else {
                        Text("-").foregroundColor(.secondary)
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
                    Section("edit_stop".localized) {
                        TextField("track_label".localized, text: $editTrack)
                        
                        let isTerminus = stopIdx == 0 || stopIdx == train.stops.count - 1
                        if !isTerminus {
                            Toggle("service_stop".localized, isOn: Binding(
                                get: { editDwell > 0 },
                                set: { if $0 { editDwell = 3 } else { editDwell = 0 } }
                            ))
                            
                            if editDwell > 0 {
                                Stepper(String(format: "min_dwell_val".localized, editDwell), value: $editDwell, in: 1...120)
                            } else {
                                Text("transit_desc".localized).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Section("planned_timetables".localized) {
                        Toggle("planned_arrival".localized, isOn: Binding(
                            get: { editPlannedArr != nil },
                            set: { if $0 { editPlannedArr = train.stops[stopIdx].arrival ?? Date() } else { editPlannedArr = nil } }
                        ))
                        if let arr = editPlannedArr {
                            DatePicker("arrival_time".localized, selection: Binding(get: { arr }, set: { editPlannedArr = $0 }), displayedComponents: .hourAndMinute)
                        }
                        
                        Toggle("planned_departure".localized, isOn: Binding(
                            get: { editPlannedDep != nil },
                            set: { if $0 { editPlannedDep = train.stops[stopIdx].departure ?? Date() } else { editPlannedDep = nil } }
                        ))
                        if let dep = editPlannedDep {
                            DatePicker("departure_time".localized, selection: Binding(get: { dep }, set: { editPlannedDep = $0 }), displayedComponents: .hourAndMinute)
                        }
                    }
                }
                .navigationTitle("edit_stop".localized)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("save".localized) {
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
