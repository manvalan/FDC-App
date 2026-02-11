import SwiftUI
import Combine

struct TrainDetailView: View {
    let train: Train
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var manager: LinesManager
    @StateObject private var wikiImageService = WikiImageService()
    private var network: NetworkModel { appState.railroad.network }
    
    var trainConflicts: [ScheduleConflict] {
        appState.railroad.lines.conflictManager.conflicts.filter { $0.trainAId == train.id || $0.trainBId == train.id }
    }
    
    var body: some View {
        Group {
            if let binding = manager.binding(for: train) {
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
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(train.wrappedValue.name)
                            .font(.title2.bold())
                        Text("\(train.wrappedValue.type)")
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

                // Conflict Banner
                if !trainConflicts.isEmpty {
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
                
                if appState.isInspectorEditingMode {
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

                // 1. IDENTIFICATION & TYPE
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        // Vehicle Image Logic
                        Group {
                            if let vId = train.wrappedValue.vehicleId,
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
                            if let vId = train.wrappedValue.vehicleId,
                               let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                                if vehicle.imageName == nil || UIImage(named: vehicle.imageName ?? "") == nil {
                                    // Search by model name if local image missing
                                    wikiImageService.searchImage(for: vehicle.model)
                                }
                            }
                        }
                        
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
                
                // 1.5 VEHICLE ASSIGNMENT (MANDATORY)
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
                    
                    Picker("Mezzo", selection: Binding(
                        get: { train.wrappedValue.vehicleId },
                        set: { newId in
                            train.wrappedValue.vehicleId = newId
                            if let vId = newId, let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                                // AUTO-POPULATE TECHNICAL DATA
                                train.wrappedValue.maxSpeed = vehicle.maxSpeed
                                train.wrappedValue.acceleration = vehicle.acceleration
                                train.wrappedValue.deceleration = vehicle.deceleration
                            }
                        }
                    )) {
                        if train.wrappedValue.vehicleId == nil {
                            Text("Seleziona un mezzo...").tag(UUID?.none)
                        }
                        ForEach(manager.vehicles) { v in
                            Text(v.name).tag(UUID?.some(v.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!appState.isInspectorEditingMode)
                    
                    if let vId = train.wrappedValue.vehicleId, let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                        HStack {
                            Text(vehicle.model).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(vehicle.length))m • \(Int(vehicle.maxSpeed))km/h").font(.caption).foregroundColor(.secondary)
                        }
                        
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
                
                // 2. TIMETABLE & ITINERARY
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Servizio Assegnato").font(.headline) // Renamed from timetable_itinerary
                    }
                    
                    if let lineId = train.wrappedValue.lineId, 
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
                                Stepper(value: train.priority, in: 1...10) {
                                    Text("\(train.wrappedValue.priority)")
                                        .font(.caption.bold())
                                        .foregroundColor(priorityColor(train.wrappedValue.priority))
                                }
                                .fixedSize()
                                .labelsHidden()
                            }
                            .disabled(!appState.isInspectorEditingMode)
                        }
                        .padding(.horizontal, 4)
                        
                        RailwayItineraryView(
                            train: train,
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
            .padding()
            .background(Color(UIColor.systemGray6).opacity(0.95))
        }
    }
    
    private func priorityColor(_ p: Int) -> Color {
        if p <= 2 { return .red }
        if p <= 5 { return .orange }
        return .blue
    }
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
