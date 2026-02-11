import SwiftUI
import Combine

struct TrainDetailView: View {
    let train: Train
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var manager: LinesManager
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
                        Text("\(train.wrappedValue.type) \(train.wrappedValue.number ?? 0)")
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
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 60, height: 60)
                            Image(systemName: "train.side.front.car")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("1234", value: train.number, format: .number)
                                    .font(.title2.bold())
                                    .frame(width: 80)
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("train_name".localized, text: train.name)
                                    .font(.title2.bold())
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
                
                // 1.5 VEHICLE ASSIGNMENT
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bus.doubledecker.fill")
                            .foregroundColor(.purple)
                        Text("materiale_rotabile".localized).font(.headline)
                    }
                    
                    Picker("Mezzo", selection: train.vehicleId) {
                        Text("nessun_mezzo".localized).tag(UUID?.none)
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
                            Text("\(Int(vehicle.length))m").font(.caption).foregroundColor(.secondary)
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
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(appState.isInspectorEditingMode ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
                
                // 2. TIMETABLE & ITINERARY
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("timetable_itinerary".localized).font(.headline)
                    }
                    
                    if let lineId = train.wrappedValue.lineId, 
                       let line = manager.lines.first(where: { $0.id == lineId }) {
                        
                        HStack {
                            if let color = line.color {
                                Circle().fill(Color(hex: color) ?? .clear).frame(width: 8, height: 8)
                            }
                            Text(String(format: "line_label_fmt".localized, line.name))
                                .font(.subheadline.bold())
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
                
                // 3. TECHNICAL PERFORMANCE
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .foregroundColor(.purple)
                            Text("technical_data".localized).font(.headline)
                    }
                    
                    Grid(alignment: .leading, verticalSpacing: 12) {
                        GridRow {
                            Text("max_speed".localized)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("140", value: train.maxSpeed, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                Text("km/h").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        GridRow {
                            Text("acceleration".localized)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("0.5", value: train.acceleration, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                Text("m/s²").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        
                        GridRow {
                            Text("deceleration".localized)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("0.4", value: train.deceleration, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                Text("m/s²").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        GridRow {
                            Text("priority_label".localized)
                                .foregroundColor(.secondary)
                            HStack {
                                Stepper(value: train.priority, in: 1...10) {
                                    Text("\(train.wrappedValue.priority)")
                                        .bold()
                                        .foregroundColor(priorityColor(train.wrappedValue.priority))
                                }
                                .padding(.leading, 4)
                            }
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
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
