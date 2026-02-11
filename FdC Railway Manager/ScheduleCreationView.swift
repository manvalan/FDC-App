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
        self._startStationId = State(initialValue: line.originId)
        self._endStationId = State(initialValue: line.destinationId)
    }
    
    // GA Optimizer
    @StateObject private var geneticOptimizer = GeneticOptimizer()
    @State private var useGA: Bool = true
    @State private var aiStatus: String? = nil
    @State private var aiTask: Task<Void, Never>? = nil

    // AI Analysis
    @State private var lineAnalysis: RailwayAIService.LineAnalysis? = nil
    @State private var isAnalyzingLine: Bool = false
    
    // Local Cadence Optimizer
    @StateObject private var cadenceOptimizer = CadenceOptimizer()
    @State private var localProposedOffset: Double? = nil

    // Preview
    @State private var previewCount: Int = 0
    @State private var estimatedTravelTime: Int = 0
    @State private var estimatedDistance: Double = 0
    
    var body: some View {
        NavigationStack {
            formContent
        }
        .overlay(optimizationOverlay)
    }
    
    private func triggerLineAnalysis() {
        Task {
            isAnalyzingLine = true
            do {
                lineAnalysis = try await RailwayAIService.shared.analyzeLine(name: line.name, stationIds: stationSequence, nodes: network.nodes, edges: network.edges)
            } catch {
                print("❌ AI Line Analysis failed: \(error)")
            }
            isAnalyzingLine = false
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
            infoLabel(title: "length_short".localized, value: String(format: "%.1f km", estimatedDistance))
            infoLabel(title: "est_duration_short".localized, value: String(format: "duration_min_fmt".localized, estimatedTravelTime))
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
            
            Button(action: { findIdealBaseTime(isReturn: isReturn) }) {
                Label(cadenceOptimizer.isRunning ? "finding_slot".localized : "propose_ideal_slot".localized, 
                      systemImage: "wand.and.stars")
                    .font(.caption)
            }
            .disabled(cadenceOptimizer.isRunning || stationSequence.count < 2)
            
            if !isReturn, let offset = localProposedOffset {
                Text(String(format: "suggested_offset_fmt".localized, Int(offset)))
                    .foregroundColor(.green)
                    .font(.caption2.bold())
            }
        }
    }
    
    private func findIdealBaseTime(isReturn: Bool) {
        Task {
            let seq = isReturn ? stationSequence.reversed() : stationSequence
            let tempLine = RailwayLine(
                id: line.id,
                name: line.name,
                stops: seq.map { RelationStop(stationId: $0) }
            )
            
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: tempLine, 
                frequency: Double(isReturn ? returnIntervalMinutes : intervalMinutes), 
                existingTrains: manager.trains, 
                network: network
            )
            
            await MainActor.run {
                if isReturn {
                    // Apply offset to returnStartTime
                    let base = normalizeDate(returnStartTime)
                    let cal = Calendar.current
                    let baseStartOfDay = cal.startOfDay(for: base)
                    returnStartTime = baseStartOfDay.addingTimeInterval(offset * 60)
                } else {
                    // Apply offset to startTime
                    let base = normalizeDate(startTime)
                    let cal = Calendar.current
                    let baseStartOfDay = cal.startOfDay(for: base)
                    startTime = baseStartOfDay.addingTimeInterval(offset * 60)
                    self.localProposedOffset = offset
                }
                updatePreview()
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
        if scheduleReturn {
            let rStart = normalizeDate(returnStartTime)
            let rEnd = normalizeDate(returnEndTime)
            total += calculateCount(s: rStart, e: rEnd, interval: returnIntervalMinutes)
        }
        
        previewCount = max(0, total)
    }
    
    private func updatePathCalculations() {
        self.estimatedDistance = network.calculatePathDistance(path: stationSequence)
        self.estimatedTravelTime = calculateAccurateTravelTime()
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

        // 1a. Probe Simulation
        let physics = appState.getPhysics(for: selectedTrainType)
        
        // Find Return Line (or self)
        let rLineObj = manager.lines.first(where: { 
             $0.originId == line.destinationId && $0.destinationId == line.originId 
        }) ?? line
        
        let pOutNum = (line.numberPrefix ?? 0) * 1000 + currentStart
        let probeOut = manager.instantiateTrain(
            number: pOutNum,
            name: "Probe Out",
            category: selectedTrainType,
            departureTime: normalizedStart,
            line: line,
            stationSequence: stationSequence,
            acceleration: physics.acceleration,
            deceleration: physics.deceleration,
            preferredTrack: "1"
        )
        
            let pRetNum = (rLineObj.numberPrefix ?? 0) * 1000 + (currentStart + 1)
        let probeReturn = manager.instantiateTrain(
            number: pRetNum,
            name: "Probe Return",
            category: selectedTrainType,
            departureTime: normalizedRStartDraft,
            line: rLineObj,
            stationSequence: Array(stationSequence.reversed()),
            acceleration: physics.acceleration,
            deceleration: physics.deceleration,
            preferredTrack: "2"
        )
        
        
        
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
            let finalNumber = (line.numberPrefix ?? 0) * 1000 + outwardNumber
            
            let outwardTrain = manager.instantiateTrain(
                number: finalNumber,
                category: selectedTrainType,
                departureTime: departureTime,
                line: line,
                stationSequence: stationSequence,
                acceleration: physics.acceleration,
                deceleration: physics.deceleration,
                preferredTrack: "1"
            )
            generatedTrains.append(outwardTrain)
        }
        
        // 3. GENERATE RETURN
        if scheduleReturn {
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
            
            for i in 0..<returnIterations {
                let departureTime = calendar.date(byAdding: .minute, value: i * returnIntervalMinutes, to: normalizedRStart) ?? normalizedRStart
                let returnNumber = returnStartNumber + (i * 2)
                let finalNumber = (rLineObj.numberPrefix ?? 0) * 1000 + returnNumber
                
                let returnTrain = manager.instantiateTrain(
                    number: finalNumber,
                    category: selectedTrainType,
                    departureTime: departureTime,
                    line: rLineObj,
                    stationSequence: Array(stationSequence.reversed()),
                    acceleration: physics.acceleration,
                    deceleration: physics.deceleration,
                    preferredTrack: "2"
                )
                generatedTrains.append(returnTrain)
            }
        }
        
        print("🚄 [GEN] Treni generati totali: \(generatedTrains.count). (Andata + Ritorno)")
        
        aiStatus = "starting_pipeline".localized
        optimizationStartTime = Date()
        
        // PIGNOLO PROTOCOL: Integration of new unified pipeline
        // PIGNOLO PROTOCOL: Capture thread-safe copies of nodes/edges while on MainActor
        let nodesCopy = network.nodes
        let edgesCopy = network.edges
        
        let optimizedTrains = await RailwayScheduleOptimizer.shared.executePipeline(
            newTrains: generatedTrains,
            existingTrains: manager.trains,
            nodes: nodesCopy,
            edges: edgesCopy,
            useAI: appState.useCloudAI && useGA && !forceLocal, // AI depends on optimization being enabled
            useGA: useGA,
            geneticOptimizer: geneticOptimizer
        )
        
        manager.trains.append(contentsOf: optimizedTrains)
        manager.validateSchedules()
        
        aiStatus = nil
        dismiss()
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
    
    private func updateEstimatedTravelTime() {
        estimatedTravelTime = calculateAccurateTravelTime()
    }
    
    private func calculateAccurateTravelTime() -> Int {
        guard stationSequence.count >= 2 else { return 0 }
        
        let dummyTrain = Train(
            id: UUID(),
            number: 0,
            name: "Tempo Stimato",
            type: selectedTrainType.rawValue,
            lineId: nil,
            departureTime: nil,
            stops: [],
            vehicleId: nil,
            maxSpeed: Double(selectedTrainType.defaultMaxSpeed),
            acceleration: 0.5,
            deceleration: 0.5,
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


    private var formContent: some View {
        ScrollView {
            formScrollContent
        }
        .navigationTitle("schedule_generation".localized)
        .onAppear {
            handleOnAppear()
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
            .environmentObject(appState)
            .environmentObject(manager)
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
        .onChange(of: returnStartTime) { _ in updatePreview() }
        .onChange(of: returnEndTime) { _ in updatePreview() }
        .onChange(of: returnIntervalMinutes) { _ in updatePreview() }
        .onChange(of: scheduleReturn) { _ in updatePreview() }
        .onChange(of: stationSequence) { _, newSeq in
            if appState.useCloudAI && newSeq.count >= 2 {
                triggerLineAnalysis()
            }
            // Sync terminals with sequence
            if let first = newSeq.first { startStationId = first }
            if let last = newSeq.last { endStationId = last }
            
            updatePathCalculations()
            updatePreview()
        }
    }
    
    private var formScrollContent: some View {
        VStack(spacing: 20) {
            headerSection
            stationSelectSection
            pathPickerSection
            pathInfoRow
            cadenceSelectionSection
            previewSection
            // optimizerStatusSection REMOVED: Now handled by Overlay
            generateReturnToggle
            Divider().padding(.top)
            actionButtonsSection
        }
        .padding(.vertical)
    }

    private var optimizationOverlay: some View {
        ZStack {
            if geneticOptimizer.isRunning {
                Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("Ottimizzazione in corso...")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                    
                    ProgressView(value: geneticOptimizer.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.horizontal)
                    
                    HStack {
                        Text("\(Int(geneticOptimizer.progress * 100))%")
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                        if let time = estimatedTimeRemaining {
                            Text("Stima: \(time)")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        VStack {
                            Text("CONFLITTI")
                                .font(.caption2).bold().foregroundColor(.secondary)
                            Text("\(geneticOptimizer.conflictCount)")
                                .font(.title).bold()
                                .foregroundColor(geneticOptimizer.conflictCount == 0 ? .green : .red)
                        }
                        .frame(minWidth: 80)
                        
                        Divider().background(Color.white)
                        
                        VStack {
                            Text("GEN")
                                .font(.caption2).bold().foregroundColor(.secondary)
                            Text("\(geneticOptimizer.currentGeneration)")
                                .font(.title).bold()
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 80)
                    }
                    .padding()
                    .background(Color(white: 0.15))
                    .cornerRadius(12)
                }
                .padding(30)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 20)
                .padding(40)
            }
        }
    }
    
    @State private var optimizationStartTime: Date? = nil
    
    private var estimatedTimeRemaining: String? {
        guard let start = optimizationStartTime, geneticOptimizer.progress > 0.05 else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let totalEstimated = elapsed / geneticOptimizer.progress
        let remaining = totalEstimated - elapsed
        
        if remaining < 0 { return "0s" }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: remaining)
    }

    private func handleOnAppear() {
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
        let usedBaseNumbers = lineTrains.compactMap { t -> Int? in
            guard let num = t.number else { return nil }
            let prefix = line.numberPrefix ?? 0
            return num - (prefix * 1000)
        }.filter { $0 >= 0 && $0 < 1000 }
        
        let maxUsed = usedBaseNumbers.max() ?? -1
        startNumber = (maxUsed + 1 < 1000) ? maxUsed + 1 : 0
        
        // If parità needs sync
        if preferredParity == .even && startNumber % 2 != 0 { startNumber += 1 }
        if preferredParity == .odd && startNumber % 2 == 0 { startNumber += 1 }
        
        returnStartNumber = (startNumber + 1 < 1000) ? startNumber + 1 : 1
        
        updatePreview()
        
        // Trigger AI Line Analysis if enabled
        if appState.useCloudAI {
            triggerLineAnalysis()
        }
        updatePathCalculations()
    }
    
    private var pathPickerSection: some View {
        PathPickerComponent(
            startStationId: $startStationId,
            viaStationIds: $viaStationIds,
            endStationId: $endStationId,
            stationSequence: $stationSequence,
            manualAddition: $manualAddition,
            activePicker: $activePicker,
            manualStationId: $manualStationId,
            lineContext: line,
            lineAnalysis: lineAnalysis,
            isAnalyzing: isAnalyzingLine
        )
        .padding(.horizontal)
    }
    
    private var cadenceSelectionSection: some View {
        HStack(alignment: .top, spacing: 20) {
            cadenceColumn(title: directionTitle(isReturn: false), 
                         isReturn: false,
                         sTime: $startTime, 
                         eTime: $endTime, 
                         interv: $intervalMinutes,
                         sNum: $startNumber)
            
            Divider()
            
            cadenceColumn(title: directionTitle(isReturn: true), 
                         isReturn: true,
                         sTime: $returnStartTime, 
                         eTime: $returnEndTime, 
                         interv: $returnIntervalMinutes,
                         sNum: $returnStartNumber)
            .opacity(scheduleReturn ? 1.0 : 0.4)
            .disabled(!scheduleReturn)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var optimizerStatusSection: some View {
        Group {
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
        }
    }
    
    private var generateReturnToggle: some View {
        Toggle(isOn: $scheduleReturn) {
            Label {
                Text("generate_return_trips".localized)
                    .font(.headline)
            } icon: {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var actionButtonsSection: some View {
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
    
    private func estimateTravelTimeBetween(_ fromId: String, _ toId: String, in network: RailwayNetwork) -> Int {
        let stations = network.findShortestPath(from: fromId, to: toId)?.0 ?? []
        guard stations.count >= 2 else { return 0 }
        
        let dummyTrain = Train(
            id: UUID(),
            number: 0,
            name: "",
            type: selectedTrainType.rawValue,
            lineId: nil,
            departureTime: nil,
            stops: [],
            vehicleId: nil,
            maxSpeed: Double(selectedTrainType.defaultMaxSpeed),
            acceleration: 0.5,
            deceleration: 0.5,
            priority: selectedTrainType.defaultPriority
        )
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

    private func directionTitle(isReturn: Bool) -> String {
        if stationSequence.count >= 2 {
            let start = stationName(stationSequence.first ?? "")
            let end = stationName(stationSequence.last ?? "")
            if isReturn {
                return "\(end) ➔ \(start) (\("return".localized))"
            } else {
                return "\(start) ➔ \(end) (\("outward".localized))"
            }
        } else {
            return isReturn ? "B ➔ A (\("return".localized))" : "A ➔ B (\("outward".localized))"
        }
    }
}
