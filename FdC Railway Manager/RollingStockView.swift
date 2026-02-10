import SwiftUI

struct RollingStockView: View {
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    
    @State private var showingAddSheet = false
    @State private var editingVehicle: Vehicle? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("materiale_rotante".localized)
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
            VehicleEditSheet(vehicle: nil)
        }
        .sheet(item: $editingVehicle) { vehicle in
            VehicleEditSheet(vehicle: vehicle)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vehicle.name)
                    .font(.headline)
                Spacer()
                Text(vehicle.model)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if trains.isEmpty {
                Text("Nessun treno assegnato")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                let sorted = trains.sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(sorted) { train in
                            Text(train.name)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct VehicleEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    
    let vehicle: Vehicle?
    
    @State private var name: String = ""
    @State private var model: String = ""
    @State private var length: Double = 200
    @State private var maxSpeed: Double = 160
    
    init(vehicle: Vehicle?) {
        self.vehicle = vehicle
        _name = State(initialValue: vehicle?.name ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _length = State(initialValue: vehicle?.length ?? 200)
        _maxSpeed = State(initialValue: vehicle?.maxSpeed ?? 160)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informazioni Generali") {
                    TextField("Matricola / Nome", text: $name)
                    TextField("Modello", text: $model)
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
                
                if let v = vehicle {
                    Section("Treni Assegnati") {
                        let attachedTrains = manager.trains.filter { $0.vehicleId == v.id }
                        ForEach(attachedTrains) { train in
                            HStack {
                                Text(train.name)
                                Spacer()
                                Button(action: {
                                    if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
                                        manager.trains[idx].vehicleId = nil
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        NavigationLink("Assegna nuovo treno") {
                            TrainSelectionPicker(vehicleId: v.id)
                        }
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
    }
}

struct TrainSelectionPicker: View {
    let vehicleId: UUID
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            let availableTrains = manager.trains.filter { $0.vehicleId == nil }
            if availableTrains.isEmpty {
                Text("Tutti i treni hanno già un mezzo assegnato.")
                    .foregroundColor(.secondary)
            }
            ForEach(availableTrains) { train in
                Button(action: {
                    if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
                        manager.trains[idx].vehicleId = vehicleId
                    }
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(train.name).font(.headline)
                        Text(train.type).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Seleziona Treno")
    }
}
