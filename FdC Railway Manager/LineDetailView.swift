import SwiftUI

struct LineDetailView: View {
    @Binding var line: TrainRoute
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var appState: AppState
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
                        .foregroundColor(appState.theme.medium)
                    
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
                .background(appState.theme.backgroundSecondary)
                .cornerRadius(12)
                
                // 2. Numbering
                VStack(alignment: .leading, spacing: 8) {
                    Text("train_numbering".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(appState.theme.medium)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("prefix".localized).font(.caption2)
                            TextField("RE", text: Binding(
                                get: { line.serviceCodePrefix ?? "" },
                                set: { line.serviceCodePrefix = $0.isEmpty ? nil : $0 }
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
                    
                    Text(String(format: "numbering_example".localized, line.serviceCodePrefix ?? "RE", line.numberPrefix ?? 5))
                        .font(.caption2)
                        .foregroundColor(appState.theme.medium)
                        .italic()
                }
                .padding()
                .background(appState.theme.backgroundSecondary)
                .cornerRadius(12)
                
                // 3. Diagram
                VStack(alignment: .leading, spacing: 12) {
                    Text("vertical_diagram".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(appState.theme.medium)
                    
                    VerticalTrackDiagramView(
                        line: $line,
                        network: network,
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
                    .cornerRadius(12)
                }
                
                // 4. Dwell Times & Tracks
                // Note: Track and dwell time configuration is per-train, not per-route
                // This section is commented out as TrainRoute doesn't contain this data
                // Configure tracks and dwell times when creating individual trains on this route
                
                // 5. Fleet / Rolling Stock
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("materiale_rotabile".localized.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(appState.theme.medium)
                        Spacer()
                        let unassignedTrains = appState.railroad.lines.trains.filter({ $0.routeId == line.id && $0.vehicleId == nil })
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
                        .background(appState.theme.surface)
                        .cornerRadius(12)
                        .shadow(color: appState.theme.line.opacity(0.1), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(appState.theme.backgroundSecondary)
                .cornerRadius(12)
                
                // 6. Actions
                Button(action: { 
                    appState.startTrainCreation(routeId: line.id)
                }) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                        Text("generate_schedule".localized)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(appState.theme.accent)
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
    let line: TrainRoute
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
    @EnvironmentObject var appState: AppState
    let line: TrainRoute
    @ObservedObject var manager: LinesManager
    @State private var showUnassignedOnly = true
    @State private var showingAddVehicle = false
    
    var body: some View {
        List {
            Section {
                Toggle("Mostra solo treni non assegnati", isOn: $showUnassignedOnly)
            }
            
            let trains = manager.trains.filter { 
                $0.routeId == line.id && 
                (!showUnassignedOnly || $0.vehicleId == nil)
            }.sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
            
            if trains.isEmpty {
                Text("Nessun treno da visualizzare.")
                    .foregroundColor(appState.theme.medium)
            } else {
                ForEach(trains) { train in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(train.name).bold().foregroundColor(appState.theme.dark)
                            if let dep = train.departureTime {
                                Text("Partenza: \(dep.timeFormat)").font(.caption).foregroundColor(appState.theme.medium)
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
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(appState.theme.accent)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(appState.theme.accent.opacity(0.1))
                                .cornerRadius(6)
                            } else {
                                Text("Assegna")
                                    .bold()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(appState.theme.accent.opacity(0.1))
                                    .foregroundColor(appState.theme.accent)
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
