import SwiftUI

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
