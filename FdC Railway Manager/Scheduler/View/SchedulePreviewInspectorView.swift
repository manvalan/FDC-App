import SwiftUI

struct SchedulePreviewInspectorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var network: RailwayNetwork
    
    let trains: [Train]
    let line: TrainRoute
    let mode: ScheduleMode
    
    @State private var acceptSchedule: Bool = false
    @State private var showConflicts: Bool = true
    
    private var conflicts: [ScheduleConflict] {
        let conflictManager = ConflictManager()
        let allTrains = manager.trains + trains
        var cache: [String: [Edge]]? = nil
        let (conflicts, _) = conflictManager.calculateConflictsWithCapacities(
            nodes: network.nodes,
            edges: network.edges,
            trains: allTrains,
            pathCache: &cache
        )
        return conflicts
    }
    
    private var outboundTrains: [Train] {
        // Trains going from origin to destination (first stop matches line origin)
        trains.filter { train in
            guard let firstStop = train.stops.first?.stationId else { return false }
            return firstStop == line.originStationId
        }
    }
    
    private var returnTrains: [Train] {
        // Trains going from destination back to origin (first stop matches line destination)
        trains.filter { train in
            guard let firstStop = train.stops.first?.stationId else { return false }
            return firstStop == line.destinationStationId
        }
    }
    
    private var estimatedVehicles: Int {
        // Estimate based on turnaround times
        let maxSimultaneous = trains.map { train in
            trains.filter { other in
                guard let t1Start = train.departureTime,
                      let t2Start = other.departureTime else { return false }
                
                let t1End = train.estimatedArrival ?? t1Start.addingTimeInterval(3600)
                let t2End = other.estimatedArrival ?? t2Start.addingTimeInterval(3600)
                
                // Ensure valid ranges (arrival must be after departure)
                guard t1End >= t1Start, t2End >= t2Start else { return false }
                
                return (t1Start...t1End).overlaps(t2Start...t2End)
            }.count
        }.max() ?? 1
        
        return max(1, maxSimultaneous)
    }
    
    private var averageInterval: Int? {
        guard mode == .cadenced, outboundTrains.count > 1 else { return nil }
        
        let departures = outboundTrains.compactMap { $0.departureTime }.sorted()
        guard departures.count > 1 else { return nil }
        
        var intervals: [Int] = []
        for i in 0..<(departures.count - 1) {
            let interval = Int(departures[i + 1].timeIntervalSince(departures[i]) / 60)
            intervals.append(interval)
        }
        
        return intervals.isEmpty ? nil : intervals.reduce(0, +) / intervals.count
    }
    
    var body: some View {
        ZStack {
            appState.theme.backgroundSecondary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                Divider()
                
                // Stats Summary
                statsSection
                    .padding()
                    .background(Color.blue.opacity(0.05))
                
                Divider()
                
                // Conflicts Warning
                if !conflicts.isEmpty && showConflicts {
                    conflictsSection
                        .padding()
                        .background(Color.red.opacity(0.05))
                    Divider()
                }
                
                // Train List
                ScrollView {
                    VStack(spacing: 0) {
                        let outbound = outboundTrains
                        let returning = returnTrains
                        
                        if !outbound.isEmpty {
                            directionSection(
                                title: "PARTENZE (ANDATA)",
                                trains: outbound,
                                color: .blue
                            )
                        }
                        
                        if !returning.isEmpty {
                            Divider()
                                .padding(.vertical, 16)
                            
                            directionSection(
                                title: "RITORNI",
                                trains: returning,
                                color: .orange
                            )
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Accept Toggle & Actions
                actionsSection
                    .padding()
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Anteprima Orario")
                    .font(.headline)
                Text(line.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { 
                rejectSchedule()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            Text("Riepilogo")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                StatBadge(
                    icon: "arrow.right",
                    label: "Andata",
                    value: "\(outboundTrains.count)",
                    color: .blue
                )
                
                if !returnTrains.isEmpty {
                    StatBadge(
                        icon: "arrow.left",
                        label: "Ritorno",
                        value: "\(returnTrains.count)",
                        color: .orange
                    )
                }
                
                if let interval = averageInterval {
                    StatBadge(
                        icon: "timer",
                        label: "Cadenza",
                        value: "\(interval)m",
                        color: .purple
                    )
                }
                
                StatBadge(
                    icon: "bus.doubledecker",
                    label: "Mezzi",
                    value: "~\(estimatedVehicles)",
                    color: .green
                )
            }
        }
    }
    
    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("⚠️ \(conflicts.count) Conflitti Rilevati")
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
                
                Spacer()
                
                Button(action: { showConflicts.toggle() }) {
                    Image(systemName: showConflicts ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if showConflicts {
                ForEach(conflicts.prefix(5)) { conflict in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(conflict.trainAName) ↔ \(conflict.trainBName)")
                                .font(.caption.bold())
                            Text(conflict.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if conflicts.count > 5 {
                    Text("... e altri \(conflicts.count - 5) conflitti")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private func directionSection(title: String, trains: [Train], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .cornerRadius(6)
                
                Spacer()
                
                Text("\(trains.count) corse")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            ForEach(trains) { train in
                trainCard(train, color: color)
            }
        }
    }
    
    private func trainCard(_ train: Train, color: Color) -> some View {
        let hasConflict = conflicts.contains { $0.trainAId == train.id || $0.trainBId == train.id }
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(train.name)
                            .font(.system(.subheadline, design: .rounded).bold())
                        
                        if hasConflict {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(selectedTrainTypeName(train))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Timeline
                HStack(spacing: 8) {
                    if let dept = train.departureTime {
                        Text(formatTime(dept))
                            .font(.system(.caption, design: .monospaced).bold())
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    if let arr = train.estimatedArrival {
                        Text(formatTime(arr))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(color)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                
                // Delete button
                Button(action: {
                    withAnimation {
                        deleteTrain(train.id)
                    }
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 10))
                    Text("\(train.stops.count) fermate")
                }
                
                if let duration = train.estimatedArrival, let dept = train.departureTime {
                    let mins = Int(duration.timeIntervalSince(dept) / 60)
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("\(mins)min")
                    }
                }
                
                Spacer()
                
                if let vId = train.vehicleId, let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                    Text(vehicle.name)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            ZStack {
                if hasConflict {
                    Color.red.opacity(0.08)
                } else {
                    color.opacity(0.06)
                }
                
                RoundedRectangle(cornerRadius: 14)
                    .stroke(hasConflict ? Color.red.opacity(0.2) : color.opacity(0.15), lineWidth: 1)
            }
        )
        .cornerRadius(14)
    }
    
    private func selectedTrainTypeName(_ train: Train) -> String {
        return TrainCategory(rawValue: train.type)?.localizedName ?? train.type
    }
    
    private func deleteTrain(_ id: UUID) {
        if var previewTrains = appState.schedulePreviewTrains {
            previewTrains.removeAll(where: { $0.id == id })
            appState.schedulePreviewTrains = previewTrains
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            Toggle(isOn: $acceptSchedule) {
                HStack(spacing: 8) {
                    Image(systemName: acceptSchedule ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(acceptSchedule ? .green : .secondary)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(acceptSchedule ? "Orario Confermato" : "Conferma Orario")
                            .font(.subheadline.bold())
                        Text("Swipe per confermare e creare i treni")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .green))
            .padding()
            .background(acceptSchedule ? Color.green.opacity(0.1) : Color.secondary.opacity(0.05))
            .cornerRadius(12)
            
            HStack(spacing: 12) {
                Button(action: rejectSchedule) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Annulla")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                
                Button(action: confirmSchedule) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Applica Orario")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(acceptSchedule ? Color.green : Color.secondary.opacity(0.2))
                    .foregroundColor(acceptSchedule ? .white : .secondary)
                    .cornerRadius(10)
                }
                .disabled(!acceptSchedule)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    private func confirmSchedule() {
        guard acceptSchedule else { return }
        
        var processedTrains = trains
        
        print("✅ [PREVIEW] Utente ha accettato l'orario: aggiunta di \(processedTrains.count) treni")
        
        // Se l'utente ha selezionato un modello e l'ottimizzazione rotazione è attiva, crea i veicoli fisici
        if let model = appState.schedulePreviewSelectedModel, appState.schedulePreviewOptimizeVehicles {
            print("🚂 [VEHICLES] Creazione automatica veicoli da modello: \(model.nome)")
            
            let vehicleOptimizer = VehicleRotationOptimizer()
            
            // Calcola il numero di veicoli necessari
            let requiredVehicles = vehicleOptimizer.suggestVehicleCount(
                for: processedTrains,
                minimumTurnaroundTime: appState.schedulePreviewMinTurnaroundTime
            )
            
            print("📊 [VEHICLES] Veicoli necessari: \(requiredVehicles)")
            
            // Crea i veicoli fisici
            var createdVehicles: [Vehicle] = []
            for i in 1...requiredVehicles {
                let vehicleName = "\(model.nome) #\(i) - \(line.name)"
                let vehicle = model.toVehicle(name: vehicleName)
                createdVehicles.append(vehicle)
                manager.vehicles.append(vehicle)
                print("   ✅ Creato: \(vehicleName)")
            }
            
            print("✅ [VEHICLES] Creati \(createdVehicles.count) veicoli fisici")
            
            // Ottimizza l'assegnazione dei veicoli ai treni con i veicoli appena creati
            let assignment = vehicleOptimizer.optimizeVehicleAssignment(
                trains: processedTrains,
                vehicles: createdVehicles,
                minimumTurnaroundTime: appState.schedulePreviewMinTurnaroundTime
            )
            
            // Applica le assegnazioni
            for (vehicleId, trainIds) in assignment {
                for trainId in trainIds {
                    if let index = processedTrains.firstIndex(where: { $0.id == trainId }) {
                        processedTrains[index].vehicleId = vehicleId
                    }
                }
            }
            
            let assignedCount = processedTrains.filter { $0.vehicleId != nil }.count
            print("✅ [VEHICLES] Assegnati \(assignedCount)/\(processedTrains.count) treni a \(assignment.count) veicoli")
        }
        
        // Add trains to manager
        manager.trains.append(contentsOf: processedTrains)
        print("✅ [PREVIEW] Manager ora ha \(manager.trains.count) treni totali")
        
        // Validate schedules
        manager.validateSchedules()
        
        print("🎉 [PREVIEW] Orario applicato con successo!")
        
        // Clear preview state
        appState.schedulePreviewTrains = nil
        appState.schedulePreviewRoute = nil
        appState.schedulePreviewSelectedModel = nil
        
        // Select the line to show timetable
        appState.selectedRouteId = line.id
        appState.sidebarSelection = .lines
        
        // Close schedule creation inspector
        appState.creationRouteId = nil
    }
    
    private func rejectSchedule() {
        print("❌ [PREVIEW] Utente ha rifiutato l'orario")
        
        // Clear preview and return to schedule creation
        appState.schedulePreviewTrains = nil
        appState.schedulePreviewRoute = nil
    }
}

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Helper extension for Train
extension Train {
    var estimatedArrival: Date? {
        // Use the arrival time from the last stop if available
        return stops.last?.arrival
    }
}

#Preview {
    SchedulePreviewInspectorView(
        trains: [],
        line: TrainRoute(id: "test", name: "Test Route"),
        mode: .single
    )
    .environmentObject(AppState.shared)
}
