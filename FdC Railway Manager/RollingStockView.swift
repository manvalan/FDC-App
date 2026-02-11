import SwiftUI

struct RollingStockView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var manager: LinesManager
    
    @State private var showingAddSheet = false
    @State private var editingVehicle: Vehicle? = nil
    
    init(manager: LinesManager) {
        self.manager = manager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("materiale_rotabile".localized)
                    .font(.title2).bold()
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            List {
                ForEach(manager.vehicles) { vehicle in
                    VehicleRow(vehicle: vehicle, trains: manager.trains.filter { $0.vehicleId == vehicle.id })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingVehicle = vehicle
                        }
                }
                .onDelete(perform: deleteVehicles)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VehicleEditSheet(manager: manager, vehicle: nil)
        }
        .sheet(item: $editingVehicle) { vehicle in
            VehicleEditSheet(manager: manager, vehicle: vehicle)
        }
    }
    
    private func deleteVehicles(at offsets: IndexSet) {
        // First unassign trains
        for index in offsets {
            let vId = manager.vehicles[index].id
            for tIdx in manager.trains.indices {
                if manager.trains[tIdx].vehicleId == vId {
                    manager.trains[tIdx].vehicleId = nil
                }
            }
        }
        manager.vehicles.remove(atOffsets: offsets)
    }
}

