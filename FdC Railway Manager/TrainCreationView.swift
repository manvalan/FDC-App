import SwiftUI

struct TrainCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    let line: RailwayLine
    
    // Configurazione
    enum CreationMode: String, CaseIterable {
        case single = "Corsa Singola"
        case series = "Batteria (Periodica)"
    }
    
    @State private var mode: CreationMode = .single
    @State private var includeReturn: Bool = false
    
    // Percorso
    @State private var originStationId: String = ""
    @State private var destinationStationId: String = ""
    
    // Orari
    @State private var departureTime: Date = Date()
    @State private var returnTurnaroundMinutes: Int = 20
    
    // Batteria
    @State private var frequencyMinutes: Int = 60
    @State private var repeatCount: Int = 5
    
    // Materiale
    @AppStorage("lastSelectedVehicleTemplateId") private var selectedVehicleTemplateId: String = ""
    
    // Numerazione
    @State private var startNumber: Int = 1
    
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
                    
                    Toggle("Includi Ritorno (Simmetrico)", isOn: $includeReturn)
                }
                
                Section("Percorso") {
                    Picker("Partenza", selection: $originStationId) {
                        ForEach(line.stops, id: \.stationId) { stop in
                            Text(stationName(for: stop.stationId)).tag(stop.stationId)
                        }
                    }
                    
                    Picker("Arrivo", selection: $destinationStationId) {
                        ForEach(line.stops, id: \.stationId) { stop in
                            Text(stationName(for: stop.stationId)).tag(stop.stationId)
                        }
                    }
                }
                
                Section("Orari e Materiale") {
                    DatePicker("Orario Partenza", selection: $departureTime, displayedComponents: .hourAndMinute)
                    
                    if includeReturn {
                        Stepper("Sosta al capolinea: \(returnTurnaroundMinutes) min", value: $returnTurnaroundMinutes, in: 5...120, step: 5)
                        
                        HStack {
                            Text("Partenza Ritorno (stimata)")
                            Spacer()
                            Text(estimatedReturnDeparture.timeFormat)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if mode == .series {
                        Stepper("Frequenza: \(frequencyMinutes) min", value: $frequencyMinutes, in: 15...240, step: 15)
                        Stepper("Numero Corse: \(repeatCount)", value: $repeatCount, in: 2...24)
                    }
                    
                    // Vehicle Picker
                    Picker("Materiale Rotabile", selection: $selectedVehicleTemplateId) {
                        Text("Seleziona template...").tag("")
                        ForEach(VehicleTemplate.all) { template in
                            Text(template.name).tag(template.id)
                        }
                    }
                }
                
                Section("Numerazione") {
                    HStack {
                        Text("Numero Partenza")
                        Spacer()
                        TextField("Num", value: $startNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anteprima:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(previewTrains.prefix(4), id: \.self) { preview in
                            Text(preview)
                                .font(.system(.caption, design: .monospaced))
                        }
                        if previewTrains.count > 4 {
                            Text("... e altri \(previewTrains.count - 4)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: createTrains) {
                        HStack {
                            Spacer()
                            Text("Crea \(previewTrains.count) Corse")
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
            .onAppear {
                setupDefaults()
            }
        }
    }
    
    // MARK: - Logic
    
    private func setupDefaults() {
        // Set Origin/Dest to Line Start/End
        if let first = line.stops.first { originStationId = first.stationId }
        if let last = line.stops.last { destinationStationId = last.stationId }
        
        // Suggest Number
        // Formula: Prefix * 100 + NextAvailable
        let prefix = line.numberPrefix ?? 0
        let base = prefix > 0 ? prefix * 100 : 100
        
        // Find highest existing number in this range
        // This is a heuristic
        startNumber = base + 1 
        
        // Ajust to current time
        let now = Date()
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now)!
        let startOfNextHour = calendar.date(bySettingMinute: 0, second: 0, of: nextHour)!
        departureTime = startOfNextHour
    }
    
    private var estimatedReturnDeparture: Date {
        let duration = nominalDuration(from: originStationId, to: destinationStationId)
        let arrival = departureTime.addingTimeInterval(duration)
        return arrival.addingTimeInterval(TimeInterval(returnTurnaroundMinutes * 60))
    }
    
    private func nominalDuration(from startId: String, to endId: String) -> TimeInterval {
        // Calculate sum of minDwell + travel time between stops
        // Approximation: Delta of 'order' on line? No, need distances/speeds.
        // For now, let's sum minDwellTime + 5 mins travel per stop as heuristic
        // Or better: use `ScheduleStop` minDwellTime.
        // Real duration requires physical calculation.
        // We will fallback to a rough estimate: 5 min per stop + dwell.
        
        guard let startIndex = line.stops.firstIndex(where: { $0.stationId == startId }),
              let endIndex = line.stops.firstIndex(where: { $0.stationId == endId }) else { return 3600 }
        
        let range = startIndex < endIndex ? line.stops[startIndex...endIndex] : line.stops[endIndex...startIndex]
        let stopCount = range.count
        return TimeInterval(stopCount * 8 * 60) // 8 mins per stop avg
    }
    
    private var previewTrains: [String] {
        var list: [String] = []
        let code = line.codePrefix ?? "T"
        
        var currentDeparture = departureTime
        var currentNum = startNumber
        
        for i in 0..<max(1, (mode == .series ? repeatCount : 1)) {
            // Outbound
            let numStr = "\(code) \(currentNum)"
            let timeStr = currentDeparture.timeFormat
            list.append("\(numStr) • \(timeStr) • \(stationName(for: originStationId)) → \(stationName(for: destinationStationId))")
            
            if includeReturn {
                // Return
                let retNum = currentNum + 1
                let duration = nominalDuration(from: originStationId, to: destinationStationId)
                let retDep = currentDeparture.addingTimeInterval(duration + TimeInterval(returnTurnaroundMinutes * 60))
                
                let retNumStr = "\(code) \(retNum)"
                let retTimeStr = retDep.timeFormat
                list.append("\(retNumStr) • \(retTimeStr) • \(stationName(for: destinationStationId)) → \(stationName(for: originStationId))")
                
                currentNum += 2
            } else {
                currentNum += 1
            }
            
            // Increment frequency
            currentDeparture = currentDeparture.addingTimeInterval(TimeInterval(frequencyMinutes * 60))
        }
        
        return list
    }
    
    private func createTrains() {
        let iterations = mode == .series ? repeatCount : 1
        var currentDelay: TimeInterval = 0
        var currentNum = startNumber
        
        var createdTrains: [Train] = []
        
        for _ in 0..<iterations {
            let depTime = departureTime.addingTimeInterval(currentDelay)
            
            // 1. Outbound
            let train1 = buildTrain(
                number: currentNum,
                origin: originStationId,
                dest: destinationStationId,
                departure: depTime
            )
            linesManager.trains.append(train1)
            createdTrains.append(train1)
            
            let outboundDuration = nominalDuration(from: originStationId, to: destinationStationId)
            
            if includeReturn {
                // 2. Return
                let retNum = currentNum + 1
                let retDep = depTime.addingTimeInterval(outboundDuration + TimeInterval(returnTurnaroundMinutes * 60))
                
                let train2 = buildTrain(
                    number: retNum,
                    origin: destinationStationId,
                    dest: originStationId,
                    departure: retDep
                )
                linesManager.trains.append(train2)
                createdTrains.append(train2)
                
                currentNum += 2
            } else {
                currentNum += 1
            }
            
            currentDelay += TimeInterval(frequencyMinutes * 60)
        }
        
        // Feedback
        dismiss()
        
        // Trigger AI Suggestion
        // We can use a delay or a specific modal
        /*
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
             // Show alert or nudge for AI
         }
         */
    }
    
    private func buildTrain(number: Int, origin: String, dest: String, departure: Date) -> Train {
        let code = line.codePrefix ?? "T"
        let name = "\(code) \(number)"
        
        // Filter stops
        let stops = extractStops(from: origin, to: dest)
        
        // Find vehicle template to get specs
        let template = VehicleTemplate.all.first(where: { $0.id == selectedVehicleTemplateId }) ?? VehicleTemplate.all[0]
        
        var t = Train(
            id: UUID(),
            number: number,
            name: name,
            type: "Regionale", // Todo: derive from Line or user
            lineId: line.id,
            departureTime: departure,
            stops: stops,
            vehicleId: nil, // We don't create instance yet, or we create a phantom vehicle? 
            // Better: we assign the "vehicle model" via technical params, 
            // OR create a new Vehicle instance if the user selected a template.
            // The prompt says "Quando crei un Materiale Rotabile...", but here we select.
            // Let's create a new Vehicle instance for this train?
            // Usually we assign distinct physical vehicles.
            // For now, let's set technical data and leave vehicleId nil (or auto-create).
            // Actually, we MUST set technical data for simulation.
            maxSpeed: template.maxSpeed,
            acceleration: template.acceleration,
            deceleration: template.deceleration,
            priority: 5 // Normal priority. New trains "wait" means they are subject to scheduler.
        )
        
        // Auto-create a physical vehicle for this train so simulation works immediately
        let v = Vehicle(
            name: "\(template.model) #\(number)", // Temp name
            model: template.model,
            length: template.length,
            maxSpeed: template.maxSpeed,
            imageName: template.imageName
        )
        // Check if we should add to fleet?
        // Maybe better to just keep it virtual or add to linesManager.vehicles
        linesManager.vehicles.append(v)
        t.vehicleId = v.id
        
        return t
    }
    
    private func extractStops(from start: String, to end: String) -> [RelationStop] {
        guard let startIndex = line.stops.firstIndex(where: { $0.stationId == start }),
              let endIndex = line.stops.firstIndex(where: { $0.stationId == end }) else {
            return []
        }
        
        var subset: [RelationStop]
        if startIndex <= endIndex {
            subset = Array(line.stops[startIndex...endIndex])
        } else {
            // Reverse direction
            // IMPORTANT: When reversing, we must ensure 'track' assignments might flip?
            // Usually 'RelationStop' tracks are generic or specific to station.
            subset = Array(line.stops[endIndex...startIndex].reversed())
        }
        
        // Reset IDs
        return subset.map { s in
            var copy = s
            copy.id = UUID()
            return copy
        }
    }
    
    private func stationName(for id: String) -> String {
        appState.railroad.network.nodes.first(where: { $0.id == id })?.name ?? id
    }
}
