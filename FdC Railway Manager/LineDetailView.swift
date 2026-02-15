import SwiftUI

struct LineDetailView: View {
    @Binding var line: RailwayLine
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var appState: AppState
    @Binding var isMoveModeEnabled: Bool
    @Binding var selectedNode: Node?
    @Binding var selectedEdgeId: String?
    
    @State private var showScheduleCreator = false
    @State private var showFleetManager = false
    
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: line.color ?? "") ?? .black },
            set: { if let hex = $0.toHex() { line.color = hex } }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Identification
                VStack(alignment: .leading, spacing: 8) {
                    Text("identification".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    TextField("line_name_placeholder".localized, text: $line.name)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("color_label".localized)
                        Spacer()
                        ColorPicker("", selection: colorBinding)
                            .labelsHidden()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 2. Numbering
                VStack(alignment: .leading, spacing: 8) {
                    Text("train_numbering".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("prefix".localized).font(.caption2)
                            TextField("RE", text: Binding(
                                get: { line.codePrefix ?? "" },
                                set: { line.codePrefix = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("code".localized).font(.caption2)
                            TextField("5", value: Binding(
                                get: { line.numberPrefix ?? 0 },
                                set: { line.numberPrefix = $0 == 0 ? nil : $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        }
                    }
                    
                    Text(String(format: "numbering_example".localized, line.codePrefix ?? "RE", line.numberPrefix ?? 5))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 3. Diagram
                VStack(alignment: .leading, spacing: 12) {
                    Text("vertical_diagram".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    VerticalTrackDiagramView(
                        line: $line,
                        network: network,
                        isMoveModeEnabled: $isMoveModeEnabled,
                        externalSelectedStationID: Binding(
                            get: { selectedNode?.id },
                            set: { id in
                                if let id = id {
                                    selectedNode = network.nodes.first(where: { $0.id == id })
                                } else {
                                    selectedNode = nil
                                }
                            }
                        ),
                        externalSelectedEdgeID: $selectedEdgeId,
                        isSidebarEditMode: $appState.isInspectorEditingMode
                    )
                    .frame(minHeight: 400)
                    .cornerRadius(8)
                }
                
                // 4. Dwell Times & Tracks
                VStack(alignment: .leading, spacing: 12) {
                    Text("tracks_dwells".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach($line.stops) { $stop in
                        HStack {
                            Text(stopName(stop.stationId))
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("track_label_short".localized, text: Binding(
                                get: { stop.track ?? "" },
                                set: { stop.track = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            
                            Spacer()
                            
                            Stepper(String(format: "dwell_time_min".localized, stop.minDwellTime), value: $stop.minDwellTime, in: 0...120)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 5. Fleet / Rolling Stock
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("materiale_rotabile".localized.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        let unassignedTrains = appState.railroad.lines.trains.filter({ $0.lineId == line.id && $0.vehicleId == nil })
                        if !unassignedTrains.isEmpty {
                            Text("\(unassignedTrains.count) Da Assegnare")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Button(action: { showFleetManager = true }) {
                        HStack {
                            Image(systemName: "tram.fill")
                            Text("Gestione Assegnazioni Flotta")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 6. Actions
                Button(action: { 
                    appState.startTrainCreation(lineId: line.id)
                }) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                        Text("generate_schedule".localized)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding()
            .disabled(!appState.isInspectorEditingMode)
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            appState.isInspectorEditingMode.toggle()
        }
        .sheet(isPresented: $showFleetManager) {
            LineFleetManagementView(line: line, manager: appState.railroad.lines)
        }
    }
     
     private func stopName(_ id: String) -> String {
         network.nodes.first(where: { $0.id == id })?.name ?? id
     }
}

struct LineFleetManagementView: View {
    let line: RailwayLine
    @ObservedObject var manager: LinesManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            LineFleetManagementContent(line: line, manager: manager)
                .navigationTitle("Gestione Flotta: \(line.name)")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Chiudi") { dismiss() }
                    }
                }
        }
    }
}

struct LineFleetManagementContent: View {
    let line: RailwayLine
    @ObservedObject var manager: LinesManager
    @State private var showUnassignedOnly = true
    @State private var showingAddVehicle = false
    
    var body: some View {
        List {
            Section {
                Toggle("Mostra solo treni non assegnati", isOn: $showUnassignedOnly)
            }
            
            let trains = manager.trains.filter { 
                $0.lineId == line.id && 
                (!showUnassignedOnly || $0.vehicleId == nil)
            }.sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
            
            if trains.isEmpty {
                Text("Nessun treno da visualizzare.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(trains) { train in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(train.name).bold()
                            if let dep = train.departureTime {
                                Text("Partenza: \(dep.timeFormat)").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button("Rimuovi Assegnazione", role: .destructive) {
                                if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
                                    manager.trains[idx].vehicleId = nil
                                }
                            }
                            Divider()
                            
                            // Group vehicles by Model
                            let groupedVehicles = Dictionary(grouping: manager.vehicles, by: { $0.model })
                            let sortedModels = groupedVehicles.keys.sorted()
                            
                            ForEach(sortedModels, id: \.self) { model in
                                Section(header: Text(model)) { 
                                    if let modelVehicles = groupedVehicles[model] {
                                        ForEach(modelVehicles) { v in
                                            Button(v.name) {
                                                if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
                                                    manager.trains[idx].vehicleId = v.id
                                                    manager.trains[idx].maxSpeed = v.maxSpeed
                                                    manager.trains[idx].acceleration = v.acceleration
                                                    manager.trains[idx].deceleration = v.deceleration
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            if let vId = train.vehicleId, let v = manager.vehicles.first(where: { $0.id == vId }) {
                                HStack {
                                    Text(v.name)
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            } else {
                                Text("Assegna")
                                    .bold()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(6)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button(action: { showingAddVehicle = true }) {
                        Label("Nuovo Mezzo", systemImage: "plus.circle")
                    }
                    Button("Auto-Assegna") {
                        manager.autoAssignRollingStock(for: line.id)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddVehicle) {
            VehicleEditSheet(manager: manager, vehicle: nil)
        }
    }
}
