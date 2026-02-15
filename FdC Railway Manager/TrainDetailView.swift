import SwiftUI
import Combine

struct TrainDetailView: View {
    let train: Train
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var manager: LinesManager
    @StateObject private var wikiImageService = WikiImageService()
    @State private var showVehicleSheet = false
    private var network: NetworkModel { appState.railroad.network }
    
    var trainConflicts: [ScheduleConflict] {
        appState.railroad.lines.conflictManager.conflicts.filter { $0.trainAId == train.id || $0.trainBId == train.id }
    }
    
    // Helper to get binding safely
    private var trainBinding: Binding<Train>? {
        manager.binding(for: train)
    }

    var body: some View {
        Group {
            if let binding = trainBinding {
                content(train: binding)
                    .id(train.id) // FORCE REFRESH when selection changes
                    .onLongPressGesture(minimumDuration: 1.0) {
                        appState.isInspectorEditingMode.toggle()
                    }
            } else {
                Text("train_not_found".localized).foregroundColor(.secondary)
            }
        }
    }
    
    func content(train: Binding<Train>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(train: train)
                
                if !trainConflicts.isEmpty {
                    conflictBanner
                }
                
                if let error = train.wrappedValue.schedulingError {
                    schedulingErrorBanner(error)
                }
                
                if appState.isInspectorEditingMode {
                     editingModeIndicator
                }
                
                // 1. IDENTIFICATION & TYPE
                identificationSection(train: train)
                
                // 1.5 VEHICLE ASSIGNMENT (MANDATORY)
                vehicleAssignmentSection(train: train)
                
                // 2. TIMETABLE & ITINERARY
                timetableSection(trainBinding: train)
            }
            .padding()
            .background(Color(UIColor.systemGray6).opacity(0.95))
        }
    }
    
    private func headerSection(train: Binding<Train>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(train.wrappedValue.name)
                    .font(.title2.bold())
                Text(train.wrappedValue.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            if appState.isInspectorEditingMode {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var conflictBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Il treno ha \(trainConflicts.count) conflitti attivi")
                .font(.subheadline.bold())
        }
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red)
        .cornerRadius(12)
    }
    
    private func schedulingErrorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "xmark.octagon.fill")
            VStack(alignment: .leading) {
                Text("Errore Calcolo Orario")
                    .font(.headline)
                Text(error)
                    .font(.caption)
            }
        }
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .cornerRadius(12)
    }
    
    private var editingModeIndicator: some View {
        HStack {
            Image(systemName: "pencil.and.outline")
            Text("MODIFICA ATTIVA")
                .font(.system(.caption, design: .rounded).bold())
            Spacer()
        }
        .foregroundColor(.yellow)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.yellow.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        .cornerRadius(12)
    }

    // MARK: - Sections
    
    private func identificationSection(train: Binding<Train>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // Vehicle Image Logic
                vehicleImage(train: train.wrappedValue)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("train_name".localized, text: train.name)
                            .font(.title2.bold())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
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
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func vehicleImage(train: Train) -> some View {
        Group {
            if let vId = train.vehicleId,
               let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                
                if let imageName = vehicle.imageName, let _ = UIImage(named: imageName) {
                    // Local Image
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else if let url = wikiImageService.currentImageURL {
                    // Remote Image
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            ProgressView()
                        }
                    }
                } else {
                    // Fallback Icon
                    Image(systemName: "train.side.front.car")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            } else {
                Image(systemName: "train.side.front.car")
                    .font(.title)
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 80, height: 80)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .clipped()
        .onAppear {
            // Trigger search if needed
            if let vId = train.vehicleId,
               let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                if vehicle.imageName == nil || UIImage(named: vehicle.imageName ?? "") == nil {
                    // Search by model name if local image missing
                    wikiImageService.searchImage(for: vehicle.model)
                }
            }
        }
    }
    
    private func vehicleAssignmentSection(train: Binding<Train>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bus.doubledecker.fill")
                    .foregroundColor(.purple)
                Text("materiale_rotabile".localized).font(.headline)
                
                if train.wrappedValue.vehicleId == nil {
                    Spacer()
                    Text("OBBLIGATORIO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Menu {
                Button("Nessun Mezzo") {
                    train.wrappedValue.vehicleId = nil
                }
                
                let models = Array(Set(manager.vehicles.map { $0.model })).sorted()
                
                ForEach(models, id: \.self) { model in
                    Menu(model) {
                         let vehiclesInModel = manager.vehicles.filter { $0.model == model }
                         ForEach(vehiclesInModel) { v in
                            Button(v.name) {
                                train.wrappedValue.vehicleId = v.id
                                // AUTO-POPULATE TECHNICAL DATA
                                train.wrappedValue.maxSpeed = v.maxSpeed
                                train.wrappedValue.acceleration = v.acceleration
                                train.wrappedValue.deceleration = v.deceleration
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let vId = train.wrappedValue.vehicleId, 
                       let v = manager.vehicles.first(where: { $0.id == vId }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.name)
                                .font(.system(.body, design: .rounded).bold())
                                .foregroundColor(.primary)
                            Text(v.model)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Seleziona un mezzo...")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .disabled(!appState.isInspectorEditingMode)
            
            if let vId = train.wrappedValue.vehicleId, let v = manager.vehicles.first(where: { $0.id == vId }) {
                Button(action: { showVehicleSheet = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Scheda Materiale Rotabile")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showVehicleSheet) {
                    VehicleEditSheet(manager: manager, vehicle: v)
                }
            }
            
            if let vId = train.wrappedValue.vehicleId, let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                HStack(spacing: 16) {
                    MetricView(label: "Lunghezza", value: "\(Int(vehicle.length))m")
                    MetricView(label: "Velocità Max", value: "\(Int(vehicle.maxSpeed))km/h")
                    MetricView(label: "Accelerazione", value: String(format: "%.2f m/s²", vehicle.acceleration))
                    Spacer()
                }
                .padding(.top, 4)
                
                // Check for conflicts involving THIS train
                let conflicts = manager.getVehicleConflicts(for: vId).filter {
                    $0.trainA.id == train.wrappedValue.id || $0.trainB.id == train.wrappedValue.id
                }
                
                if let firstConflict = conflicts.first {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(firstConflict.description)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red)
                    .cornerRadius(6)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(train.wrappedValue.vehicleId == nil ? Color.red.opacity(0.5) : (appState.isInspectorEditingMode ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1)), lineWidth: 1))
    }
    
    private func timetableSection(trainBinding: Binding<Train>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Servizio Assegnato").font(.headline)
            }
            
            if let lineId = trainBinding.wrappedValue.lineId,
               let line = manager.lines.first(where: { $0.id == lineId }) {
                
                HStack {
                    if let color = line.color {
                        Circle().fill(Color(hex: color) ?? .clear).frame(width: 8, height: 8)
                    }
                    Text(String(format: "line_label_fmt".localized, line.name))
                        .font(.subheadline.bold())
                    
                    Spacer()
                    
                    // Move Priority here since technical column is gone
                    HStack(spacing: 4) {
                        Text("Priorità:").font(.caption).foregroundColor(.secondary)
                        Stepper(value: trainBinding.priority, in: 1...10) {
                            Text("\(trainBinding.wrappedValue.priority)")
                                .font(.caption.bold())
                                .foregroundColor(priorityColor(trainBinding.wrappedValue.priority))
                        }
                        .fixedSize()
                        .labelsHidden()
                    }
                    .disabled(!appState.isInspectorEditingMode)
                }
                .padding(.horizontal, 4)
                
                RailwayItineraryView(
                    train: trainBinding,
                    network: appState.railroad.network,
                    lineColor: Color(hex: line.color ?? ""),
                    isReadOnly: !appState.isInspectorEditingMode
                )
                .frame(minHeight: 400)
                .cornerRadius(12)
                
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("no_line_assigned".localized).italic().foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(appState.isInspectorEditingMode ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private func priorityColor(_ p: Int) -> Color {
        if p <= 2 { return .red }
        if p <= 5 { return .orange }
        return .blue
    }
}