struct VehicleRow: View {
    let vehicle: Vehicle
    let trains: [Train]
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(modelColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "train.side.front.car")
                    .foregroundColor(modelColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(vehicle.name)
                        .font(.headline)
                    Spacer()
                    Text(vehicle.model)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modelColor.opacity(0.15))
                        .foregroundColor(modelColor)
                        .cornerRadius(4)
                }
                
                HStack(spacing: 12) {
                    Label("\(Int(vehicle.length))m", systemImage: "arrow.left.and.right")
                    Label("\(Int(vehicle.maxSpeed)) km/h", systemImage: "gauge.with.dots.needle.67percent")
                    
                    let conflicts = manager.getVehicleConflicts(for: vehicle.id)
                    if !conflicts.isEmpty {
                        Label("\(conflicts.count) conflitti", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                
                if trains.isEmpty {
                    Text("Nessun treno assegnato")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                        .italic()
                } else {
                    let sorted = trains.sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(sorted) { train in
                                Text(train.name)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var modelColor: Color {
        let m = vehicle.model.lowercased()
        if m.contains("coradia") || m.contains("pop") || m.contains("jazz") || m.contains("minuetto") { return .blue }
        if m.contains("caravaggio") || m.contains("rock") { return .orange }
        if m.contains("pesa") || m.contains("swing") { return .green }
        if m.contains("stadler") || m.contains("colleoni") { return .red }
        if m.contains("navetta") { return .purple }
        return .secondary
    }
}

struct VehicleEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var manager: LinesManager
    
    let vehicle: Vehicle?
    
    @State private var name: String = ""
    @State private var model: String = ""
    @State private var length: Double = 200
    @State private var maxSpeed: Double = 160
    @State private var selectedTemplateId: String? = nil
    
    init(manager: LinesManager, vehicle: Vehicle?) {
        self.manager = manager
        self.vehicle = vehicle
        _name = State(initialValue: vehicle?.name ?? "")
        _model = State(initialValue: vehicle?.model ?? appState.lastVehicleModel)
        _length = State(initialValue: vehicle?.length ?? appState.lastVehicleLength)
        _maxSpeed = State(initialValue: vehicle?.maxSpeed ?? appState.lastVehicleMaxSpeed)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Template Modello") {
                    Picker("Scegli Template", selection: $selectedTemplateId) {
                        Text("Manuale / Nessuno").tag(String?.none)
                        Divider()
                        ForEach(VehicleTemplate.all) { template in
                            Text(template.name).tag(String?.some(template.id))
                        }
                    }
                    .onChange(of: selectedTemplateId) { old, newValue in
                        if let tid = newValue, let template = VehicleTemplate.all.first(where: { $0.id == tid }) {
                            self.model = template.model
                            self.length = template.length
                            self.maxSpeed = template.maxSpeed
                            if self.name.isEmpty {
                                self.name = template.name
                            }
                        }
                    }
                }

                Section("Informazioni Generali") {
                    TextField("Matricola / Nome", text: $name)
                    TextField("Modello Tecnico", text: $model)
                }
                
                if let v = vehicle {
                    Section("Turno Materiale (Treni Assegnati)") {
                        let attachedTrains = manager.trains.filter { $0.vehicleId == v.id }
                            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
                        
                        if attachedTrains.isEmpty {
                            Text("Nessun treno assegnato a questo mezzo.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(attachedTrains) { train in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(train.name).font(.subheadline).bold()
                                    HStack(spacing: 8) {
                                        if let dep = train.departureTime {
                                            Text("Part: \(dep.timeFormat)").font(.caption2)
                                        }
                                        if let arr = train.stops.last?.arrival {
                                            Text("Arr: \(arr.timeFormat)").font(.caption2)
                                        }
                                    }
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(role: .destructive, action: {
                                    if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
                                        manager.trains[idx].vehicleId = nil
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        NavigationLink {
                            TrainSelectionPicker(vehicleId: v.id)
                        } label: {
                            Label("Assegna nuovo treno", systemImage: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                Section("Specifiche Tecniche") {
                    HStack {
                        Text("Lunghezza (m)")
                        Spacer()
                        TextField("", value: $length, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Velocità Max (km/h)")
                        Spacer()
                        TextField("", value: $maxSpeed, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
            }
            .navigationTitle(vehicle == nil ? "Nuovo Mezzo" : "Modifica Mezzo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private func save() {
        if var existing = vehicle {
            existing.name = name
            existing.model = model
            existing.length = length
            existing.maxSpeed = maxSpeed
            if let idx = manager.vehicles.firstIndex(where: { $0.id == existing.id }) {
                manager.vehicles[idx] = existing
            }
        } else {
            let newV = Vehicle(name: name, model: model, length: length, maxSpeed: maxSpeed)
            manager.vehicles.append(newV)
        }
        
        // Persist as last used
        appState.lastVehicleModel = model
        appState.lastVehicleLength = length
        appState.lastVehicleMaxSpeed = maxSpeed
    }
}

struct TrainSelectionPicker: View {
    let vehicleId: UUID
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    @Environment(\.dismiss) var dismiss
    
    @State private var useSmartFilter: Bool = true
    
    private var lastStationId: String? {
        let vehicleTrains = manager.trains.filter { $0.vehicleId == vehicleId && $0.departureTime != nil }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
        return vehicleTrains.last?.stops.last?.stationId
    }
    
    private var lastStationName: String {
        guard let id = lastStationId else { return "Nessuna" }
        return appState.railroad.network.nodes.first(where: { $0.id == id })?.name ?? id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Header
            Picker("Filtra per Linea", selection: $appState.lastVehicleAssignmentLineId) {
                Text("Tutti i treni disponibili").tag(String?.none)
                Divider()
                ForEach(manager.sortedLines) { line in
                    Text(line.name).tag(String?.some(line.id))
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            List {
                let filteredTrains = manager.trains.filter { train in
                    let isAvailable = train.vehicleId == nil
                    let matchesLine = appState.lastVehicleAssignmentLineId == nil || train.lineId == appState.lastVehicleAssignmentLineId
                    
                    var matchesSmart = true
                    if useSmartFilter, let lastPos = lastStationId {
                        matchesSmart = train.stops.first?.stationId == lastPos
                    }
                    
                    return isAvailable && matchesLine && matchesSmart
                }
                
                if let lastPos = lastStationId {
                    Section {
                        Toggle(isOn: $useSmartFilter) {
                            VStack(alignment: .leading) {
                                Text("Filtro intelligente").font(.subheadline).bold()
                                Text("Mostra solo treni partenti da \(lastStationName)")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if filteredTrains.isEmpty {
                    Section {
                        Text(appState.lastVehicleAssignmentLineId == nil ? "Tutti i treni hanno già un mezzo assegnato." : "Nessun treno disponibile per la linea selezionata.")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding()
                    }
                } else {
                    Section {
                        ForEach(filteredTrains) { train in
                            let conflictsWithNew = checkPotentialConflict(train: train)
                            Button(action: {
                                if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
                                    manager.trains[idx].vehicleId = vehicleId
                                }
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(train.name).font(.headline)
                                            if let line = manager.lines.first(where: { $0.id == train.lineId }) {
                                                Text(line.name).font(.system(size: 9)).foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(train.type).font(.caption2).padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
                                    }
                                    
                                    // Origin and Destination with Time
                                    HStack(spacing: 4) {
                                        let originId = train.stops.first?.stationId ?? ""
                                        let originName = appState.railroad.network.nodes.first(where: { $0.id == originId })?.name ?? originId
                                        let isAtLastPos = originId == lastStationId
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.right.circle.fill")
                                            Text(originName)
                                                .fontWeight(isAtLastPos ? .bold : .regular)
                                        }
                                        .foregroundColor(isAtLastPos ? .green : .primary)
                                        
                                        Text("→").foregroundColor(.secondary)
                                        
                                        let destId = train.stops.last?.stationId ?? ""
                                        let destName = appState.railroad.network.nodes.first(where: { $0.id == destId })?.name ?? destId
                                        Text(destName)
                                        
                                        Spacer()
                                        
                                        if let dep = train.departureTime {
                                            Text(dep.timeFormat).font(.system(size: 10, weight: .bold, design: .monospaced))
                                        }
                                    }
                                    .font(.system(size: 11))
                                    
                                    if let conflict = conflictsWithNew {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                            Text(conflict).font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(.red)
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Assegna Treno")
    }

    private func checkPotentialConflict(train: Train) -> String? {
        // Find existing trains for this vehicle
        let existing = manager.trains.filter { $0.vehicleId == vehicleId && $0.departureTime != nil }
        
        guard let newDep = train.departureTime else { return nil }
        
        // We also need the arrival time of the new train to check vs. future existing trains
        // But for simplicity, let's just check against the train immediately before/after in time
        
        for ex in existing {
            if let exArr = ex.stops.last?.arrival, let exDep = ex.departureTime {
                // If the new train starts before an existing one arrives
                if newDep < exArr.addingTimeInterval(15 * 60) && newDep > exDep.addingTimeInterval(-15 * 60) {
                    return "In conflitto con \(ex.name) (Arr: \(exArr.timeFormat))"
                }
                
                // If an existing train starts before the new one arrives
                if let newArr = train.stops.last?.arrival {
                    if exDep < newArr.addingTimeInterval(15 * 60) && exDep > newDep.addingTimeInterval(-15 * 60) {
                        return "In conflitto con \(ex.name) (Parte: \(exDep.timeFormat))"
                    }
                }
            }
        }
        
        return nil
    }
}
