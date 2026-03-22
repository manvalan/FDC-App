import SwiftUI

struct TrainCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    let route: TrainRoute
    
    // Configurazione
    enum CreationMode: String, CaseIterable {
        case single = "Corsa Singola"
        case series = "Batteria (Periodica)"
    }
    
    @State private var mode: CreationMode = .single
    @State private var includeReturn: Bool = true
    
    // Percorso
    @State private var originStationId: String = ""
    @State private var destinationStationId: String = ""
    
    // Orari
    @State private var departureTime: Date = Date()
    @State private var returnDepartureTime: Date = Date().addingTimeInterval(3600)
    
    // Batteria
    @State private var frequencyMinutes: Int = 60
    @State private var repeatCount: Int = 5
    
    // Materiale
    @AppStorage("lastSelectedVehicleTemplateId") private var selectedVehicleTemplateId: String = ""
    
    // Numerazione
    @State private var startNumber: Int = 1
    @State private var startNumberReturn: Int = 2
    
    // Post-Creation
    @State private var showAIPrompt = false
    @State private var createdTrainsCount = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Modalità") {
                    Picker("Tipo", selection: $mode) {
                        ForEach(CreationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Includi Ritorno (Speculare)", isOn: $includeReturn)
                }
                
                Section("Percorso") {
                    Picker("Partenza", selection: $originStationId) {
                        ForEach(route.stationIds, id: \.self) { stationId in
                            Text(stationName(for: stationId)).tag(stationId)
                        }
                    }
                    Picker("Arrivo", selection: $destinationStationId) {
                        ForEach(route.stationIds, id: \.self) { stationId in
                            Text(stationName(for: stationId)).tag(stationId)
                        }
                    }
                }
                
                Section("Orari e Frequenza") {
                    DatePicker("Partenza \(stationName(for: originStationId))", selection: $departureTime, displayedComponents: .hourAndMinute)
                    
                    if includeReturn {
                        DatePicker("Partenza \(stationName(for: destinationStationId))", selection: $returnDepartureTime, displayedComponents: .hourAndMinute)
                    }
                    
                    if mode == .series {
                        Stepper("Intervallo: \(frequencyMinutes) min", value: $frequencyMinutes, in: 15...240, step: 15)
                        Stepper("Per: \(repeatCount) volte", value: $repeatCount, in: 2...24)
                    }
                }

                Section("Materiale Rotabile") {
                    Picker("Materiale", selection: $selectedVehicleTemplateId) {
                        Text("Seleziona template...").tag("")
                        ForEach(VehicleTemplate.all) { template in
                            Text(template.name).tag(template.id)
                        }
                    }
                }
                
                Section("Numerazione") {
                    HStack {
                        Text("N. Partenza \(stationName(for: originStationId))")
                        Spacer()
                        TextField("Odd", value: $startNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    if includeReturn {
                        HStack {
                            Text("N. Partenza \(stationName(for: destinationStationId))")
                            Spacer()
                            TextField("Even", value: $startNumberReturn, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Anteprima Designazione:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(previewTrains.prefix(4), id: \.self) { preview in
                            Text(preview)
                                .font(.system(.caption, design: .monospaced).bold())
                        }
                        if previewTrains.count > 4 {
                            Text("... e altre \(previewTrains.count - 4) corse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: processCreation) {
                        HStack {
                            Spacer()
                            let count = (includeReturn ? 2 : 1) * (mode == .series ? repeatCount : 1)
                            Text("Genera \(count) Corse")
                                .bold()
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(appState.theme.accent)
                }
            }
            .navigationTitle("Nuova Corsa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
            .alert("Corse Create", isPresented: $showAIPrompt) {
                Button("Ottimizza con AI") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appState.currentMode = .schedule
                        appState.sidebarSelection = .trains
                        appState.showPanel(.inspector)
                    }
                }
                Button("Raffina con GA") { dismiss() }
                Button("Mostra nel Timetable", role: .cancel) { dismiss() }
            } message: {
                Text("Hai creato \(createdTrainsCount) corse. Poiché sono 'treni di sfondo', hanno una priorità bassa e aspetteranno in caso di ostacoli. Vuoi usare l'AI per sistemare i conflitti?")
            }
            .onAppear {
                setupDefaults()
            }
        }
    }
    
    // MARK: - Logic
    
    private func setupDefaults() {
        if originStationId.isEmpty {
            originStationId      = route.stationIds.first ?? ""
            destinationStationId = route.stationIds.last  ?? ""
        }
        let prefix = route.numberPrefix ?? 0
        let base = prefix * 1000
        startNumber = base + 1
        startNumberReturn = base + 2
        
        let now = Date()
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now)!
        let baseTime = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: nextHour))!
        departureTime = baseTime
        returnDepartureTime = baseTime.addingTimeInterval(1800) // Default 30 min after
    }
    
    private func nominalDuration(from startId: String, to endId: String) -> TimeInterval {
        guard let startIdx = route.stationIds.firstIndex(of: startId),
              let endIdx   = route.stationIds.firstIndex(of: endId) else { return 1800 }
        return TimeInterval(abs(startIdx - endIdx) * 10 * 60)
    }
    
    private var previewTrains: [String] {
        var list: [String] = []
        let code = route.serviceCodePrefix ?? "T"
        
        var currentDeparture = departureTime
        var currentReturnDeparture = returnDepartureTime
        var currentNum = startNumber
        var currentNumReturn = startNumberReturn
        
        for i in 0..<max(1, (mode == .series ? repeatCount : 1)) {
            let numStr = "\(code) - \(currentNum)"
            list.append("\(numStr) (\(currentDeparture.timeFormat))")
            
            if includeReturn {
                let retNumStr = "\(code) - \(currentNumReturn)"
                list.append("\(retNumStr) (\(currentReturnDeparture.timeFormat))")
                currentReturnDeparture = currentReturnDeparture.addingTimeInterval(TimeInterval(frequencyMinutes * 60))
                currentNumReturn += 2
            }
            
            currentNum += 2
            currentDeparture = currentDeparture.addingTimeInterval(TimeInterval(frequencyMinutes * 60))
        }
        return list
    }
    
    private func processCreation() {
        let iterations = mode == .series ? repeatCount : 1
        
        // 1. Generate all trains logic
        var trainsToAssign: [Train] = []
        var currentDelay: TimeInterval = 0
        var currentNum = startNumber
        var currentNumReturn = startNumberReturn
        
        for _ in 0..<iterations {
            let depTime = departureTime.addingTimeInterval(currentDelay)
            
            // Outbound
            let t1 = buildTrain(number: currentNum, origin: originStationId, dest: destinationStationId, departure: depTime)
            trainsToAssign.append(t1)
            
            if includeReturn {
                // Return
                let retDepTime = returnDepartureTime.addingTimeInterval(currentDelay)
                let t2 = buildTrain(number: currentNumReturn, origin: destinationStationId, dest: originStationId, departure: retDepTime)
                trainsToAssign.append(t2)
                currentNumReturn += 2
            }
            currentNum += 2
            currentDelay += TimeInterval(frequencyMinutes * 60)
        }
        
        // 2. Estimate required fleet size (V)
        // RTT = 2 * Duration + 2 * Turnaround (fixed 15 min for estimation)
        let tripDuration = nominalDuration(from: originStationId, to: destinationStationId)
        let rtt = (tripDuration * 2) + (30 * 60) // 15+15 min turnaround
        let freq = Double(frequencyMinutes * 60)
        let vCount = max(1, Int(ceil(rtt / freq)))
        
        // 3. Create Vehicles Pool
        let template = VehicleTemplate.all.first(where: { $0.id == selectedVehicleTemplateId }) ?? VehicleTemplate.all[0]
        
        for i in 0..<vCount {
            let groupNumber = String(format: "%03d", i + 1)
            // Format: Model.XXX (e.g. ETR 351.001)
            let cleanModel = template.model.trimmingCharacters(in: .whitespacesAndNewlines)
            let vehicleName = "\(cleanModel).\(groupNumber)"
            let v = Vehicle(
                name: vehicleName,
                model: template.model,
                length: template.length,
                maxSpeed: template.maxSpeed,
                imageName: template.imageName
            )
            linesManager.vehicles.append(v)
        }
        
        // 4. Add trains to manager (Unassigned)
        linesManager.trains.append(contentsOf: trainsToAssign)
        
        // 5. Intelligent Auto-Assignment
        // Let the manager balance the load and respect locations
        linesManager.autoAssignRollingStock(for: route.id)
        

        
        createdTrainsCount = trainsToAssign.count
        showAIPrompt = true
    }
    
    private func buildTrain(number: Int, origin: String, dest: String, departure: Date) -> Train {
        let code = route.serviceCodePrefix ?? "T"
        let name = "\(code) - \(number)"
        
        let stops = extractStops(from: origin, to: dest)
        let template = VehicleTemplate.all.first(where: { $0.id == selectedVehicleTemplateId }) ?? VehicleTemplate.all[0]
        
        return Train(
            id: UUID(),
            number: number,
            name: name,
            type: "Regionale",
            lineId: route.id,
            departureTime: departure,
            stops: stops,
            vehicleId: nil, // Will be assigned in processCreation for batteries
            maxSpeed: template.maxSpeed,
            acceleration: template.acceleration,
            deceleration: template.deceleration,
            priority: 1
        )
    }
    
    /// Builds the ordered list of RelationStops for a train running from `start` to `end`
    /// along this route's stationIds.
    private func extractStops(from start: String, to end: String) -> [RelationStop] {
        guard let startIdx = route.stationIds.firstIndex(of: start),
              let endIdx   = route.stationIds.firstIndex(of: end) else {
            print("❌ [TrainCreationView] Station not found in route \(route.name)")
            return []
        }
        let ordered: [String] = startIdx <= endIdx
            ? Array(route.stationIds[startIdx...endIdx])
            : Array(route.stationIds[endIdx...startIdx].reversed())
        
        return ordered.map { stationId in
            RelationStop(
                id: UUID(),
                stationId: stationId,
                minDwellTime: linesManager.getStandardDwell(for: stationId)
            )
        }
    }
    
    private func stationName(for id: String) -> String {
        appState.railroad.network.nodes.first(where: { $0.id == id })?.name ?? id
    }
}
