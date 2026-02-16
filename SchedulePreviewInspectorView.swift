import SwiftUI

struct SchedulePreviewInspectorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var network: RailwayNetwork
    
    let trains: [Train]
    let line: RailwayLine
    let mode: ScheduleCreationView.ScheduleMode
    
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
            return firstStop == line.originId
        }
    }
    
    private var returnTrains: [Train] {
        // Trains going from destination back to origin (first stop matches line destination)
        trains.filter { train in
            guard let firstStop = train.stops.first?.stationId else { return false }
            return firstStop == line.destinationId
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
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Stats Summary
            statsSection
                .padding()
                .background(Color.blue.opacity(0.05))
            
            Divider()
            
            // Conflicts Warning (if any)
            if !conflicts.isEmpty && showConflicts {
                conflictsSection
                    .padding()
                    .background(Color.red.opacity(0.05))
                Divider()
            }
            
            // Train List
            ScrollView {
                VStack(spacing: 0) {
                    if !outboundTrains.isEmpty {
                        directionSection(
                            title: "🚂 Treni in Partenza",
                            trains: outboundTrains,
                            color: .blue
                        )
                    }
                    
                    if !returnTrains.isEmpty {
                        Divider()
                            .padding(.vertical, 12)
                        
                        directionSection(
                            title: "🔄 Treni di Ritorno",
                            trains: returnTrains,
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
                .background(Color.primary.opacity(0.03))
        }
        .navigationTitle("Anteprima Orario")
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(color)
            
            ForEach(trains) { train in
                trainCard(train, color: color)
            }
        }
    }
    
    private func trainCard(_ train: Train, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(train.name)
                    .font(.subheadline.bold())
                
                Spacer()
                
                if let dept = train.departureTime {
                    Text(formatTime(dept))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let arr = train.estimatedArrival {
                    Text(formatTime(arr))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                Label("\(train.stops.count) fermate", systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let duration = train.estimatedArrival, let dept = train.departureTime {
                    let mins = Int(duration.timeIntervalSince(dept) / 60)
                    Label("\(mins)min", systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(color.opacity(0.05))
        .cornerRadius(10)
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
        appState.schedulePreviewLine = nil
        appState.schedulePreviewSelectedModel = nil
        
        // Select the line to show timetable
        appState.selectedLineId = line.id
        appState.sidebarSelection = .lines
        
        // Close schedule creation inspector
        appState.creationLineId = nil
    }
    
    private func rejectSchedule() {
        print("❌ [PREVIEW] Utente ha rifiutato l'orario")
        
        // Clear preview and return to schedule creation
        appState.schedulePreviewTrains = nil
        appState.schedulePreviewLine = nil
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
    let network = NetworkModel()
    let manager = LinesManager(network: network)
    return SchedulePreviewInspectorView(
        trains: [],
        line: RailwayLine(id: "test", name: "Test Line", stops: []),
        mode: .single
    )
    .environmentObject(AppState.shared)
    .environmentObject(manager)
    .environmentObject(network)
}
