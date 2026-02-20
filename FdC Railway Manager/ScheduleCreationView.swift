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
    @State private var selectedVehicle: Vehicle? = nil
    @State private var suggestedVehicles: [Vehicle] = []
    @State private var startNumber: Int = 2  // Pari inizia da 2, dispari da 1
    @State private var preferredParity: NumberParity = .even {
        didSet {
            // Automatically update startNumber when parity changes
            startNumber = (preferredParity == .odd) ? 1 : 2
        }
    }
    
    // Path selection within the line
    @State private var startStationId: String = ""
    @State private var viaStationIds: [String] = []
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = false
    @State private var activePicker: PickerType?
    @State private var manualStationId: String = ""
    @State private var isInitializing: Bool = true
    
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
    
    @State private var aiStatus: String? = nil
    @State private var aiTask: Task<Void, Never>? = nil

    // AI Analysis
    @State private var lineAnalysis: RailwayAIService.LineAnalysis? = nil
    @State private var isAnalyzingLine: Bool = false
    
    // Local Cadence Optimizer
    @StateObject private var cadenceOptimizer = CadenceOptimizer()
    @State private var localProposedOffset: Double? = nil
    
    // Vehicle Rotation Optimizer
    private let vehicleRotationOptimizer = VehicleRotationOptimizer()
    @State private var optimizeVehicleRotation: Bool = true
    @State private var minimumTurnaroundTime: Int = 15

    // Preview
    @State private var previewCount: Int = 0
    @State private var estimatedTravelTime: Int = 0
    @State private var estimatedDistance: Double = 0
    
    // Schedule Preview & Confirmation
    @State private var generatedTrains: [Train]? = nil
    
    // Train Model Selection
    @State private var selectedModel: TrainModel? = nil
    @State private var showModelSelector = false
    
    // Departure Time Optimizer
    @State private var useDepartureOptimizer: Bool = true
    private let departureOptimizer = DepartureTimeOptimizer()
    @State private var optimizerProgress: Double = 0.0
    
    // Optimized times preview (shown in inspector before final generation)
    @State private var showOptimizedTimesPreview: Bool = false
    @State private var proposedOutboundTime: Date? = nil
    @State private var proposedReturnTime: Date? = nil
    @State private var proposedInterval: Int? = nil
    @State private var proposedReturnInterval: Int? = nil
    
    var body: some View {
        ZStack {
            ScrollView {
                formScrollContent
                    .padding(.top, 10)
            }
            
            if cadenceOptimizer.isRunning {
                optimizationOverlay
            }
        }

        .onAppear {
            handleOnAppear()
        }
        .onChange(of: appState.optimizedTimesConfirmed) { _, confirmed in
            print("🔔 [onChange] optimizedTimesConfirmed changed to: \(confirmed)")
            print("   previewData exists: \(appState.optimizedTimesPreviewData != nil)")
            
            if confirmed, let previewData = appState.optimizedTimesPreviewData {
                print("✅ [onChange] Applying optimized times and generating schedule")
                // User confirmed optimized times, apply them and generate trains
                startTime = previewData.proposedOutboundTime
                if let returnTime = previewData.proposedReturnTime {
                    returnStartTime = returnTime
                }
                if let interval = previewData.proposedInterval {
                    intervalMinutes = interval
                }
                if let returnInterval = previewData.proposedReturnInterval {
                    returnIntervalMinutes = returnInterval
                }
                
                print("   Applied times - Start: \(formatTime(startTime)), Interval: \(intervalMinutes)min")
                
                // Clear preview state
                appState.optimizedTimesPreviewData = nil
                appState.optimizedTimesConfirmed = false
                
                // Now generate the schedule with the confirmed times
                print("   Launching generateSchedule task...")
                aiTask = Task { await generateSchedule() }
            } else {
                print("⚠️ [onChange] Conditions not met - confirmed: \(confirmed), previewData: \(appState.optimizedTimesPreviewData != nil)")
            }
        }
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
            Text("PERCORSO DI LINEA")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    stationPill(title: "Partenza", id: startStationId, type: .start)
                    
                    HStack {
                        Image(systemName: "arrow.down")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.leading, 12)
                        Spacer()
                    }
                    
                    stationPill(title: "Arrivo", id: endStationId, type: .end)
                }
                
                if !viaStationIds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VIA").font(.caption2.bold()).foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viaStationIds.indices, id: \.self) { idx in
                                    stationPill(title: nil, id: viaStationIds[idx], type: .via(idx))
                                }
                                Button(action: { viaStationIds.append("") }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } else {
                    Button(action: { viaStationIds.append("") }) {
                        Label("Aggiungi tappa intermedia", systemImage: "plus.circle")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    private func stationPill(title: String?, id: String, type: PickerType) -> some View {
        Button(action: { activePicker = type }) {
            VStack(alignment: .leading, spacing: 2) {
                if let t = title {
                    Text(t).font(.caption2).bold().foregroundColor(.secondary)
                }
                Text(stationName(id))
                    .font(.headline)
                    .foregroundColor(id.isEmpty ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var pathInfoRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DETTAGLI SERVIZIO")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    MetricView(label: "Stazioni", value: "\(stationSequence.count)")
                    MetricView(label: "Distanza", value: String(format: "%.1fkm", estimatedDistance))
                    MetricView(label: "Durata St.", value: "\(estimatedTravelTime)m")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "train.side.front.car")
                        .foregroundColor(.blue)
                    Text("Tipologia Treno").font(.subheadline)
                    Spacer()
                    Picker("train_type".localized, selection: $selectedTrainType) {
                        ForEach(TrainCategory.allCases) { cat in
                            Text(cat.localizedName).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: selectedTrainType) { _, _ in
                        updateSuggestedVehicles()
                    }
                }
                
                // Vehicle Selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bus.doubledecker.fill")
                            .foregroundColor(.orange)
                        Text("Materiale Rotabile").font(.subheadline.bold())
                        if let vehicle = selectedVehicle {
                            Spacer()
                            Text("✓").foregroundColor(.green)
                        }
                    }
                    
                    vehicleSelectionMenu
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    private var vehicleSelectionMenu: some View {
        Button(action: { showModelSelector = true }) {
            HStack {
                if let model = selectedModel {
                    // Show selected model with photo and specs
                    Group {
                        if let imageName = model.asset_name, !imageName.isEmpty, let _ = UIImage(named: imageName) {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "train.side.front.car")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .clipped()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.nome)
                            .font(.subheadline.bold())
                        Text("\(model.costruttore) • \(model.specifiche.velocita_max_kmh)km/h • \(String(format: "%.1f", model.fisica.accelerazione_m_s2))m/s²")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Seleziona modello treno...")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(10)
        }
        .sheet(isPresented: $showModelSelector) {
            TrainModelSelectorView(
                selectedModel: $selectedModel,
                lineCharacteristics: calculateLineCharacteristics()
            )
        }
    }
    
    private func infoLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary).bold()
            Text(value).font(.body)
        }
    }

    private var cadenceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROGRAMMAZIONE ORARIA")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                // Genetic Optimizer Toggle
                Toggle(isOn: $useDepartureOptimizer) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ottimizzatore Genetico")
                                .font(.subheadline.bold())
                            Text(mode == .single ? 
                                 "Trova automaticamente gli orari di partenza ottimali" : 
                                 "Ottimizza orari iniziali e intervalli tra i treni")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                .padding(.vertical, 8)
                
                Divider().background(Color.white.opacity(0.2))
                
                // Outward
                cadenceBlock(title: directionTitle(isReturn: false), 
                           isReturn: false,
                           sTime: $startTime, 
                           eTime: $endTime, 
                           interv: $intervalMinutes,
                           sNum: $startNumber)
                
                if scheduleReturn {
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Return
                    cadenceBlock(title: directionTitle(isReturn: true), 
                               isReturn: true,
                               sTime: $returnStartTime, 
                               eTime: $returnEndTime, 
                               interv: $returnIntervalMinutes,
                               sNum: $returnStartNumber)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    private func cadenceBlock(title: String, isReturn: Bool, sTime: Binding<Date>, eTime: Binding<Date>, interv: Binding<Int>, sNum: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isReturn ? "arrow.left" : "arrow.right")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                Text(title).font(.subheadline.bold())
            }
            
            HStack {
                Text("Inizio").font(.caption).foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: sTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            
            if mode == .cadenced {
                HStack {
                    Text("Fine").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    DatePicker("", selection: eTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Frequenza").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Stepper("\(interv.wrappedValue)m", value: interv, in: 5...360, step: 5)
                        .font(.caption.bold())
                }
            }
            
            HStack {
                Text("Parità").font(.caption).foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $preferredParity) {
                    ForEach(NumberParity.allCases) { parity in
                        Text(parity.localizedName).tag(parity)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            
            HStack {
                Text("N. Partenza").font(.caption).foregroundColor(.secondary)
                Spacer()
                TextField("", value: sNum, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline.bold())
                    .frame(width: 80)
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Button(action: { findIdealBaseTime(isReturn: isReturn) }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text(cadenceOptimizer.isRunning ? "Calcolo in corso..." : "Trova slot ideale")
                }
                .font(.caption.bold())
                .foregroundColor(.blue)
            }
            .padding(.top, 4)
            .disabled(cadenceOptimizer.isRunning || stationSequence.count < 2)
        }
    }
    
    private func findIdealBaseTime(isReturn: Bool) {
        optimizationStartTime = Date()
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
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 20) {
                VStack(alignment: .center) {
                    Text("CORSE").font(.caption2).foregroundColor(.secondary)
                    Text("\(previewCount)")
                        .font(.title2.bold())
                        .foregroundColor(.blue)
                }
                
                Divider().frame(height: 30)
                
                Toggle(isOn: $optimizeVehicleRotation) {
                    VStack(alignment: .leading) {
                        Text("TURNI").font(.caption2).bold()
                        Text("Ottimizza mezzi").font(.caption).foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
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
    
    /// Calcola gli orari ottimizzati e mostra l'alert di conferma
    /// NOTA: DepartureTimeOptimizer (genetico) DISABILITATO - mantiene frequenza impostata dall'utente
    @MainActor
    private func proposeOptimizedTimes() async {
        print("🧬 [OPTIMIZER] proposeOptimizedTimes() called - SIMPLIFIED VERSION")
        print("   scheduleReturn: \(scheduleReturn)")
        print("   mode: \(mode.rawValue)")
        print("   stationSequence.count: \(stationSequence.count)")
        print("   intervalMinutes: \(intervalMinutes) (MUST BE PRESERVED)")
        print("   returnIntervalMinutes: \(returnIntervalMinutes) (MUST BE PRESERVED)")
        
        // Verifica che ci siano almeno 2 stazioni
        guard stationSequence.count >= 2 else {
            print("   ❌ ERROR: Not enough stations (\(stationSequence.count))")
            aiStatus = "Errore: Aggiungi almeno 2 stazioni"
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            aiStatus = nil
            return
        }
        
        // Genera direttamente usando gli orari e frequenze impostati dall'utente
        // L'unica ottimizzazione è trovare lo slot migliore (offset) per ridurre conflitti
        print("   ✅ Generating schedule with USER-SET frequency (no genetic optimization)")
        aiTask = Task { await generateSchedule() }
    }
    
    @MainActor
    private func generateSchedule(forceLocal: Bool = false) async {
        let calendar = Calendar.current
        
        print("\n🚀 [GEN] ===== INIZIO GENERAZIONE ORARIO =====")
        print("   Linea: \(line.name)")
        print("   Modalità: \(mode.rawValue)")
        print("   Stazioni: \(stationSequence.count) → \(stationSequence)")
        print("   Tipo treno: \(selectedTrainType.rawValue)")
        print("   Orario partenza: \(formatTime(startTime))")
        if mode == .cadenced {
            print("   Orario fine: \(formatTime(endTime))")
            print("   Intervallo: \(intervalMinutes) minuti")
        }
        print("   Genera ritorno: \(scheduleReturn)")
        print("   Ottimizzatore orari partenza: \(useDepartureOptimizer)")
        
        // PRE-FLIGHT CHECK: Validate station sequence
        guard stationSequence.count >= 2 else {
            print("❌ [GEN] ERRORE: Sequenza stazioni insufficiente (\(stationSequence.count) stazioni)")
            print("   La linea '\(line.name)' deve avere almeno 2 stazioni configurate.")
            print("   Aggiungi le stazioni alla linea prima di generare gli orari.")
            aiStatus = nil
            return
        }
        
        // 1. PRE-FLIGHT SIMULATION: Analyze real timing to find critical stations
        aiStatus = "line_analysis".localized
        
        // Ensure startNumber matches parity
        var currentStart = startNumber
        let isEven = currentStart % 2 == 0
        if preferredParity == .even && !isEven { currentStart += 1 }
        if preferredParity == .odd && isEven { currentStart += 1 }

        let outwardStops = stationSequence.enumerated().map { index, sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            
            // Platform assignment logic:
            // - Departure station: Use platform 1
            // - Arrival station: Use platform 1 (will switch for return)
            // - Intermediate stations: Use platform 1 for outward direction
            let isFirst = index == 0
            let isLast = index == stationSequence.count - 1
            let track: String
            
            if isFirst || isLast {
                // Terminal stations: use platform 1 for outward
                track = "1"
            } else {
                // Intermediate stations: use platform 1 (same direction)
                track = "1"
            }
            
            return RelationStop(stationId: sid, minDwellTime: defaultDwell, track: track)
        }
        
        let normalizedStart = normalizeDate(startTime)
        let normalizedRStartDraft = normalizeDate(returnStartTime)

        // 1a. Probe Simulation
        // Use selected vehicle physics if available, otherwise use default
        let physics: (acceleration: Double, deceleration: Double, maxSpeed: Double)
        if let vehicle = selectedVehicle {
            physics = (
                acceleration: vehicle.acceleration,
                deceleration: vehicle.deceleration,
                maxSpeed: vehicle.maxSpeed
            )
            print("   🚂 Usando mezzo: \(vehicle.name) (\(vehicle.model))")
            print("      Accelerazione: \(vehicle.acceleration) m/s²")
            print("      Decelerazione: \(vehicle.deceleration) m/s²")
            print("      Velocità max: \(vehicle.maxSpeed) km/h")
        } else {
            let defaultPhysics = appState.getPhysics(for: selectedTrainType)
            physics = (
                acceleration: defaultPhysics.acceleration,
                deceleration: defaultPhysics.deceleration,
                maxSpeed: Double(selectedTrainType.defaultMaxSpeed)
            )
            print("   ⚙️ Usando valori di default per tipo: \(selectedTrainType.rawValue)")
        }
        
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
                preferredTrack: "1",
                vehicleId: selectedVehicle?.id
            )
            #if DEBUG
            print("🚂 [GEN] Created outward train \(outwardTrain.name) with \(outwardTrain.stops.count) stops, departure: \(departureTime)")
            #endif
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
                    preferredTrack: "2",
                    vehicleId: selectedVehicle?.id
                )
                #if DEBUG
                print("🚂 [GEN] Created return train \(returnTrain.name) with \(returnTrain.stops.count) stops, departure: \(departureTime)")
                #endif
                generatedTrains.append(returnTrain)
            }
        }
        
        print("🚄 [GEN] Treni generati totali: \(generatedTrains.count). (Andata + Ritorno)")
        
        // CRITICAL CHECK: Verify we actually generated trains
        guard !generatedTrains.isEmpty else {
            print("❌ [GEN] ERRORE CRITICO: Nessun treno generato! generatedTrains è vuoto.")
            print("   Debug info: mode=\(mode), outwardIterations dovrebbe essere > 0")
            print("   stationSequence: \(stationSequence)")
            aiStatus = nil
            return
        }
        
        // VALIDATION: Check for trains with 0 stops (invalid)
        let validTrains = generatedTrains.filter { !$0.stops.isEmpty }
        let invalidCount = generatedTrains.count - validTrains.count
        if invalidCount > 0 {
            print("⚠️ [GEN] WARNING: \(invalidCount) trains had 0 stops and were filtered out")
            for train in generatedTrains where train.stops.isEmpty {
                print("   • Invalid train: \(train.name) (stops: \(train.stops.count))")
            }
        }
        generatedTrains = validTrains
        
        // Verify we still have trains after validation
        guard !generatedTrains.isEmpty else {
            print("❌ [GEN] ERRORE CRITICO: All trains were invalid (0 stops)")
            print("   Impossibile generare treni: la linea '\(line.name)' non ha stazioni configurate.")
            print("   Aggiungi almeno 2 stazioni alla linea prima di generare gli orari.")
            aiStatus = nil
            return
        }
        
        // Log detailed info about generated trains
        for train in generatedTrains {
            print("   Train '\(train.name)': \(train.stops.count) stops")
        }
        
        aiStatus = "starting_pipeline".localized
        optimizationStartTime = Date()
        
        // PIGNOLO PROTOCOL: Integration of new unified pipeline
        // PIGNOLO PROTOCOL: Capture thread-safe copies of nodes/edges while on MainActor
        let nodesCopy = network.nodes
        let edgesCopy = network.edges
        
        print("🔧 [GEN] Avvio pipeline con \(generatedTrains.count) treni, \(nodesCopy.count) nodi, \(edgesCopy.count) edges")
        
        // Usa la pipeline semplificata senza ottimizzazione genetica
        let optimizedTrains = await RailwayScheduleOptimizer.shared.executePipeline(
            newTrains: generatedTrains,
            existingTrains: manager.trains,
            nodes: nodesCopy,
            edges: edgesCopy,
            useAI: false,  // Disabilitato AI
            useGA: false,  // Disabilitato GA
            geneticOptimizer: nil
        )
        
        print("✅ [GEN] Pipeline completed, returned \(optimizedTrains.count) trains")
        
        // CRITICAL CHECK: Verify pipeline didn't return empty
        guard !optimizedTrains.isEmpty else {
            print("❌ [GEN] ERRORE CRITICO: Pipeline ha ritornato 0 treni! Input era \(generatedTrains.count)")
            print("   Questo potrebbe indicare un problema nella pipeline di ottimizzazione.")
            aiStatus = nil
            return
        }
        
        #if DEBUG
        for train in optimizedTrains.prefix(3) {
            print("   Train '\(train.name)': \(train.stops.count) stops")
            for (i, stop) in train.stops.prefix(3).enumerated() {
                let arr = stop.arrival.map { formatTime($0) } ?? "nil"
                let dep = stop.departure.map { formatTime($0) } ?? "nil"
                print("      Stop \(i) (\(stop.stationId)): arr=\(arr), dep=\(dep)")
            }
        }
        #endif
        
        // Apply vehicle rotation optimization if enabled
        var finalTrains = optimizedTrains
        if optimizeVehicleRotation {
            print("🔄 [GEN] Optimizing vehicle rotations...")
            aiStatus = "Ottimizzazione turni mezzi..."
            
            let assignment = vehicleRotationOptimizer.optimizeVehicleAssignment(
                trains: finalTrains,
                vehicles: manager.vehicles,
                minimumTurnaroundTime: minimumTurnaroundTime
            )
            
            // Apply assignments
            for (vehicleId, trainIds) in assignment {
                for trainId in trainIds {
                    if let index = finalTrains.firstIndex(where: { $0.id == trainId }) {
                        finalTrains[index].vehicleId = vehicleId
                    }
                }
            }
            
            let assignedCount = finalTrains.filter { $0.vehicleId != nil }.count
            print("✅ [GEN] Assigned \(assignedCount)/\(finalTrains.count) trains to \(assignment.count) vehicles")
        }
        
        print("✅ [GEN] Generazione completata! \(finalTrains.count) treni pronti per l'anteprima")
        
        // Salva i treni generati per l'anteprima e mostra nell'inspector
        generatedTrains = finalTrains
        appState.schedulePreviewTrains = finalTrains
        appState.schedulePreviewLine = line
        appState.schedulePreviewMode = mode
        appState.schedulePreviewSelectedModel = selectedModel
        appState.schedulePreviewOptimizeVehicles = optimizeVehicleRotation
        appState.schedulePreviewMinTurnaroundTime = minimumTurnaroundTime
        
        aiStatus = nil
    }
    
    // MARK: - Schedule Preview Actions
    
    func acceptScheduleFromPreview() {
        acceptSchedule()
    }
    
    private func acceptSchedule() {
        guard var trains = generatedTrains else { return }
        
        print("✅ [PREVIEW] Utente ha accettato l'orario: aggiunta di \(trains.count) treni")
        
        // Se l'utente ha selezionato un modello e l'ottimizzazione rotazione è attiva, crea i veicoli fisici
        if let model = selectedModel, optimizeVehicleRotation {
            print("🚂 [VEHICLES] Creazione automatica veicoli da modello: \(model.nome)")
            
            // Calcola il numero di veicoli necessari
            let requiredVehicles = vehicleRotationOptimizer.suggestVehicleCount(
                for: trains,
                minimumTurnaroundTime: minimumTurnaroundTime
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
            let assignment = vehicleRotationOptimizer.optimizeVehicleAssignment(
                trains: trains,
                vehicles: createdVehicles,
                minimumTurnaroundTime: minimumTurnaroundTime
            )
            
            // Applica le assegnazioni
            for (vehicleId, trainIds) in assignment {
                for trainId in trainIds {
                    if let index = trains.firstIndex(where: { $0.id == trainId }) {
                        trains[index].vehicleId = vehicleId
                    }
                }
            }
            
            let assignedCount = trains.filter { $0.vehicleId != nil }.count
            print("✅ [VEHICLES] Assegnati \(assignedCount)/\(trains.count) treni a \(assignment.count) veicoli")
        }
        
        // Aggiungi i treni al manager
        manager.trains.append(contentsOf: trains)
        print("✅ [PREVIEW] Manager ora ha \(manager.trains.count) treni totali")
        
        // Valida gli orari
        manager.validateSchedules()
        
        print("🎉 [PREVIEW] Orario applicato con successo!")
        
        // Clear preview state
        appState.schedulePreviewTrains = nil
        appState.schedulePreviewLine = nil
        
        // Select the line to show timetable
        appState.selectedLineId = line.id
        appState.sidebarSelection = .lines
        
        // Close schedule creation inspector
        generatedTrains = nil
        appState.creationLineId = nil
    }
    
    private func rejectSchedule() {
        print("❌ [PREVIEW] Utente ha rifiutato l'orario")
        
        // Clear preview and return to schedule creation
        appState.schedulePreviewTrains = nil
        appState.schedulePreviewLine = nil
        generatedTrains = nil
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
            // Don't override station sequence during initialization
            guard !isInitializing else { return }
            
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
        VStack(spacing: 24) {
            // Header con selettore modalità
            HStack {
                Text("Modalità").font(.caption.bold()).foregroundColor(.secondary)
                Spacer()
                Picker("mode".localized, selection: $mode) {
                    ForEach(ScheduleMode.allCases) { m in
                        Text(m.localizedName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            stationSelectSection
            pathInfoRow
            
            generateReturnToggle
            
            cadenceSelectionSection
            
            previewSection
            
            actionButtonsSection
        }
        .padding(.bottom, 40)
    }

    private var optimizationOverlay: some View {
        ZStack {
            if cadenceOptimizer.isRunning {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack(spacing: 24) {
                    // Title
                    Text(cadenceOptimizer.isRunning ? "Calcolo Slot Ideale..." : "Ottimizzazione Orario...")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                        .padding(.top, 8)
                    
                    // MARK: - New Conflict Counter Bar
                    HStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .symbolEffect(.pulse)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CONFLITTI RIMANENTI")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                            
                            let count = cadenceOptimizer.isRunning ? (cadenceOptimizer.fitness.isFinite ? Int(cadenceOptimizer.fitness / 1000) : 0) : 0
                            let isClean = count == 0
                            
                            Text(isClean ? "NESSUNO" : "\(count)")
                                .font(.system(.title, design: .rounded).bold())
                                .foregroundColor(isClean ? .green : .primary)
                                .contentTransition(.numericText())
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Progress
                    VStack(spacing: 8) {
                        let progress = cadenceOptimizer.progress
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                        
                        HStack {
                            Text("\(Int(progress * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                    }
                }
                .padding(30)
                .frame(maxWidth: 400)
                .background(.regularMaterial)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cadenceOptimizer.isRunning)
    }
    
    @State private var optimizationStartTime: Date? = nil
    private func handleOnAppear() {
        print("📍 [ScheduleCreationView] handleOnAppear for line: \(line.name)")
        print("   Line ID: \(line.id)")
        print("   Origin: \(line.originId), Destination: \(line.destinationId)")
        print("   Line.stops.count: \(line.stops.count)")
        print("   Line.stops: \(line.stops)")
        
        startStationId = line.originId
        endStationId = line.destinationId
        stationSequence = line.stations
        
        print("   Line.stations.count: \(line.stations.count)")
        print("   Stations: \(line.stations)")
        print("   stationSequence.count: \(stationSequence.count)")
        print("   stationSequence: \(stationSequence)")
        
        // Mark initialization as complete to allow onChange handlers to work
        isInitializing = false
        
        // Debug: Check optimized times state
        print("🔍 [handleOnAppear] Checking optimized times state:")
        print("   optimizedTimesConfirmed: \(appState.optimizedTimesConfirmed)")
        print("   optimizedTimesPreviewData exists: \(appState.optimizedTimesPreviewData != nil)")
        
        // Check if there are confirmed optimized times to apply
        if appState.optimizedTimesConfirmed, let previewData = appState.optimizedTimesPreviewData {
            print("✅ [handleOnAppear] Found confirmed optimized times, applying and generating...")
            // Apply optimized times
            startTime = previewData.proposedOutboundTime
            if let returnTime = previewData.proposedReturnTime {
                returnStartTime = returnTime
            }
            if let interval = previewData.proposedInterval {
                intervalMinutes = interval
            }
            if let returnInterval = previewData.proposedReturnInterval {
                returnIntervalMinutes = returnInterval
            }
            
            // Clear preview state
            appState.optimizedTimesPreviewData = nil
            appState.optimizedTimesConfirmed = false
            
            // Generate schedule with confirmed times
            print("   Launching generateSchedule from handleOnAppear...")
            aiTask = Task { await generateSchedule() }
            return  // Don't continue with normal initialization
        } else if appState.optimizedTimesPreviewData != nil {
            print("⚠️ [handleOnAppear] Preview data exists but not confirmed yet - showing preview")
        } else {
            print("ℹ️ [handleOnAppear] No optimized times to apply, proceeding with normal init")
        }
        
        // Sync return times
        returnStartTime = startTime
        returnEndTime = endTime
        returnIntervalMinutes = intervalMinutes
        
        presetTrainType()
        updateSuggestedVehicles()
        
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
    
    private func updateSuggestedVehicles() {
        // Get all available vehicles
        let allVehicles = manager.vehicles
        
        print("🚂 [updateSuggestedVehicles] Available vehicles: \(allVehicles.count)")
        if allVehicles.isEmpty {
            print("   ⚠️ No vehicles available! Check if vehicles are loaded.")
            return
        }
        
        // Filter by train type capabilities
        var filtered = allVehicles.filter { vehicle in
            switch selectedTrainType {
            case .highSpeed:
                return vehicle.maxSpeed >= 250
            case .direct:
                return vehicle.maxSpeed >= 160 && vehicle.maxSpeed < 250
            case .regional:
                return vehicle.maxSpeed >= 120 && vehicle.maxSpeed < 200
            case .freight:
                return vehicle.maxSpeed < 120
            case .support:
                return true
            }
        }
        
        // Calculate line requirements
        let lineDistance = estimatedDistance
        // Use a default speed based on train type for now
        let lineMaxSpeed: Double = {
            switch selectedTrainType {
            case .highSpeed: return 300.0
            case .direct: return 200.0
            case .regional: return 160.0
            case .freight: return 100.0
            case .support: return 120.0
            }
        }()
        
        // Score vehicles based on suitability
        filtered = filtered.sorted { v1, v2 in
            let score1 = vehicleSuitabilityScore(v1, lineDistance: lineDistance, lineMaxSpeed: lineMaxSpeed)
            let score2 = vehicleSuitabilityScore(v2, lineDistance: lineDistance, lineMaxSpeed: lineMaxSpeed)
            return score1 > score2
        }
        
        // Take top 3 suggestions
        suggestedVehicles = Array(filtered.prefix(3))
        
        // Auto-select first suggestion if none selected
        if selectedVehicle == nil && !suggestedVehicles.isEmpty {
            selectedVehicle = suggestedVehicles[0]
        }
    }
    
    private func vehicleSuitabilityScore(_ vehicle: Vehicle, lineDistance: Double, lineMaxSpeed: Double) -> Double {
        var score = 0.0
        
        // 1. Speed match (most important - 40% weight)
        let speedDiff = abs(vehicle.maxSpeed - lineMaxSpeed)
        let speedScore = max(0, 100 - speedDiff)
        score += speedScore * 0.4
        
        // 2. Number of stops and acceleration (30% weight)
        let numberOfStops = stationSequence.count
        let avgStopDistance = lineDistance / Double(max(numberOfStops - 1, 1))
        
        // For frequent stops (< 10km average), prioritize good acceleration
        if avgStopDistance < 10 {
            let accelerationScore = min(vehicle.acceleration * 30, 100) // Max 100 points
            score += accelerationScore * 0.3
        } else if avgStopDistance < 20 {
            // Medium stops - balanced acceleration/speed
            let accelerationScore = min(vehicle.acceleration * 20, 100)
            score += accelerationScore * 0.2
            // Add some speed bonus for longer distances
            score += min((vehicle.maxSpeed / lineMaxSpeed) * 50, 50) * 0.1
        } else {
            // Long distances - prioritize high speed and capacity
            let speedCapabilityScore = min((vehicle.maxSpeed / lineMaxSpeed) * 100, 100)
            score += speedCapabilityScore * 0.3
        }
        
        // 3. Line distance vs vehicle range/capacity (20% weight)
        // Prefer vehicles suitable for the total distance
        if lineDistance > 100 {
            // Long lines - prefer high-capacity, long-range vehicles
            if vehicle.maxSpeed >= 160 {
                score += 20 * 0.2
            }
        } else if lineDistance > 50 {
            // Medium lines - balanced vehicles
            if vehicle.maxSpeed >= 120 && vehicle.maxSpeed <= 200 {
                score += 20 * 0.2
            }
        } else {
            // Short lines - agile vehicles with good acceleration
            if vehicle.acceleration > 1.0 {
                score += 20 * 0.2
            }
        }
        
        // 4. Station infrastructure compatibility (10% weight)
        // Check if line has stations with platform/capacity constraints
        let minPlatforms = network.nodes
            .filter { node in stationSequence.contains(node.id) }
            .compactMap { $0.platforms }
            .min() ?? 2
        
        // Penalize if vehicle might be too demanding for small stations
        if minPlatforms <= 2 && vehicle.maxSpeed > 200 {
            // High-speed trains in small stations - slight penalty
            score -= 10 * 0.1
        }
        
        // 5. Prefer vehicles with photos (aesthetic bonus - 5% weight)
        if vehicle.imageName != nil {
            score += 5 * 0.05
        }
        
        // 6. Bonus for matching service type
        switch selectedTrainType {
        case .highSpeed:
            if vehicle.maxSpeed >= 250 && vehicle.acceleration >= 1.2 {
                score += 10
            }
        case .direct:
            if vehicle.maxSpeed >= 160 && vehicle.maxSpeed < 250 {
                score += 10
            }
        case .regional:
            if vehicle.acceleration >= 1.0 && vehicle.maxSpeed >= 100 && vehicle.maxSpeed < 160 {
                score += 10
            }
        case .freight, .support:
            break
        }
        
        return score
    }
    
    private func calculateLineCharacteristics() -> LineCharacteristics {
        let totalDistance = estimatedDistance
        let numberOfStops = stationSequence.count
        let averageStopDistance = totalDistance / Double(max(numberOfStops - 1, 1))
        let maxLineSpeed = Double(selectedTrainType.defaultMaxSpeed)
        let frequency = mode == .cadenced ? intervalMinutes : nil
        
        return LineCharacteristics(
            totalDistance: totalDistance,
            averageStopDistance: averageStopDistance,
            numberOfStops: numberOfStops,
            maxLineSpeed: maxLineSpeed,
            serviceType: selectedTrainType,
            frequency: frequency
        )
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
        let isValidConfiguration = stationSequence.count >= 2
        
        return VStack(spacing: 12) {
            if let status = aiStatus {
                // Progress bar elegante durante l'ottimizzazione
                VStack(spacing: 14) {
                    // Header con icona animata
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                                .imageScale(.medium)
                                .symbolEffect(.pulse)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Analisi in corso")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(status)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    
                    // Progress bar con sfumatura
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 8)
                            
                            // Progress bar animata
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * max(0.02, optimizerProgress), height: 8)
                                .animation(.easeInOut(duration: 0.3), value: optimizerProgress)
                        }
                    }
                    .frame(height: 8)
                    
                    // Bottone ferma
                    Button(action: {
                        aiTask?.cancel()
                        aiTask = nil
                        aiStatus = nil
                        optimizerProgress = 0.0
                        departureOptimizer.progressCallback = nil
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .imageScale(.small)
                            Text("FERMA OTTIMIZZAZIONE")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.blue.opacity(0.1), radius: 8, y: 4)
            } else {
                // Bottone normale quando non sta ottimizzando
                Button(action: {
                    aiTask = Task { await proposeOptimizedTimes() }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isValidConfiguration ? "GENERA ORARIO" : "CONFIGURA LINEA")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidConfiguration ? Color.blue : Color.gray)
                    .cornerRadius(16)
                    .shadow(color: (isValidConfiguration ? Color.blue : Color.gray).opacity(0.3), radius: 8, y: 4)
                }
                .disabled(!isValidConfiguration)
            }
            
            if !isValidConfiguration {
                Text("⚠️ Aggiungi almeno 2 stazioni alla linea")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Button(action: { appState.creationLineId = nil }) {
                Text("cancel".localized.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
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


