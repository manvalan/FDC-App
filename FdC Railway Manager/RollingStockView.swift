import SwiftUI

enum VehicleGroupingMode: String, CaseIterable, Identifiable {
    case byName = "Nome"
    case byManufacturer = "Produttore"
    case byModel = "Modello"
    case byLine = "Linea"
    
    var id: String { rawValue }
}

struct RollingStockView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var manager: LinesManager
    
    @State private var showingAddSheet = false
    @State private var isListEditMode: EditMode = .inactive
    @State private var groupingMode: VehicleGroupingMode = .byName
    
    init(manager: LinesManager) {
        self.manager = manager
    }
    
    private var sortedVehicles: [Vehicle] {
        manager.vehicles.sorted { $0.name < $1.name }
    }
    
    private var manufacturer: String {
        // Extract manufacturer from model
        let model = appState.selectedVehicle?.model.uppercased() ?? ""
        if model.contains("ETR") || model.contains("ALN") { return "Alstom" }
        if model.contains("HTR") || model.contains("TAF") || model.contains("TSR") { return "Hitachi" }
        if model.contains("ATR 803") { return "Stadler" }
        if model.contains("ETR 170") || model.contains("ETR 343") { return "Stadler" }
        if model.contains("ATR 220") || model.contains("SWING") { return "Pesa" }
        if model.contains("E.464") || model.contains("E464") || model.contains("E.494") || model.contains("E.191") || model.contains("E.652") || model.contains("D.445") { return "Locomotive" }
        return "Altro"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Materiale Rotabile").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    showingAddSheet = true
                }) {
                    Label("Nuovo", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Grouping Mode Picker
            Picker("Visualizza per", selection: $groupingMode) {
                ForEach(VehicleGroupingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // List based on grouping mode
            switch groupingMode {
            case .byName:
                vehicleListByName
            case .byManufacturer:
                vehicleListByManufacturer
            case .byModel:
                vehicleListByModel
            case .byLine:
                vehicleListByLine
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VehicleEditSheet(manager: manager, vehicle: nil as RailwayVehicle?)
                .environmentObject(appState)
        }
    }
    
    // MARK: - List Views by Grouping Mode
    
    private var vehicleListByName: some View {
        List {
            ForEach(sortedVehicles) { vehicle in
                VehicleRowContent(vehicle: vehicle, manager: manager)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isListEditMode == .inactive {
                            appState.selectedVehicleId = vehicle.id
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation {
                            isListEditMode = (isListEditMode == .active) ? .inactive : .active
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteVehicles)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $isListEditMode)
    }
    
    private var vehicleListByManufacturer: some View {
        let grouped = Dictionary(grouping: manager.vehicles) { vehicle -> String in
            getManufacturer(for: vehicle.model)
        }
        
        return List {
            ForEach(grouped.keys.sorted(), id: \.self) { manufacturer in
                Section(header: Text(manufacturer).font(.headline).foregroundColor(appState.theme.dark)) {
                    ForEach(grouped[manufacturer]?.sorted { $0.name < $1.name } ?? []) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var vehicleListByModel: some View {
        let grouped = Dictionary(grouping: manager.vehicles, by: { $0.model })
        
        return List {
            ForEach(grouped.keys.sorted(), id: \.self) { model in
                Section(header: Text(model).font(.headline).foregroundColor(appState.theme.dark)) {
                    ForEach(grouped[model]?.sorted { $0.name < $1.name } ?? []) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var vehicleListByLine: some View {
        // Group vehicles by which line's trains they're assigned to
        var grouped: [String: [RailwayVehicle]] = [:]
        var unassigned: [Vehicle] = []
        
        for vehicle in manager.vehicles {
            let assignedTrains = manager.trains.filter { $0.vehicleId == vehicle.id }
            if assignedTrains.isEmpty {
                unassigned.append(vehicle)
            } else {
                for train in assignedTrains {
                    if let lineId = train.lineId,
                       let line = manager.lines.first(where: { $0.id == lineId }) {
                        if grouped[line.name] == nil {
                            grouped[line.name] = []
                        }
                        if !grouped[line.name]!.contains(where: { $0.id == vehicle.id }) {
                            grouped[line.name]!.append(vehicle)
                        }
                    }
                }
            }
        }
        
        return List {
            if !unassigned.isEmpty {
                Section(header: Text("Non Assegnati").font(.headline).foregroundColor(.secondary)) {
                    ForEach(unassigned.sorted { $0.name < $1.name }) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            
            ForEach(grouped.keys.sorted(), id: \.self) { lineName in
                Section(header: Text(lineName).font(.headline).foregroundColor(appState.theme.dark)) {
                    ForEach(grouped[lineName]?.sorted { $0.name < $1.name } ?? []) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Helper Functions
    
    private func getManufacturer(for model: String) -> String {
        let m = model.uppercased()
        if m.contains("ETR 103") || m.contains("ETR 104") || m.contains("ETR 204") || m.contains("ETR 255") { return "Alstom (Pop)" }
        if m.contains("ETR 425") || m.contains("ETR 324") { return "Alstom (Jazz)" }
        if m.contains("ALN 501") || m.contains("MINUETTO") { return "Alstom (Minuetto)" }
        if m.contains("ETR 600") || m.contains("ETR 610") || m.contains("ETR 485") { return "Alstom (Pendolino)" }
        if m.contains("ETR 1000") || m.contains("ETR 500") || m.contains("FRECCIAROSSA") { return "Hitachi (Frecciarossa)" }
        if m.contains("ETR 700") || m.contains("FRECCIARGENTO") { return "Hitachi (Frecciargento)" }
        if m.contains("ETR 421") || m.contains("ETR 521") || m.contains("ETR 621") { return "Hitachi (Rock)" }
        if m.contains("HTR 312") || m.contains("HTR 412") { return "Hitachi (Blues)" }
        if m.contains("TAF") { return "Hitachi (TAF)" }
        if m.contains("TSR") { return "Hitachi (TSR)" }
        if m.contains("ETR 170") || m.contains("FLIRT") { return "Stadler (FLIRT)" }
        if m.contains("ETR 343") { return "Stadler (FLIRT XL)" }
        if m.contains("ATR 803") || m.contains("COLLEONI") { return "Stadler (Colleoni)" }
        if m.contains("ATR 220") || m.contains("SWING") { return "Pesa (Swing)" }
        if m.contains("E.464") || m.contains("E464") { return "Locomotive (E.464)" }
        if m.contains("E.494") { return "Locomotive (TRAXX)" }
        if m.contains("E.191") || m.contains("E.193") { return "Locomotive (Vectron)" }
        if m.contains("E.652") { return "Locomotive (Caimano)" }
        if m.contains("D.445") { return "Locomotive (Diesel)" }
        return "Altro"
    }
    
    private func deleteVehicles(at offsets: IndexSet) {
        for index in offsets {
            let vehicle = sortedVehicles[index]
            // First unassign trains
            for tIdx in manager.trains.indices {
                if manager.trains[tIdx].vehicleId == vehicle.id {
                    manager.trains[tIdx].vehicleId = nil
                }
            }
            manager.vehicles.removeAll { $0.id == vehicle.id }
        }
        manager.createCheckpoint()
    }
}

struct VehicleRowContent: View {
    let vehicle: Vehicle
    let manager: LinesManager
    @EnvironmentObject var appState: AppState
    
    private var modelColor: Color {
        let m = vehicle.model.lowercased()
        if m.contains("coradia") || m.contains("pop") || m.contains("jazz") || m.contains("minuetto") { return .blue }
        if m.contains("caravaggio") || m.contains("rock") { return .orange }
        if m.contains("pesa") || m.contains("swing") { return .green }
        if m.contains("stadler") || m.contains("colleoni") { return .red }
        if m.contains("navetta") { return .purple }
        return .secondary
    }
    
    private var assignedTrains: [Train] {
        manager.trains.filter { $0.vehicleId == vehicle.id }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Vehicle photo or badge icon
            Group {
                if let imageName = vehicle.imageName, !imageName.isEmpty, let _ = UIImage(named: imageName) {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(modelColor.opacity(0.15))
                        Text(String(vehicle.model.prefix(3)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(modelColor)
                    }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                Text("\(vehicle.model) • \(Int(vehicle.length))m • \(Int(vehicle.maxSpeed)) km/h")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                if !assignedTrains.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(assignedTrains.prefix(3)) { train in
                                Text(train.name)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)
                            }
                            if assignedTrains.count > 3 {
                                Text("+\(assignedTrains.count - 3)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.selectedVehicleId == vehicle.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedVehicleId == vehicle.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
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
    @State private var showTrainDatabase = false
    @State private var acceleration: Double = 1.0
    @State private var deceleration: Double = 1.0
    @State private var imageName: String? = nil
    @State private var isElectric: Bool = false
    
    init(manager: LinesManager, vehicle: Vehicle?) {
        self.manager = manager
        self.vehicle = vehicle
        _name = State(initialValue: vehicle?.name ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _length = State(initialValue: vehicle?.length ?? 200)
        _maxSpeed = State(initialValue: vehicle?.maxSpeed ?? 160)
        _acceleration = State(initialValue: vehicle?.acceleration ?? 1.0)
        _deceleration = State(initialValue: vehicle?.deceleration ?? 1.0)
        _imageName = State(initialValue: vehicle?.imageName)
        _isElectric = State(initialValue: vehicle?.isElectric ?? false)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Database Treni") {
                    Button(action: { showTrainDatabase = true }) {
                        Label("Importa da Database", systemImage: "square.and.arrow.down")
                    }
                    
                    if let img = imageName {
                        Text("Immagine: \(img)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
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
                            self.isElectric = template.isElectric
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
                    Toggle("Trazione Elettrica", isOn: $isElectric)
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
            .sheet(isPresented: $showTrainDatabase) {
                TrainDatabasePickerView { selectedTrain in
                    // Populate form fields from selected train
                    self.name = selectedTrain.nome
                    self.model = selectedTrain.tipo
                    self.maxSpeed = selectedTrain.specifiche.velocitaMaxKmh
                    self.acceleration = selectedTrain.fisica.accelerazioneMS2
                    self.deceleration = selectedTrain.fisica.frenaturaServizioMS2
                    self.imageName = selectedTrain.assetName
                    // Infer electrification from model name or type
                    let modelLower = selectedTrain.tipo.lowercased()
                    self.isElectric = modelLower.hasPrefix("e.") || modelLower.contains("etr") || modelLower.contains("el.")
                    showTrainDatabase = false
                }
                .environmentObject(appState)
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
            existing.acceleration = acceleration
            existing.deceleration = deceleration
            existing.isElectric = isElectric
            existing.imageName = imageName
            if let idx = manager.vehicles.firstIndex(where: { $0.id == existing.id }) {
                manager.vehicles[idx] = existing
            }
        } else {
            let newV = Vehicle(
                name: name,
                model: model,
                length: length,
                maxSpeed: maxSpeed,
                acceleration: acceleration,
                deceleration: deceleration,
                isElectric: isElectric,
                imageName: imageName
            )
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

// MARK: - Vehicle Inspector View

struct VehicleInspectorView: View {
    let vehicle: Vehicle
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    
    private var modelColor: Color {
        let m = vehicle.model.lowercased()
        if m.contains("coradia") || m.contains("pop") || m.contains("jazz") || m.contains("minuetto") { return .blue }
        if m.contains("caravaggio") || m.contains("rock") { return .orange }
        if m.contains("pesa") || m.contains("swing") { return .green }
        if m.contains("stadler") || m.contains("colleoni") { return .red }
        if m.contains("navetta") || m.contains("e.464") || m.contains("e464") { return .purple }
        if m.contains("etr") && (m.contains("1000") || m.contains("500") || m.contains("700")) { return .red }
        return .secondary
    }
    
    private var assignedTrains: [Train] {
        manager.trains.filter { $0.vehicleId == vehicle.id }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
    }
    
    private var imageName: String {
        let model = vehicle.model.uppercased()
        if model.contains("ETR 103") { return "ETR_103_Pop" }
        if model.contains("ETR 104") { return "ETR_104_Pop" }
        if model.contains("ETR 204") { return "ETR_204_Pop" }
        if model.contains("ETR 255") { return "ETR_255_Pop" }
        if model.contains("ETR 425") { return "ETR_425_Jazz" }
        if model.contains("ETR 324") { return "ETR_324_Jazz" }
        if model.contains("ALN 501") || model.contains("MINUETTO") { return "ALn_501_Minuetto" }
        if model.contains("ETR 600") || model.contains("ETR 610") { return "ETR_600_Pendolino" }
        if model.contains("ETR 485") { return "ETR_485_Pendolino" }
        if model.contains("ETR 1000") { return "ETR_1000_Frecciarossa" }
        if model.contains("ETR 500") { return "ETR_500_Frecciarossa" }
        if model.contains("ETR 700") { return "ETR_700_Frecciargento" }
        if model.contains("ETR 421") { return "ETR_421_Rock" }
        if model.contains("ETR 521") { return "ETR_521_Rock" }
        if model.contains("ETR 621") { return "ETR_621_Rock" }
        if model.contains("HTR 312") { return "HTR_312_Blues" }
        if model.contains("HTR 412") { return "HTR_412_Blues" }
        if model.contains("ETR 170") { return "ETR_170_FLIRT" }
        if model.contains("ATR 220") || model.contains("SWING") { return "ATR_220_Swing" }
        if model.contains("E.464") || model.contains("E464") { return "Locomotiva_E464" }
        if model.contains("TSR") { return "Treno_Servizio_Regionale_TSR" }
        return ""
    }
    
    private var trainIconForModel: String {
        let model = vehicle.model.uppercased()
        // High-speed trains
        if model.contains("FRECCIAROSSA") || model.contains("ETR 1000") || model.contains("ETR 500") {
            return "train.side.front.car"
        }
        // Frecciargento
        if model.contains("FRECCIARGENTO") || model.contains("ETR 700") {
            return "train.side.front.car"
        }
        // Pendolino (tilting trains)
        if model.contains("PENDOLINO") || model.contains("ETR 600") || model.contains("ETR 610") || model.contains("ETR 485") {
            return "tram.fill.tunnel"
        }
        // Regional EMUs (Pop, Rock, Jazz)
        if model.contains("POP") || model.contains("ROCK") || model.contains("JAZZ") || 
           model.contains("ETR 103") || model.contains("ETR 104") || model.contains("ETR 204") || 
           model.contains("ETR 255") || model.contains("ETR 421") || model.contains("ETR 521") || 
           model.contains("ETR 621") || model.contains("ETR 425") || model.contains("ETR 324") {
            return "tram.fill"
        }
        // Blues
        if model.contains("BLUES") || model.contains("HTR 312") || model.contains("HTR 412") {
            return "tram.fill"
        }
        // Light rail (Minuetto)
        if model.contains("MINUETTO") || model.contains("ALN 501") {
            return "tram"
        }
        // Stadler (FLIRT, Colleoni)
        if model.contains("STADLER") || model.contains("FLIRT") || model.contains("COLLEONI") || 
           model.contains("ETR 170") || model.contains("ATR 803") {
            return "tram.fill"
        }
        // Pesa Swing
        if model.contains("SWING") || model.contains("ATR 220") {
            return "tram.fill"
        }
        // Locomotives
        if model.contains("LOCOMOTIVA") || model.contains("E.464") || model.contains("E464") || 
           model.contains("E.494") || model.contains("E.191") || model.contains("E.193") || 
           model.contains("E.652") || model.contains("D.445") {
            return "rectangle.fill.on.rectangle.fill"
        }
        // TSR
        if model.contains("TSR") {
            return "tram.fill"
        }
        // Default
        return "train.side.front.car"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
                // Vehicle Image
                if !imageName.isEmpty, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                } else {
                    // Enhanced Placeholder with train-specific design
                    ZStack {
                        // Background gradient
                        LinearGradient(
                            colors: [modelColor.opacity(0.3), modelColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 200)
                        .cornerRadius(12)
                        
                        // Decorative elements
                        HStack(spacing: 0) {
                            ForEach(0..<5) { _ in
                                Rectangle()
                                    .fill(modelColor.opacity(0.05))
                                    .frame(width: 2)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Train icon and info
                        VStack(spacing: 16) {
                            // Icon based on train type
                            ZStack {
                                Circle()
                                    .fill(modelColor.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: trainIconForModel)
                                    .font(.system(size: 50, weight: .light))
                                    .foregroundColor(modelColor.opacity(0.8))
                            }
                            
                            VStack(spacing: 4) {
                                Text(vehicle.model)
                                    .font(.title3.bold())
                                    .foregroundColor(modelColor)
                                
                                Text("Immagine non disponibile")
                                    .font(.caption2)
                                    .foregroundColor(modelColor.opacity(0.6))
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(modelColor.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Vehicle Info Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(vehicle.name)
                                .font(.title2.bold())
                                .foregroundColor(appState.theme.dark)
                            
                            Text(vehicle.model)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(modelColor.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "train.side.front.car")
                                .font(.system(size: 30))
                                .foregroundColor(modelColor)
                        }
                    }
                    
                    Divider()
                    
                    // Technical Specs
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Specifiche Tecniche")
                            .font(.headline)
                            .foregroundColor(appState.theme.dark)
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label {
                                    Text("Lunghezza")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } icon: {
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.caption)
                                }
                                Text("\(Int(vehicle.length)) m")
                                    .font(.title3.bold())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label {
                                    Text("Velocità Max")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } icon: {
                                    Image(systemName: "gauge.with.dots.needle.67percent")
                                        .font(.caption)
                                }
                                Text("\(Int(vehicle.maxSpeed)) km/h")
                                    .font(.title3.bold())
                            }
                        }
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label {
                                    Text("Accelerazione")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } icon: {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.caption)
                                }
                                Text(String(format: "%.1f m/s²", vehicle.acceleration))
                                    .font(.title3.bold())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label {
                                    Text("Decelerazione")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } icon: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.caption)
                                }
                                Text(String(format: "%.1f m/s²", vehicle.deceleration))
                                    .font(.title3.bold())
                            }
                        }
                    }
                    
                    if let notes = vehicle.notes, !notes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note")
                                .font(.headline)
                                .foregroundColor(appState.theme.dark)
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(appState.theme.surface)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Assigned Trains
                VStack(alignment: .leading, spacing: 12) {
                    Text("Turno Materiale")
                        .font(.headline)
                        .foregroundColor(appState.theme.dark)
                    
                    if assignedTrains.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Nessun treno assegnato a questo mezzo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(appState.theme.surface)
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(assignedTrains) { train in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(train.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(appState.theme.dark)
                                        
                                        Spacer()
                                        
                                        if let line = manager.lines.first(where: { $0.id == train.lineId }) {
                                            Text(line.name)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(line.uiColor.opacity(0.2))
                                                .foregroundColor(line.uiColor)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    HStack(spacing: 12) {
                                        if let dep = train.departureTime {
                                            Label(dep.timeFormat, systemImage: "arrow.up.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        
                                        if let arr = train.stops.last?.arrival {
                                            Label(arr.timeFormat, systemImage: "arrow.down.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        
                                        Spacer()
                                        
                                        if let origin = train.stops.first?.stationId,
                                           let dest = train.stops.last?.stationId {
                                            let originName = appState.railroad.network.nodes.first(where: { $0.id == origin })?.name ?? origin
                                            let destName = appState.railroad.network.nodes.first(where: { $0.id == dest })?.name ?? dest
                                            Text("\(originName) → \(destName)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .background(appState.theme.surface)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                
                // Conflicts
                let conflicts = manager.getVehicleConflicts(for: vehicle.id)
                if !conflicts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Conflitti di Turno")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        ForEach(conflicts) { conflict in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(conflict.description)
                                    .font(.subheadline)
                                    .foregroundColor(appState.theme.dark)
                            }
                            .padding()
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
        }
    }
}

