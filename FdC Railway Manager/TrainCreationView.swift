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
    @State private var includeReturn: Bool = true
    
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
                    
                    if let firstIdx = line.stops.firstIndex(where: { $0.stationId == originStationId }),
                       let lastIdx = line.stops.firstIndex(where: { $0.stationId == destinationStationId }) {
                        Text("\(abs(lastIdx - firstIdx) + 1) fermate selezionate")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        Stepper("Ogni: \(frequencyMinutes) min", value: $frequencyMinutes, in: 15...240, step: 15)
                        Stepper("Per: \(repeatCount) volte", value: $repeatCount, in: 2...24)
                    }
                    
                    Picker("Materiale Rotabile", selection: $selectedVehicleTemplateId) {
                        Text("Seleziona template...").tag("")
                        ForEach(VehicleTemplate.all) { template in
                            Text(template.name).tag(template.id)
                        }
                    }
                }
                
                Section("Numerazione (Prefisso x100)") {
                    HStack {
                        Text("Numero Partenza")
                        Spacer()
                        TextField("Num", value: $startNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Anteprima Designazione:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(previewTrains.prefix(2), id: \.self) { preview in
                            Text(preview)
                                .font(.system(.caption, design: .monospaced).bold())
                        }
                        if previewTrains.count > 2 {
                            Text("... e altre \(previewTrains.count - 2) corse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: processCreation) {
                        HStack {
                            Spacer()
                            Text("Genera \(includeReturn ? previewTrains.count : (mode == .series ? repeatCount : 1)) Corse")
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
                    // Delay to allow UI update before switching mode
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appState.currentMode = .schedule
                        appState.sidebarSelection = .trains
                        appState.showPanel(.inspector)
                    }
                }
                Button("Raffina con GA") {
                    dismiss()
                }
                Button("Mostra nel Timetable", role: .cancel) {
                    dismiss()
                }
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
            if let first = line.stops.first { originStationId = first.stationId }
            if let last = line.stops.last { destinationStationId = last.stationId }
        }
        
        // Suggest Number based on line prefix
        let prefix = line.numberPrefix ?? 0
        let base = prefix > 0 ? prefix * 100 : 100
        startNumber = base + 1 
        
        // Next clean hour
        let now = Date()
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now)!
        departureTime = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: nextHour))!
    }
    
    private var estimatedReturnDeparture: Date {
        let duration = nominalDuration(from: originStationId, to: destinationStationId)
        let arrival = departureTime.addingTimeInterval(duration)
        return arrival.addingTimeInterval(TimeInterval(returnTurnaroundMinutes * 60))
    }
    
    private func nominalDuration(from startId: String, to endId: String) -> TimeInterval {
        guard let startIndex = line.stops.firstIndex(where: { $0.stationId == startId }),
              let endIndex = line.stops.firstIndex(where: { $0.stationId == endId }) else { return 1800 }
        
        let diff = abs(startIndex - endIndex)
        return TimeInterval(diff * 10 * 60) // High estimate: 10 mins per leg (travel + dwell)
    }
    
    private var previewTrains: [String] {
        var list: [String] = []
        let code = line.codePrefix ?? "T"
        
        var currentDeparture = departureTime
        var currentNum = startNumber
        
        for _ in 0..<max(1, (mode == .series ? repeatCount : 1)) {
            let numStr = "\(code) - \(currentNum)"
            list.append("\(numStr) (\(currentDeparture.timeFormat))")
            
            if includeReturn {
                let retNum = currentNum + 1
                let duration = nominalDuration(from: originStationId, to: destinationStationId)
                let retDep = currentDeparture.addingTimeInterval(duration + TimeInterval(returnTurnaroundMinutes * 60))
                let retNumStr = "\(code) - \(retNum)"
                list.append("\(retNumStr) (\(retDep.timeFormat))")
                currentNum += 2
            } else {
                currentNum += 1
            }
            currentDeparture = currentDeparture.addingTimeInterval(TimeInterval(frequencyMinutes * 60))
        }
        return list
    }
    
    private func processCreation() {
        let iterations = mode == .series ? repeatCount : 1
        var currentDelay: TimeInterval = 0
        var currentNum = startNumber
        
        var totalCreated = 0
        
        for _ in 0..<iterations {
            let depTime = departureTime.addingTimeInterval(currentDelay)
            
            // 1. Outbound
            let train1 = buildTrain(number: currentNum, origin: originStationId, dest: destinationStationId, departure: depTime)
            linesManager.trains.append(train1)
            totalCreated += 1
            
            let outboundDuration = nominalDuration(from: originStationId, to: destinationStationId)
            
            if includeReturn {
                // 2. Return (Symmetric)
                let retNum = currentNum + 1
                let retDep = depTime.addingTimeInterval(outboundDuration + TimeInterval(returnTurnaroundMinutes * 60))
                
                let train2 = buildTrain(number: retNum, origin: destinationStationId, dest: originStationId, departure: retDep)
                linesManager.trains.append(train2)
                totalCreated += 1
                
                currentNum += 2
            } else {
                currentNum += 1
            }
            currentDelay += TimeInterval(frequencyMinutes * 60)
        }
        
        createdTrainsCount = totalCreated
        showAIPrompt = true
    }
    
    private func buildTrain(number: Int, origin: String, dest: String, departure: Date) -> Train {
        let code = line.codePrefix ?? "T"
        let name = "\(code) - \(number)" // Requested format: CODE - NUMBER
        
        let stops = extractStops(from: origin, to: dest)
        let template = VehicleTemplate.all.first(where: { $0.id == selectedVehicleTemplateId }) ?? VehicleTemplate.all[0]
        
        // PIGNOLO PROTOCOL: Subject to obstacles -> Low Priority (1)
        // This ensures the train "waits" for higher priority traffic.
        var t = Train(
            id: UUID(),
            number: number,
            name: name,
            type: "Regionale",
            lineId: line.id,
            departureTime: departure,
            stops: stops,
            vehicleId: nil,
            maxSpeed: template.maxSpeed,
            acceleration: template.acceleration,
            deceleration: template.deceleration,
            priority: 1 // LOWER priority so it yields/waits
        )
        
        // Create dedicated virtual vehicle
        let v = Vehicle(
            name: "\(template.model) (\(name))",
            model: template.model,
            length: template.length,
            maxSpeed: template.maxSpeed,
            imageName: template.imageName
        )
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
            subset = Array(line.stops[endIndex...startIndex].reversed())
        }
        
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
