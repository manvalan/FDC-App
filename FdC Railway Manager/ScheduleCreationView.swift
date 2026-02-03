import SwiftUI
import Combine

struct ScheduleCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState
    
    let line: RailwayLine
    
    // Scheduling Mode
    enum ScheduleMode: String, CaseIterable, Identifiable {
        case single = "single_trip"
        case cadenced = "cadenced_trip"
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .single: return "single_trip".localized
            case .cadenced: return "cadenced_trip".localized
            }
        }
    }
    
    enum NumberParity: String, CaseIterable, Identifiable {
        case even = "even"
        case odd = "odd"
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .even: return "even".localized
            case .odd: return "odd".localized
            }
        }
    }
    
    @State private var mode: ScheduleMode = .single
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600 * 4)
    @State private var intervalMinutes: Int = 60
    @State private var selectedTrainType: TrainCategory = .regional
    @State private var startNumber: Int = 0
    @State private var preferredParity: NumberParity = .even
    
    // Path selection within the line
    @State private var startStationId: String = ""
    @State private var viaStationIds: [String] = []
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = false
    @State private var activePicker: PickerType?
    @State private var manualStationId: String = ""
    
    // Paired Return
    @State private var scheduleReturn: Bool = true // Enabled by default in this layout
    @State private var returnStartTime: Date = Date()
    @State private var returnEndTime: Date = Date().addingTimeInterval(3600 * 4)
    @State private var returnIntervalMinutes: Int = 60
    @State private var returnStartNumber: Int = 1
    
    // Config
    init(line: RailwayLine, initialMode: ScheduleMode = .single) {
        self.line = line
        self._mode = State(initialValue: initialMode)
    }
    
    // GA Optimizer
    @StateObject private var geneticOptimizer = GeneticOptimizer()
    @State private var useGA: Bool = true
    @State private var aiStatus: String? = nil
    @State private var aiTask: Task<Void, Never>? = nil

    // Preview
    @State private var previewCount: Int = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    stationSelectSection
                    
                    PathPickerComponent(
                        startStationId: $startStationId,
                        viaStationIds: $viaStationIds,
                        endStationId: $endStationId,
                        stationSequence: $stationSequence,
                        manualAddition: $manualAddition,
                        activePicker: $activePicker,
                        manualStationId: $manualStationId,
                        lineContext: line
                    )
                    .padding(.horizontal)
                    
                    pathInfoRow
                    
                    // Two Columns for Cadence
                    HStack(alignment: .top, spacing: 20) {
                        cadenceColumn(title: "A ➔ B (\("outward".localized))", 
                                     isReturn: false,
                                     sTime: $startTime, 
                                     eTime: $endTime, 
                                     interv: $intervalMinutes,
                                     sNum: $startNumber)
                        
                        Divider()
                        
                        cadenceColumn(title: "B ➔ A (\("return".localized))", 
                                     isReturn: true,
                                     sTime: $returnStartTime, 
                                     eTime: $returnEndTime, 
                                     interv: $returnIntervalMinutes,
                                     sNum: $returnStartNumber)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    
                    previewSection
                    
                    if geneticOptimizer.isRunning {
                        VStack(spacing: 8) {
                            ProgressView(value: geneticOptimizer.progress)
                            HStack {
                                Text(String(format: "genetic_opt_gen_fmt".localized, geneticOptimizer.currentGeneration))
                                Spacer()
                                Text(String(format: "conflicts_count_fmt".localized, geneticOptimizer.conflictCount))
                                    .foregroundColor(geneticOptimizer.conflictCount == 0 ? .green : .red)
                                    .bold()
                            }
                            .font(.caption2)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    Divider().padding(.top)
                    
                    HStack {
                        Button("cancel".localized.uppercased()) { dismiss() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        
                        Spacer()
                        
                        Button(action: {
                            if aiStatus != nil || geneticOptimizer.isRunning {
                                // STOP EVERYTHING - Cancel and reset
                                aiTask?.cancel()
                                aiTask = nil
                                aiStatus = "cancelling".localized
                                
                                // Wait for cleanup before resetting UI
                                Task { @MainActor in
                                    // Give the pipeline time to detect cancellation and exit
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                                    aiStatus = nil
                                }
                            } else {
                                aiTask = Task {
                                    await generateSchedule()
                                }
                            }
                        }) {
                            if geneticOptimizer.isRunning || aiStatus != nil {
                                ProgressView().controlSize(.small).padding(.trailing, 4)
                            }
                            if aiStatus != nil || geneticOptimizer.isRunning {
                                Text("stop".localized.uppercased())
                            } else {
                                Text("generate".localized.uppercased())
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
                .padding(.vertical)
            }
            .navigationTitle("schedule_generation".localized)
            .onAppear {
                startStationId = line.originId
                endStationId = line.destinationId
                stationSequence = line.stations
                
                // Sync return times
                returnStartTime = startTime
                returnEndTime = endTime
                returnIntervalMinutes = intervalMinutes
                
                presetTrainType()
                
                // Propose numbers starting from 0 (range 0-999) for this line
                let lineTrains = manager.trains.filter { $0.lineId == line.id }
                let usedBaseNumbers = lineTrains.map { t -> Int in
                    let prefix = line.numberPrefix ?? 0
                    return t.number - (prefix * 1000)
                }.filter { $0 >= 0 && $0 < 1000 }
                
                let maxUsed = usedBaseNumbers.max() ?? -1
                startNumber = (maxUsed + 1 < 1000) ? maxUsed + 1 : 0
                
                // If parità needs sync
                if preferredParity == .even && startNumber % 2 != 0 { startNumber += 1 }
                if preferredParity == .odd && startNumber % 2 == 0 { startNumber += 1 }
                
                returnStartNumber = (startNumber + 1 < 1000) ? startNumber + 1 : 1
                
                updatePreview()
            }
            .sheet(item: $activePicker) { item in
                Group {
                    switch item {
                    case .start:
                        StationPickerView(selectedStationId: $startStationId, whitelistIds: line.stations)
                    case .via(let idx):
                        StationPickerView(selectedStationId: $viaStationIds[idx], whitelistIds: line.stations)
                    case .end:
                        StationPickerView(selectedStationId: $endStationId, whitelistIds: line.stations)
                    case .manual:
                        StationPickerView(selectedStationId: $manualStationId, linkedToStationId: stationSequence.last, whitelistIds: line.stations)
                    }
                }
                .environmentObject(network)
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    stationSequence.append(new)
                    manualStationId = ""
                }
            }
            .onChange(of: startStationId) { old, new in
                if !new.isEmpty {
                    if stationSequence.isEmpty || !manualAddition {
                        stationSequence = [new]
                    }
                }
            }
            .onChange(of: mode) { _ in updatePreview() }
            .onChange(of: startTime) { _ in updatePreview() }
            .onChange(of: endTime) { _ in updatePreview() }
            .onChange(of: intervalMinutes) { _ in updatePreview() }
        }
    }

    private var headerSection: some View {
        HStack {
            Text(String(format: "schedule_gen_line_fmt".localized, line.name))
                .font(.headline)
            Spacer()
            Picker("mode".localized, selection: $mode) {
                ForEach(ScheduleMode.allCases) { m in
                    Text(m.localizedName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
        .padding(.horizontal)
    }

    private var stationSelectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 15) {
                stationPill(title: "from".localized, id: startStationId, type: .start)
                stationPill(title: "to".localized, id: endStationId, type: .end)
                
                HStack {
                    Text("via".localized).font(.caption).bold()
                    if viaStationIds.isEmpty {
                        Button(action: { viaStationIds.append("") }) {
                            Image(systemName: "plus.circle")
                        }
                    } else {
                        ForEach(viaStationIds.indices, id: \.self) { idx in
                            stationPill(title: nil, id: viaStationIds[idx], type: .via(idx))
                        }
                        Button(action: { viaStationIds.append("") }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func stationPill(title: String?, id: String, type: PickerType) -> some View {
        Button(action: { activePicker = type }) {
            HStack {
                if let t = title {
                    Text(t).bold().foregroundColor(.secondary)
                }
                Text(stationName(id))
                    .foregroundColor(id.isEmpty ? .secondary : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var pathInfoRow: some View {
        HStack(spacing: 20) {
            infoLabel(title: "path".localized, value: String(format: "stations_count_fmt".localized, stationSequence.count))
            infoLabel(title: "length_short".localized, value: String(format: "%.1f km", network.calculatePathDistance(stationSequence)))
            infoLabel(title: "est_duration_short".localized, value: String(format: "duration_min_fmt".localized, estimateAccurateTravelTime()))
            Spacer()
            
            Picker("train_type".localized, selection: $selectedTrainType) {
                ForEach(TrainCategory.allCases) { cat in
                    Text(cat.localizedName).tag(cat)
                }
            }
            .frame(width: 150)
        }
        .padding(.horizontal)
    }

    private func infoLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary).bold()
            Text(value).font(.body)
        }
    }

    private func cadenceColumn(title: String, isReturn: Bool, sTime: Binding<Date>, eTime: Binding<Date>, interv: Binding<Int>, sNum: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.subheadline).bold()
            
            DatePicker("start_hour".localized, selection: sTime, displayedComponents: .hourAndMinute)
            
            if mode == .cadenced {
                DatePicker("end_hour".localized, selection: eTime, displayedComponents: .hourAndMinute)
                HStack {
                    Text("interval".localized)
                    Spacer()
                    Stepper(String(format: "interval_min_fmt".localized, interv.wrappedValue), value: interv, in: 5...360, step: 5)
                }
            }
            
            HStack {
                Text("start_number".localized)
                Spacer()
                TextField("num_placeholder".localized, value: sNum, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            
            if !isReturn {
                Picker("parity".localized, selection: $preferredParity) {
                    ForEach(NumberParity.allCases) { p in
                        Text(p.localizedName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }


    private var previewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(format: "trains_to_be_created_fmt".localized, previewCount))
                Spacer()
                
                Toggle("optimization_ga".localized, isOn: $useGA)
                    .toggleStyle(.switch)
            }
            .padding(.top, 4)

            if appState.useCloudAI {
                HStack(spacing: 6) {
                    Circle()
                        .fill(aiServiceConnectionColor)
                        .frame(width: 8, height: 8)
                    Text("cloud_ai_active_desc".localized)
                        .font(.caption2).foregroundColor(.blue).italic()
                }
                .onAppear { RailwayAIService.shared.verifyConnection() }
            } else if useGA {
                Text("local_ga_desc".localized)
                    .font(.caption2).foregroundColor(.secondary).italic()
            }
        }
        .padding(.horizontal)
    }
    
    
    private func normalizeDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: comps) ?? date
    }
    
    private func updatePreview() {
        let calendar = Calendar.current
        let start = normalizeDate(startTime)
        let end = normalizeDate(endTime)
        
        func calculateCount(s: Date, e: Date, interval: Int) -> Int {
            if mode == .single { return 1 }
            let sMin = calendar.component(.hour, from: s) * 60 + calendar.component(.minute, from: s)
            var eMin = calendar.component(.hour, from: e) * 60 + calendar.component(.minute, from: e)
            if eMin < sMin { eMin += 24 * 60 }
            if interval <= 0 { return 1 }
            return (eMin - sMin) / interval + 1
        }
        
        var total = calculateCount(s: start, e: end, interval: intervalMinutes)
        
        // Return calculations
        let rStart = normalizeDate(returnStartTime)
        let rEnd = normalizeDate(returnEndTime)
        total += calculateCount(s: rStart, e: rEnd, interval: returnIntervalMinutes)
        
        previewCount = max(0, total)
    }
    
    @MainActor
    private func generateSchedule(forceLocal: Bool = false) async {
        let calendar = Calendar.current
        
        // 1. PRE-FLIGHT SIMULATION: Analyze real timing to find critical stations
        aiStatus = "line_analysis".localized
        
        // Ensure startNumber matches parity
        var currentStart = startNumber
        let isEven = currentStart % 2 == 0
        if preferredParity == .even && !isEven { currentStart += 1 }
        if preferredParity == .odd && isEven { currentStart += 1 }

        let outwardStops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            // PIGNOLO PROTOCOL: Outward starts on Track 1
            return RelationStop(stationId: sid, minDwellTime: defaultDwell, track: "1")
        }
        
        let normalizedStart = normalizeDate(startTime)
        let normalizedRStartDraft = normalizeDate(returnStartTime)

        // Helper to formatting Train Number & Name based on Line Prefixes
        func makeTrainSpecs(baseNumber: Int, line: RailwayLine, currentType: String) -> (number: Int, name: String) {
            let numPrefix = line.numberPrefix ?? 0
            let finalNumber = (numPrefix * 1000) + baseNumber
            
            let code = line.codePrefix ?? currentType
            // Rule 4: "il nome del treno è costituito dal prefisso della linea, spazio e il numero del treno"
            let finalName = "\(code) \(finalNumber)"
            return (finalNumber, finalName)
        }

        // 1a. Probe Simulation
        let pOutSpecs = makeTrainSpecs(baseNumber: currentStart, line: line, currentType: selectedTrainType.rawValue)
        let probeOut = Train(id: UUID(), number: pOutSpecs.number, name: "Probe Out", type: selectedTrainType.rawValue, maxSpeed: selectedTrainType.defaultMaxSpeed, priority: selectedTrainType.defaultPriority, lineId: line.id, departureTime: normalizedStart, stops: outwardStops)
        
        let returnStops = outwardStops.reversed().map { stop -> RelationStop in
            var ns = stop
            ns.id = UUID()
            // PIGNOLO PROTOCOL: Return uses Track 2 to avoid trivial conflicts in stations
            ns.track = "2"
            return ns
        }
        
        // Find Return Line (or self)
        let rLineId = network.lines.first(where: { 
             $0.originId == line.destinationId && $0.destinationId == line.originId 
        })?.id ?? line.id
        
        // Resolve return line object if different, to get its prefixes
        let rLineObj = network.lines.first(where: { $0.id == rLineId }) ?? line
        
        let pRetSpecs = makeTrainSpecs(baseNumber: currentStart + 1, line: rLineObj, currentType: selectedTrainType.rawValue)
        let probeReturn = Train(id: UUID(), number: pRetSpecs.number, name: "Probe Return", type: selectedTrainType.rawValue, maxSpeed: selectedTrainType.defaultMaxSpeed, priority: selectedTrainType.defaultPriority, lineId: rLineId, departureTime: normalizedRStartDraft, stops: returnStops)
        
        
        
        let normalizedEnd = normalizeDate(endTime)
        
        var generatedTrains: [Train] = []
        
        // 2. GENERATE OUTWARD
        let outwardIterations: Int
        if mode == .single { outwardIterations = 1 }
        else {
            let sMin = calendar.component(.hour, from: normalizedStart) * 60 + calendar.component(.minute, from: normalizedStart)
            var eMin = calendar.component(.hour, from: normalizedEnd) * 60 + calendar.component(.minute, from: normalizedEnd)
            if eMin < sMin { eMin += 24 * 60 }
            outwardIterations = (eMin - sMin) / intervalMinutes + 1
        }
        
        for i in 0..<outwardIterations {
            let departureTime = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedStart) ?? normalizedStart
            let outwardNumber = currentStart + (i * 2)
            
            let specs = makeTrainSpecs(baseNumber: outwardNumber, line: line, currentType: selectedTrainType.rawValue)
            
            let outwardTrain = Train(
                id: UUID(),
                number: specs.number,
                name: specs.name, // Now uses prefix + number
                type: selectedTrainType.rawValue,
                maxSpeed: selectedTrainType.defaultMaxSpeed,
                priority: selectedTrainType.defaultPriority,
                lineId: line.id,
                departureTime: departureTime,
                stops: outwardStops
            )
            generatedTrains.append(outwardTrain)
        }
        
        // 3. GENERATE RETURN
        if scheduleReturn {
            let returnStops = stationSequence.reversed().map { sid -> RelationStop in
                let node = network.nodes.first(where: { $0.id == sid })
                let defaultDwell = (node?.type == .interchange) ? 5 : 3
                // PIGNOLO PROTOCOL: Return trains prefer Track 2 on multi-track/hubs
                let preferredTrack = ((node?.platforms ?? 1) > 1) ? "2" : "1"
                return RelationStop(stationId: sid, minDwellTime: defaultDwell, track: preferredTrack)
            }
            
            let normalizedRStart = normalizeDate(returnStartTime)
            let normalizedREnd = normalizeDate(returnEndTime)
            
            let returnIterations: Int
            if mode == .single { returnIterations = 1 }
            else {
                let sMin = calendar.component(.hour, from: normalizedRStart) * 60 + calendar.component(.minute, from: normalizedRStart)
                var eMin = calendar.component(.hour, from: normalizedREnd) * 60 + calendar.component(.minute, from: normalizedREnd)
                if eMin < sMin { eMin += 24 * 60 }
                returnIterations = (eMin - sMin) / returnIntervalMinutes + 1
            }
            
            // Re-resolve rLineObj
             let rLineObj = network.lines.first(where: { 
                 $0.originId == line.destinationId && $0.destinationId == line.originId 
            }) ?? line
            let rLineId = rLineObj.id
            
            for i in 0..<returnIterations {
                let departureTime = calendar.date(byAdding: .minute, value: i * returnIntervalMinutes, to: normalizedRStart) ?? normalizedRStart
                let returnNumber = returnStartNumber + (i * 2)
                
                let specs = makeTrainSpecs(baseNumber: returnNumber, line: rLineObj, currentType: selectedTrainType.rawValue)
                
                let returnTrain = Train(
                    id: UUID(),
                    number: specs.number,
                    name: specs.name,
                    type: selectedTrainType.rawValue,
                    // ... continuation handled by existing code

                    maxSpeed: selectedTrainType.defaultMaxSpeed,
                    priority: selectedTrainType.defaultPriority,
                    lineId: rLineId,
                    departureTime: departureTime,
                    stops: returnStops
                )
                generatedTrains.append(returnTrain)
            }
        }
        
        print("🚄 [GEN] Treni generati totali: \(generatedTrains.count). (Andata + Ritorno)")
        
        aiStatus = "starting_pipeline".localized
        
        // PIGNOLO PROTOCOL: Integration of new unified pipeline
        let optimizedTrains = await RailwayScheduleOptimizer.shared.executePipeline(
            newTrains: generatedTrains,
            existingTrains: manager.trains,
            network: network,
            useAI: appState.useCloudAI && !forceLocal,
            geneticOptimizer: geneticOptimizer
        )
        
        manager.trains.append(contentsOf: optimizedTrains)
        manager.validateSchedules(with: network)
        
        aiStatus = nil
        dismiss()
    }
    
    @MainActor
    private func optimizeWithCloudAI(_ newTrains: [Train]) async {
        aiStatus = "preparation".localized
        let service = RailwayAIService.shared
        
        // 1. We must calculate proper arrival/departure times for NEW trains before AI can see conflicts
        // We use a temporary local copy to avoid modifying the main manager until AI responds
        var tempTrains = manager.trains + newTrains
        
        // PIGNOLO PROTOCOL: Refreshing times for the whole set so AI has valid schedule data
        let tempManager = TrainManager()
        tempManager.trains = tempTrains
        tempManager.refreshSchedules(with: network)
        
        let initialConflicts = tempManager.conflictManager.calculateConflicts(network: network, trains: tempManager.trains)
        print("🌐🌐🌐 [AI DEBUG] Rilevati \(initialConflicts.count) conflitti iniziali. Preparazione richiesta...")
        
        let request = service.createRequest(network: network, trains: tempManager.trains, conflicts: initialConflicts)
        print("🌐🌐🌐 [AI DEBUG] Richiesta creata per \(tempManager.trains.count) treni totali (\(newTrains.count) nuovi).")
        
        aiStatus = "sending_to_cloud".localized
        print("🌐🌐🌐 [AI DEBUG] Avvio chiamata di rete...")
        
        // Execute request using AsyncPublisher to avoid continuation hangs
        let startTime = Date()
        let timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 secondi
                let elapsed = Int(Date().timeIntervalSince(startTime))
                print("🌐🌐🌐 [AI DEBUG] In attesa da \(elapsed)s...")
            }
        }
        
        do {
            let optimizedValues = service.optimize(request: request).values
            
            // Check for cancellation before entering the wait
            if Task.isCancelled { return }
            
            let response = try await optimizedValues.first(where: { _ in true })
            
            // Check for cancellation after response
            if Task.isCancelled { return }
            
            guard let response = response else {
                print("🌐🌐🌐 [AI DEBUG] Risposta nulla/vuota dal Cloud.")
                throw NSError(domain: "Nessuna risposta ricevuta dall'AI Cloud", code: 0)
            }
            
            print("🌐🌐🌐 [AI DEBUG] Risposta ricevuta in \(Int(Date().timeIntervalSince(startTime)))s: \(response.resolutions?.count ?? 0) risoluzioni.")
            aiStatus = "applying".localized
            
            // 3. APPLY AND REFRESH
            aiStatus = "validation".localized
            var optimizedTrains = newTrains
            
            if let resolutions = response.resolutions, !resolutions.isEmpty {
                print("🌐🌐🌐 [AI DIAGNOSIS] Ricevute \(resolutions.count) risoluzioni:")
                for res in resolutions {
                    guard let uuid = service.getTrainUUID(optimizerId: res.train_id) else { 
                        print("   ❌ [ERROR] Impossibile mappare AI ID \(res.train_id) a un UUID locale.")
                        continue 
                    }
                    
                    let trainName = manager.trains.first(where: { $0.id == uuid })?.name ?? newTrains.first(where: { $0.id == uuid })?.name ?? "Sconosciuto"
                    print("   🔹 Treno \(trainName): Shift=\(res.time_adjustment_min)m, Track=\(res.track_assignment ?? -1)")
                    
                    if let index = optimizedTrains.firstIndex(where: { $0.id == uuid }) {
                        applyResolution(res, to: &optimizedTrains[index])
                    } else if let mIdx = manager.trains.firstIndex(where: { $0.id == uuid }) {
                        applyResolution(res, to: &manager.trains[mIdx])
                    }
                }
            } else {
                print("🌐🌐🌐 [AI DEBUG] Nessuna risoluzione ricevuta dal Cloud AI. Aggiungo i treni non ottimizzati.")
                optimizedTrains = newTrains // Keep original trains if no resolutions
            }
            
            // 4. HYBRID REFINEMENT: Run a quick BUT POTENT local GA to fix remaining track/platform conflicts
            // after the Cloud AI has settled the global timings.
            aiStatus = "final_refinement".localized
            let refinedTrains = await geneticOptimizer.optimize(
                newTrains: optimizedTrains,
                existingTrains: manager.trains,
                network: network,
                iterations: 120 // PIGNOLO PROTOCOL: Balanced refinement (User requested not too low)
            )
            
            // PIGNOLO PROTOCOL: Total verification
            let verificationManager = TrainManager()
            verificationManager.trains = manager.trains + refinedTrains
            verificationManager.refreshSchedules(with: network)
            let postConflicts = verificationManager.conflictManager.calculateConflicts(network: network, trains: verificationManager.trains)
            
            print("\n" + String(repeating: "", count: 20))
            print("🌐🌐🌐 [AI HYBRID SUCCESS] Ottimizzazione Completata:")
            print("   📊 Conflitti Originali: \(initialConflicts.count)")
            print("   📊 Conflitti Residui: \(postConflicts.count)")
            
            if !postConflicts.isEmpty {
                print("   🚩 [AVVISO] Rimangono \(postConflicts.count) conflitti non risolvibili matematicamente:")
                for (idx, c) in postConflicts.enumerated() {
                    print("     \(idx+1). \(c.trainAName) vs \(c.trainBName) @ \(c.locationName)")
                }
            }
            print(String(repeating: "🏆", count: 20) + "\n")
            
            manager.trains.append(contentsOf: refinedTrains)
            manager.refreshSchedules(with: network) // Final global refresh
            manager.conflictManager.detectConflicts(network: network, trains: manager.trains)
            
            // 5. FINAL REPORT
            if postConflicts.isEmpty {
                print("🏆🏆🏆 [AI HYBRID SUCCESS] Tutti i conflitti sono stati risolti!")
            } else {
                print("🚩🚩🚩 [AI HYBRID WARNING] Rimangono \(postConflicts.count) conflitti dopo l'ottimizzazione.")
                for (idx, c) in postConflicts.enumerated() where idx < 5 {
                    print("   ⚠️ Conflitto \(idx+1): \(c.description) (Treni: \(c.trainAName) e \(c.trainBName))")
                }
            }
            
            aiStatus = postConflicts.isEmpty ? "optimized".localized : String(format: "almost_resolved_fmt".localized, postConflicts.count)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            aiStatus = nil
        } catch {
            timerTask.cancel()
            print("🌐🌐🌐 [AI DEBUG] ERRORE: \(error.localizedDescription)")
            aiStatus = "error".localized
            // Fallback: just add them anyway or alert
            manager.trains.append(contentsOf: newTrains)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            aiStatus = nil
        }
        timerTask.cancel() // [FIX] Stop debug logs
    }
    
    private func applyResolution(_ res: RailwayAIResolution, to train: inout Train) {
        // 1. Time Shift (Base Departure)
        // PIGNOLO PROTOCOL: Apply ALL adjustments, even micro-seconds, to respect AI precision
        if let dep = train.departureTime {
            train.departureTime = dep.addingTimeInterval(res.time_adjustment_min * 60)
        }
        
        // 2. Track Assignment (Platform)
        // [AI FIX] L'ID ritornato (es. 29, 44) è un Graph Track ID, non un numero di piattaforma (1-12).
        // Non possiamo mapparlo direttamente a una piattaforma senza una lookup table inversa.
        // Ignoriamo questo dato e ci affidiamo alla logica "Andata=1/Ritorno=2" e alla rifinitura GA locale.
        /*
        if let trackId = res.track_assignment {
            // ... Logic removed to prevent data corruption ...
        }
        */
        
        // 3. Dwell extensions (Wait Strategy)
        // Fondamentale: Aggiorniamo 'minDwellTime' affinché il ricalcolo degli orari rispetti l'attesa.
        if let extraDwells = res.dwell_delays {
            for (sIdx, extra) in extraDwells.enumerated() where sIdx < train.stops.count {
                if extra > 0 {
                    let minutesToAdd = Int(ceil(extra))
                    train.stops[sIdx].minDwellTime += minutesToAdd
                    // Optional: store in extraDwellTime for UI visualization if needed
                    train.stops[sIdx].extraDwellTime += extra
                }
            }
        }
    }
    
    private func presetTrainType() {
        // 1. Match existing trains on line
        let lineTrains = manager.trains.filter { $0.lineId == line.id }
        if let mostCommon = lineTrains.map({ $0.type }).reduce([String: Int](), { 
            var dict = $0; dict[$1, default: 0] += 1; return dict 
        }).max(by: { $0.value < $1.value })?.key {
            if let cat = TrainCategory(rawValue: mostCommon) {
                selectedTrainType = cat
                return
            }
        }
        
        // 2. Detect High-Speed tracks
        guard line.stations.count >= 2 else {
            selectedTrainType = .regional
            return
        }
        
        let hasHSTracks = line.stations.indices.dropLast().contains(where: { i in
            let from = line.stations[i]
            let to = line.stations[i+1]
            return network.edges.contains(where: { 
                (($0.from == from && $0.to == to) || ($0.from == to && $0.to == from)) && 
                $0.trackType == .highSpeed 
            })
        })
        
        if hasHSTracks {
            selectedTrainType = .highSpeed
        } else {
            selectedTrainType = .regional
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    private func estimateAccurateTravelTime() -> Int {
        guard stationSequence.count >= 2 else { return 0 }
        
        let dummyTrain = Train(
            id: UUID(),
            number: 0,
            name: "Tempo Stimato",
            type: selectedTrainType.rawValue,
            maxSpeed: selectedTrainType.defaultMaxSpeed,
            priority: selectedTrainType.defaultPriority
        )
        
        var totalSeconds: TimeInterval = 0
        var prevId = stationSequence[0]
        
        for i in 1..<stationSequence.count {
            let currentId = stationSequence[i]
            
            // LEG TRANSIT - Calculate as continuous motion between stops
            var legDistance: Double = 0
            var legMinSpeed: Double = Double.infinity
            
            if let path = network.findPathEdges(from: prevId, to: currentId) {
                for edge in path {
                    legDistance += edge.distance
                    legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                }
            }
            
            if legDistance > 0 {
                let hours = FDCSchedulerEngine.calculateTravelTime(
                    distanceKm: legDistance,
                    maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed,
                    train: dummyTrain,
                    initialSpeedKmh: 0,
                    finalSpeedKmh: 0
                )
                
                // Add transit + safety padding (minimum 60s total)
                let transitDuration = hours * 3600
                let realTransitDuration = max(transitDuration + 35.0, 60.0)
                totalSeconds += realTransitDuration
                
                // Add dwell time (except last station)
                if i < stationSequence.count - 1 {
                    let node = network.nodes.first(where: { $0.id == currentId })
                    let dwell = (node?.type == .interchange) ? 5 : 3
                    totalSeconds += Double(dwell) * 60
                }
            }
            prevId = currentId
        }
        
        return Int(ceil(totalSeconds / 60.0))
    }
    
    private var aiServiceConnectionColor: Color {
        switch RailwayAIService.shared.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        default: return .red
        }
    }
    
    private func stationName(_ id: String) -> String {
        if id.isEmpty { return "Seleziona..." }
        return network.nodes.first(where: { $0.id == id })?.name ?? "Sconosciuta"
    }


    private func estimateTravelTimeBetween(_ fromId: String, _ toId: String, in network: RailwayNetwork) -> Int {
        let stations = network.findShortestPath(from: fromId, to: toId)?.0 ?? []
        guard stations.count >= 2 else { return 0 }
        
        let dummyTrain = Train(id: UUID(), number: 0, name: "", type: selectedTrainType.rawValue, maxSpeed: selectedTrainType.defaultMaxSpeed, priority: selectedTrainType.defaultPriority)
        var totalSeconds: TimeInterval = 0
        var prevId = stations[0]
        
        for i in 1..<stations.count {
            let currentId = stations[i]
            if let path = network.findPathEdges(from: prevId, to: currentId) {
                var legDistance: Double = 0
                var legMinSpeed: Double = Double.infinity
                for edge in path {
                    legDistance += edge.distance
                    legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                }
                if legDistance > 0 {
                    let hours = FDCSchedulerEngine.calculateTravelTime(distanceKm: legDistance, maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed, train: dummyTrain, initialSpeedKmh: 0, finalSpeedKmh: 0)
                    totalSeconds += (hours * 3600) + 35.0
                    if i < stations.count - 1 {
                        let node = network.nodes.first(where: { $0.id == currentId })
                        let dwell = (node?.type == .interchange) ? 5 : 3
                        totalSeconds += Double(dwell) * 60
                    }
                }
            }
            prevId = currentId
        }
        return Int(ceil(totalSeconds / 60.0))
    }

    
}
