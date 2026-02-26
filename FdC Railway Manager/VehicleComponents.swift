import SwiftUI

// MARK: - Vehicle Edit Sheet

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
                
                templateSection
                
                Section("Informazioni Generali") {
                    TextField("Matricola / Nome", text: $name)
                    TextField("Modello Tecnico", text: $model)
                }
                
                if let v = vehicle {
                    attachedTrainsSection(v)
                }
                
                technicalSpecsSection
                
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
    
    private var templateSection: some View {
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
                    applyTemplate(template)
                }
            }
        }
    }

    private func applyTemplate(_ template: VehicleTemplate) {
        self.model = template.model
        self.length = template.length
        self.maxSpeed = template.maxSpeed
        self.isElectric = template.isElectric
        if self.name.isEmpty {
            self.name = template.name
        }
    }

    private func attachedTrainsSection(_ v: Vehicle) -> some View {
        Section("Turno Materiale (Treni Assegnati)") {
            let attachedTrains = manager.trains.filter { $0.vehicleId == v.id }
                .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
            
            if attachedTrains.isEmpty {
                Text("Nessun treno assegnato a questo mezzo.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(attachedTrains) { train in
                attachedTrainRow(train)
            }
            
            NavigationLink {
                TrainSelectionPicker(vehicleId: v.id)
            } label: {
                Label("Assegna nuovo treno", systemImage: "plus.circle")
                    .foregroundColor(.accentColor)
            }
        }
    }

    private func attachedTrainRow(_ train: Train) -> some View {
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
            
            Button(role: .destructive, action: { unassignTrain(train) }) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func unassignTrain(_ train: Train) {
        if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
            manager.trains[idx].vehicleId = nil
        }
    }

    private var technicalSpecsSection: some View {
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

// MARK: - Train Selection Picker

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
            Picker("Filtra per Linea", selection: $appState.lastVehicleAssignmentRouteId) {
                Text("Tutti i treni disponibili").tag(String?.none)
                Divider()
                ForEach(manager.sortedRoutes) { route in
                    Text(route.name).tag(String?.some(route.id))
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            List {
                let filteredTrains = manager.trains.filter { train in
                    let isAvailable = train.vehicleId == nil
                    let matchesLine = appState.lastVehicleAssignmentRouteId == nil || train.routeId == appState.lastVehicleAssignmentRouteId
                    
                    var matchesSmart = true
                    if useSmartFilter, let lastPos = lastStationId {
                        matchesSmart = train.stops.first?.stationId == lastPos
                    }
                    
                    return isAvailable && matchesLine && matchesSmart
                }
                
                if let lastPos = lastStationId {
                    smartFilterSection(lastPos)
                }
                
                if filteredTrains.isEmpty {
                    emptyTrainsSection
                } else {
                    Section {
                        ForEach(filteredTrains) { train in
                            trainSelectionRow(train)
                        }
                    }
                }
            }
        }
        .navigationTitle("Assegna Treno")
    }

    private func smartFilterSection(_ lastPos: String) -> some View {
        Section {
            let matchesSmartBinding = Binding<Bool>(
                get: { useSmartFilter },
                set: { useSmartFilter = $0 }
            )
            Toggle(isOn: matchesSmartBinding) {
                VStack(alignment: .leading) {
                    Text("Filtro intelligente").font(.subheadline).bold()
                    Text("Mostra solo treni partenti da \(lastStationName)")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyTrainsSection: some View {
        Section {
            Text(appState.lastVehicleAssignmentRouteId == nil ? "Tutti i treni hanno già un mezzo assegnato." : "Nessun treno disponibile per la linea selezionata.")
                .foregroundColor(.secondary)
                .italic()
                .padding()
        }
    }

    private func trainSelectionRow(_ train: Train) -> some View {
        let conflictsWithNew = checkPotentialConflict(train: train)
        return Button(action: { assignVehicleToTrain(train) }) {
            VStack(alignment: .leading, spacing: 6) {
                trainHeaderRow(train)
                trainRouteRow(train)
                
                if let conflict = conflictsWithNew {
                    conflictWarningRow(conflict)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func trainHeaderRow(_ train: Train) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(train.name).font(.headline)
                if let route = manager.routes.first(where: { $0.id == train.routeId }) {
                    Text(route.name).font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(train.type).font(.caption2).padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
        }
    }

    private func trainRouteRow(_ train: Train) -> some View {
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
    }

    private func conflictWarningRow(_ conflict: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(conflict).font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.red)
        .padding(.vertical, 2)
    }

    private func assignVehicleToTrain(_ train: Train) {
        if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
            manager.trains[idx].vehicleId = vehicleId
        }
        dismiss()
    }

    private func checkPotentialConflict(train: Train) -> String? {
        // Find existing trains for this vehicle
        let existing = manager.trains.filter { $0.vehicleId == vehicleId && $0.departureTime != nil }
        
        guard let newDep = train.departureTime else { return nil }
        
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
            vehicleImageHeader
            vehicleInfoCard
            assignedTrainsTimeline
            vehicleConflictsSection
        }
    }

    private var vehicleImageHeader: some View {
        Group {
            if !imageName.isEmpty, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                imagePlaceholder
            }
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [modelColor.opacity(0.3), modelColor.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            .cornerRadius(12)
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(modelColor.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: trainIconForModel)
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(modelColor.opacity(0.8))
                }
                
                VStack(spacing: 4) {
                    Text(vehicle.model).font(.title3.bold()).foregroundColor(modelColor)
                    Text("Immagine non disponibile").font(.caption2).foregroundColor(modelColor.opacity(0.6))
                }
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(modelColor.opacity(0.3), lineWidth: 1))
    }

    private var vehicleInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vehicle.name).font(.title2.bold()).foregroundColor(appState.theme.dark)
                    Text(vehicle.model).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(modelColor.opacity(0.15)).frame(width: 60, height: 60)
                    Image(systemName: "train.side.front.car").font(.system(size: 30)).foregroundColor(modelColor)
                }
            }
            Divider()
            technicalSpecsGrid
            vehicleNotesSection
        }
        .padding()
        .background(appState.theme.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var technicalSpecsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specifiche Tecniche").font(.headline).foregroundColor(appState.theme.dark)
            HStack(spacing: 20) {
                specItem(label: "Lunghezza", value: "\(Int(vehicle.length)) m", icon: "arrow.left.and.right")
                specItem(label: "Velocità Max", value: "\(Int(vehicle.maxSpeed)) km/h", icon: "gauge.with.dots.needle.67percent")
            }
            HStack(spacing: 20) {
                specItem(label: "Accelerazione", value: String(format: "%.1f m/s²", vehicle.acceleration), icon: "arrow.up.circle")
                specItem(label: "Decelerazione", value: String(format: "%.1f m/s²", vehicle.deceleration), icon: "arrow.down.circle")
            }
        }
    }

    private func specItem(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(label).font(.caption).foregroundColor(.secondary)
            } icon: {
                Image(systemName: icon).font(.caption)
            }
            Text(value).font(.title3.bold())
        }
    }

    private var vehicleNotesSection: some View {
        Group {
            if let notes = vehicle.notes, !notes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note").font(.headline).foregroundColor(appState.theme.dark)
                    Text(notes).font(.body).foregroundColor(.secondary)
                }
            }
        }
    }

    private var assignedTrainsTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turno Materiale").font(.headline).foregroundColor(appState.theme.dark)
            if assignedTrains.isEmpty {
                emptyTrainsIndicator
            } else {
                VStack(spacing: 8) {
                    ForEach(assignedTrains) { train in
                        assignedTrainTimelineRow(train)
                    }
                }
            }
        }
    }

    private var emptyTrainsIndicator: some View {
        HStack {
            Image(systemName: "info.circle").foregroundColor(.secondary)
            Text("Nessun treno assegnato a questo mezzo").font(.subheadline).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appState.theme.surface)
        .cornerRadius(12)
    }

    private func assignedTrainTimelineRow(_ train: Train) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(train.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                Spacer()
                if let route = manager.routes.first(where: { $0.id == train.routeId }) {
                    Text(route.name).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(route.displayColor.opacity(0.2)).foregroundColor(route.displayColor).cornerRadius(4)
                }
            }
            assignedTrainTimeInfo(train)
        }
        .padding()
        .background(appState.theme.surface)
        .cornerRadius(10)
    }

    private func assignedTrainTimeInfo(_ train: Train) -> some View {
        HStack(spacing: 12) {
            if let dep = train.departureTime {
                Label(dep.timeFormat, systemImage: "arrow.up.circle.fill").font(.caption).foregroundColor(.green)
            }
            if let arr = train.stops.last?.arrival {
                Label(arr.timeFormat, systemImage: "arrow.down.circle.fill").font(.caption).foregroundColor(.red)
            }
            Spacer()
            if let origin = train.stops.first?.stationId, let dest = train.stops.last?.stationId {
                let originName = appState.railroad.network.nodes.first(where: { $0.id == origin })?.name ?? origin
                let destName = appState.railroad.network.nodes.first(where: { $0.id == dest })?.name ?? dest
                Text("\(originName) → \(destName)").font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private var vehicleConflictsSection: some View {
        let conflicts = manager.getVehicleConflicts(for: vehicle.id)
        return Group {
            if !conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text("Conflitti di Turno").font(.headline).foregroundColor(.red)
                    }
                    ForEach(conflicts) { conflict in
                        Text(conflict.description).font(.subheadline).foregroundColor(appState.theme.dark)
                            .padding().background(Color.red.opacity(0.05)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
    }
}
