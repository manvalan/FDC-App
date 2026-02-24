import SwiftUI
import Combine

struct ScheduleCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState
    
    let line: RailwayLine
    
    // Note: ScheduleMode and NumberParity are now defined in ScheduleCreationViewModel.swift
    
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
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var isInitializing: Bool = true {
        didSet {
            // Fix parity on init
            if isInitializing {
                startNumber = (preferredParity == .odd) ? 1 : 2
                returnStartNumber = (preferredParity == .odd) ? 2 : 1
            }
        }
    }
    
    // Stop Pattern - Track which stops should be skipped
    @State private var skippedStopIds: Set<String> = []
    
    // Taktfahrplan
    @State private var taktStationId: String = ""
    
    // Computed: useTaktAlignment is true ONLY for Taktfahrplan mode
    private var useTaktAlignment: Bool {
        mode == .taktfahrplan
    }
    
    // Paired Return
    @State private var scheduleReturn: Bool = true // Enabled by default in this layout
    @State private var returnStartNumber: Int = 1
    
    // Takt / Main Train Flag
    @State private var isMainLine: Bool = true
    
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
            if confirmed, let previewData = appState.optimizedTimesPreviewData {
                startTime = previewData.proposedOutboundTime
                endTime = previewData.proposedReturnTime ?? endTime // Use return end as a proxy if it exists
                intervalMinutes = previewData.proposedInterval ?? intervalMinutes
                
                appState.optimizedTimesPreviewData = nil
                appState.optimizedTimesConfirmed = false
                aiTask = Task { await generateSchedule() }
            }
        }
        .onChange(of: mode) { _, newMode in
            // Quando si passa a Taktfahrplan, assicura che l'intervallo sia 60 o 120
            if newMode == .taktfahrplan && intervalMinutes != 60 && intervalMinutes != 120 {
                intervalMinutes = 120  // Default a 120 minuti
            }
        }
        .onChange(of: startStationId) { _, _ in
            if !isInitializing {
                withAnimation {
                    updateStationSequenceFromSelection()
                    updatePathCalculations()
                    updatePreview()
                    // Reset skipped stops when path changes significantly
                    skippedStopIds.removeAll()
                }
            }
        }
        .onChange(of: endStationId) { _, _ in
            if !isInitializing {
                withAnimation {
                    updateStationSequenceFromSelection()
                    updatePathCalculations()
                    updatePreview()
                    // Reset skipped stops when path changes significantly
                    skippedStopIds.removeAll()
                }
            }
        }
    }
    
    /// Updates stationSequence to include all stations between startStationId and endStationId
    private func updateStationSequenceFromSelection() {
        guard !startStationId.isEmpty, !endStationId.isEmpty else { return }
        
        // Find indices in line.stations
        guard let startIdx = line.stations.firstIndex(of: startStationId),
              let endIdx = line.stations.firstIndex(of: endStationId) else {
            print("⚠️ Start or end station not found in line.stations")
            return
        }
        
        // Ensure start comes before end
        if startIdx <= endIdx {
            // Normal direction: start → end
            stationSequence = Array(line.stations[startIdx...endIdx])
        } else {
            // Reversed direction: end → start (user picked them backwards)
            stationSequence = Array(line.stations[endIdx...startIdx].reversed())
        }
        
        print("✅ Updated stationSequence: \(stationSequence.count) stations from \(stationName(startStationId)) to \(stationName(endStationId))")
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
                    stationPickerRow(title: "Partenza", selection: $startStationId)
                    
                    HStack {
                        Image(systemName: "arrow.down")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.leading, 12)
                        Spacer()
                    }
                    
                    stationPickerRow(title: "Arrivo", selection: $endStationId)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func stationSymbol(for stationId: String, size: CGFloat = 16) -> some View {
        if let station = network.nodes.first(where: { $0.id == stationId }) {
            // Interchange stations use double red circle
            if station.type == .interchange {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: size, height: size)
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: size * 0.6, height: size * 0.6)
                }
            } else {
                let color = station.customColor.flatMap { Color(hex: $0) } ?? .blue
                
                switch station.visualType ?? .filledCircle {
                case .filledCircle:
                    Circle()
                        .fill(color)
                        .frame(width: size, height: size)
                case .emptyCircle:
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: size, height: size)
                case .filledSquare:
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: size, height: size)
                case .emptySquare:
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(color, lineWidth: 2)
                        .frame(width: size, height: size)
                case .filledStar:
                    Image(systemName: "star.fill")
                        .foregroundColor(color)
                        .font(.system(size: size))
                }
            }
        } else {
            Circle()
                .fill(Color.gray)
                .frame(width: size, height: size)
        }
    }
    
    private func stationPickerRow(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            Picker(title, selection: selection) {
                ForEach(line.stations, id: \.self) { stationId in
                    HStack(spacing: 8) {
                        stationSymbol(for: stationId, size: 14)
                        Text(stationName(stationId))
                    }
                    .tag(stationId)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
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
    
    private var stopPatternSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SCHEMA FERMATE")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Quick pattern buttons
                Button(action: {
                    // Local (all stops)
                    skippedStopIds.removeAll()
                }) {
                    Text("Locale")
                        .font(.caption2.bold())
                        .foregroundColor(skippedStopIds.isEmpty ? .white : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(skippedStopIds.isEmpty ? Color.blue : Color.blue.opacity(0.2))
                        .cornerRadius(6)
                }
                
                Button(action: {
                    // Intercity (skip stations without square symbol, keep first and last)
                    skippedStopIds.removeAll()
                    if stationSequence.count > 2 {
                        for i in 1..<(stationSequence.count - 1) {
                            let stationId = stationSequence[i]
                            if let station = network.nodes.first(where: { $0.id == stationId }) {
                                // Skip if NOT a square station (keep only squares + first/last)
                                if station.visualType != .filledSquare && station.visualType != .emptySquare {
                                    skippedStopIds.insert(stationId)
                                }
                            }
                        }
                    }
                }) {
                    Text("Intercity")
                        .font(.caption2.bold())
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(6)
                }
                
                Button(action: {
                    // Express (skip intermediate stops, keep first and last)
                    skippedStopIds.removeAll()
                    if stationSequence.count > 2 {
                        for i in 1..<(stationSequence.count - 1) {
                            skippedStopIds.insert(stationSequence[i])
                        }
                    }
                }) {
                    Text("Diretto")
                        .font(.caption2.bold())
                        .foregroundColor(skippedStopIds.count == max(0, stationSequence.count - 2) ? .white : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(skippedStopIds.count == max(0, stationSequence.count - 2) ? Color.orange : Color.orange.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            if stationSequence.count >= 2 {
                VStack(spacing: 8) {
                    ForEach(Array(stationSequence.enumerated()), id: \.offset) { index, stationId in
                        let isFirst = index == 0
                        let isLast = index == stationSequence.count - 1
                        let isSkipped = skippedStopIds.contains(stationId)
                        
                        HStack(spacing: 12) {
                            // Stop indicator
                            ZStack {
                                Circle()
                                    .fill(isSkipped ? Color.gray.opacity(0.3) : Color.blue)
                                    .frame(width: 16, height: 16)
                                
                                if !isSkipped {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            
                            // Station name
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stationName(stationId))
                                    .font(.subheadline)
                                    .foregroundColor(isSkipped ? .secondary : .primary)
                                
                                if isFirst {
                                    Text("Partenza")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else if isLast {
                                    Text("Arrivo")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else if isSkipped {
                                    Text("Transito senza fermata")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                            
                            // Toggle skip (disabled for first and last station)
                            if !isFirst && !isLast {
                                Button(action: {
                                    if isSkipped {
                                        skippedStopIds.remove(stationId)
                                    } else {
                                        skippedStopIds.insert(stationId)
                                    }
                                }) {
                                    Image(systemName: isSkipped ? "circle" : "checkmark.circle.fill")
                                        .foregroundColor(isSkipped ? .gray : .green)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSkipped ? Color.gray.opacity(0.05) : Color.blue.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
            } else {
                Text("Aggiungi almeno 2 stazioni per configurare lo schema fermate")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }
    
    private var taktfahrplanSection: some View {
        let suggestions = calculateTaktSuggestions()
        let sequenceWithTakt = stationSequence.filter { sid in 
            network.nodes.first(where: { $0.id == sid })?.taktMinutes != nil 
        }
        
        return Group {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("TAKTFAHRPLAN (CADENZAMENTO SVIZZERO)")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if !sequenceWithTakt.isEmpty {
                    // Takt Station Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hub di Convergenza (Nodi Takt)")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        
                        Picker("Stazione Takt", selection: $taktStationId) {
                            Text("Nessun Hub specifico").tag("")
                            ForEach(sequenceWithTakt, id: \.self) { sid in
                                Text(stationName(sid)).tag(sid)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if !taktStationId.isEmpty, let suggestion = suggestions.first(where: { $0.stationId == taktStationId }) {
                        VStack(spacing: 8) {
                            HStack {
                                Text(suggestion.stationName)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("Minuto :\(String(format: "%02d", suggestion.taktMinute))")
                                    .font(.caption.bold())
                                    .foregroundColor(.orange)
                            }
                            
                            HStack(spacing: 12) {
                                // Arrivals window
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Finestra Arrivi")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(suggestion.suggestedArrival)
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                }
                                .padding(8)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(8)
                                
                                // Departures window
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Finestra Partenze")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(suggestion.suggestedDeparture)
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(10)
                    }
                } else {
                    Text("Nessuna stazione nel percorso ha un minuto Takt configurato.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Text("ℹ️ L'algoritmo cercherà di far convergere i treni tra -15/-5 minuti e ripartire tra +5/+15 minuti rispetto al minuto Takt.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
            .padding(.horizontal)
            .padding(.top, 8)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("PROGRAMMAZIONE E FINESTRA DI SERVIZIO")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                // Genetic Optimizer Toggle - NASCOSTO per Taktfahrplan
                if mode != .taktfahrplan {
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
                    .toggleStyle(.switch)
                    
                    Divider()
                }
                
                // Main Train Toggle
                Toggle(isOn: $isMainLine) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Linea Principale (Takt)")
                                .font(.subheadline.bold())
                            Text("I treni di questa linea hanno la priorità negli hub")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                
                Divider()
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Inizio Servizio").font(.subheadline)
                        Spacer()
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    if mode == .cadenced || mode == .taktfahrplan {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.red)
                            Text("Fine Servizio").font(.subheadline)
                            Spacer()
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(.green)
                            Text("Frequenza").font(.subheadline)
                            Spacer()
                            if mode == .taktfahrplan {
                                Picker("", selection: $intervalMinutes) {
                                    Text("60 min").tag(60)
                                    Text("120 min").tag(120)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                            } else {
                                Stepper("\(intervalMinutes)m", value: $intervalMinutes, in: 5...360, step: 5)
                                    .font(.subheadline.bold())
                            }
                        }
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    Toggle(isOn: $scheduleReturn) {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("Pianifica anche il ritorno").font(.subheadline.bold())
                        }
                    }
                    
                    HStack {
                        Text("Parità Numerazione").font(.caption).foregroundColor(.secondary)
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
                        TextField("", value: $startNumber, format: .number)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline.bold())
                            .frame(width: 80)
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
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
                frequency: Double(intervalMinutes), 
                existingTrains: manager.trains, 
                network: network
            )
            
            await MainActor.run {
                // Apply offset to unified startTime
                let base = normalizeDate(startTime)
                let cal = Calendar.current
                let baseStartOfDay = cal.startOfDay(for: base)
                startTime = baseStartOfDay.addingTimeInterval(offset * 60)
                self.localProposedOffset = offset
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
    
    /// Calculates Taktfahrplan suggestions for stations with configured takt times
    private func calculateTaktSuggestions() -> [(stationId: String, stationName: String, taktMinute: Int, suggestedArrival: String, suggestedDeparture: String)] {
        var suggestions: [(String, String, Int, String, String)] = []
        
        // Check all stations in the sequence for Taktfahrplan configuration
        for stationId in stationSequence {
            guard let station = network.nodes.first(where: { $0.id == stationId }),
                  let taktMinute = station.taktMinutes else {
                continue
            }
            
            // Calculate suggested time windows according to Swiss standard:
            // Takt center +/- 15, leaving 10 minutes gap around the center (+/- 5 from Takt)
            // Arrivals: [T - 15, T - 5]
            // Departures: [T + 5, T + 15]
            
            let arrS = (taktMinute - 15 + 60) % 60
            let arrE = (taktMinute - 5 + 60) % 60
            
            let depS = (taktMinute + 5) % 60
            let depE = (taktMinute + 15) % 60
            
            let arrivalWindow = String(format: ":%02d-:%02d", arrS, arrE)
            let departureWindow = String(format: ":%02d-:%02d", depS, depE)
            
            suggestions.append((stationId, station.name, taktMinute, arrivalWindow, departureWindow))
        }
        
        return suggestions
    }
    
    private func alignToTakt(isReturn: Bool) {
        let sequence = isReturn ? Array(stationSequence.reversed()) : stationSequence
        guard sequence.count >= 2 else { return }
        
        // Get stations with Takt info
        let taktStations = sequence.compactMap { sid -> (String, Int)? in
            if let node = network.nodes.first(where: { $0.id == sid }), let takt = node.taktMinutes {
                return (sid, takt)
            }
            return nil
        }
        
        guard let firstTakt = taktStations.first else { return }
        
        // Calculate estimated travel time from start to this Takt station
        var totalMinutes: Double = 0
        var prevId = sequence[0]
        
        // Dummy train for timing calculations
        let dummyTrain = Train(
            id: UUID(),
            number: 0,
            name: "Probe",
            type: selectedTrainType.rawValue,
            lineId: nil,
            departureTime: Date(),
            stops: [],
            vehicleId: nil,
            maxSpeed: Double(selectedTrainType.defaultMaxSpeed),
            acceleration: 0.5,
            deceleration: 0.5,
            mass: 200,
            power: 2500,
            priority: 5
        )
        
        for i in 0..<sequence.count {
            let sid = sequence[i]
            if sid == firstTakt.0 { break }
            
            if i > 0 {
                var legDist: Double = 0
                var legSpeed: Double = Double.infinity
                if let path = network.findPathEdges(from: prevId, to: sid) {
                    for edge in path {
                        legDist += edge.distance
                        legSpeed = min(legSpeed, Double(edge.maxSpeed))
                    }
                }
                
                if legDist > 0 {
                    let hours = FDCSchedulerEngine.calculateTravelTime(
                        distanceKm: legDist,
                        maxSpeedKmh: legSpeed == .infinity ? 100 : legSpeed,
                        train: dummyTrain,
                        initialSpeedKmh: 0,
                        finalSpeedKmh: 0
                    )
                    totalMinutes += (hours * 60) + (35.0 / 60.0) // Leg + Buffer
                }
                
                // Add dwell at previous station
                let prevNode = network.nodes.first(where: { $0.id == prevId })
                let dwell = (prevNode?.type == .interchange) ? 5 : 3
                totalMinutes += Double(dwell)
            }
            prevId = sid
        }
        
        // Target: (DepartureMinute + TravelTime) = TaktMinute
        // DepartureMinute = TaktMinute - TravelTime
        let targetMinute = (Double(firstTakt.1) - totalMinutes + 3600.0) // Ensure positive
        let alignedMinute = Int(targetMinute.rounded()) % 60
        
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: startTime)
        comps.minute = alignedMinute
        
        if let newDate = cal.date(from: comps) {
            startTime = newDate
            updatePreview()
        }
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
            total += calculateCount(s: start, e: end, interval: intervalMinutes)
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
        
        // AUTO-TAKTACTIVATION
        if useTaktAlignment {
            alignToTakt(isReturn: false)
        }
        
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

        let normalizedStart = normalizeDate(startTime)
        let normalizedRStartDraft = normalizedStart // Symmtrical start for draft

        // 1a. Probe Simulation
        // Use selected model (preferred) or vehicle physics if available, otherwise use default
        let physics: (acceleration: Double, deceleration: Double, mass: Double, power: Double, maxSpeed: Double)
        let effectiveVehicle: Vehicle?
        
        if let model = selectedModel {
            // Convert TrainModel to Vehicle
            let vehicleFromModel = model.toVehicle()
            effectiveVehicle = vehicleFromModel
            physics = (
                acceleration: vehicleFromModel.acceleration,
                deceleration: vehicleFromModel.deceleration,
                mass: vehicleFromModel.mass,
                power: vehicleFromModel.power,
                maxSpeed: vehicleFromModel.maxSpeed
            )
            print("   🚂 Usando modello: \(model.nome) (\(model.costruttore))")
            print("      Accelerazione: \(vehicleFromModel.acceleration) m/s²")
            print("      Decelerazione: \(vehicleFromModel.deceleration) m/s²")
            print("      Massa: \(vehicleFromModel.mass) t")
            print("      Potenza: \(vehicleFromModel.power) kW")
            print("      Velocità max: \(vehicleFromModel.maxSpeed) km/h")
        } else if let vehicle = selectedVehicle {
            effectiveVehicle = vehicle
            physics = (
                acceleration: vehicle.acceleration,
                deceleration: vehicle.deceleration,
                mass: vehicle.mass,
                power: vehicle.power,
                maxSpeed: vehicle.maxSpeed
            )
            print("   🚂 Usando mezzo: \(vehicle.name) (\(vehicle.model))")
            print("      Accelerazione: \(vehicle.acceleration) m/s²")
            print("      Decelerazione: \(vehicle.deceleration) m/s²")
            print("      Massa: \(vehicle.mass) t")
            print("      Potenza: \(vehicle.power) kW")
            print("      Velocità max: \(vehicle.maxSpeed) km/h")
        } else {
            effectiveVehicle = nil
            let defaultPhysics = appState.getPhysics(for: selectedTrainType)
            physics = (
                acceleration: defaultPhysics.acceleration,
                deceleration: defaultPhysics.deceleration,
                mass: 200, // Default mass
                power: 2500, // Default power
                maxSpeed: Double(selectedTrainType.defaultMaxSpeed)
            )
            print("   ⚙️ Usando valori di default per tipo: \(selectedTrainType.rawValue)")
        }
        
        // Find Return Line (or self)
        let rLineObj = manager.lines.first(where: { 
             $0.originId == line.destinationId && $0.destinationId == line.originId 
        }) ?? line
        
        let pOutNum = (line.numberPrefix ?? 0) * 100 + currentStart
        let probeOut = manager.instantiateTrain(
            number: pOutNum,
            name: "Probe Out",
            category: selectedTrainType,
            departureTime: normalizedStart,
            line: line,
            stationSequence: stationSequence,
            acceleration: physics.acceleration,
            deceleration: physics.deceleration,
            mass: physics.mass,
            power: physics.power,
            preferredTrack: "1",
            skippedStopIds: skippedStopIds
        )
        
            let pRetNum = (rLineObj.numberPrefix ?? line.numberPrefix ?? 0) * 100 + returnStartNumber
        let probeReturn = manager.instantiateTrain(
            number: pRetNum,
            name: "Probe Return",
            category: selectedTrainType,
            departureTime: normalizedRStartDraft,
            line: rLineObj,
            stationSequence: Array(stationSequence.reversed()),
            acceleration: physics.acceleration,
            deceleration: physics.deceleration,
            mass: physics.mass,
            power: physics.power,
            preferredTrack: "2",
            skippedStopIds: skippedStopIds
        )
        
        
        
        let normalizedEnd = normalizeDate(endTime)
        
        var generatedTrains: [Train] = []
        
        // SPECIAL HANDLING FOR TAKTFAHRPLAN 120-MINUTE CADENCE
        // Generate paired trains (T1 outward + T2 return) at the same departure time
        // so they meet at the Takt station
        if mode == .taktfahrplan && intervalMinutes == 120 && scheduleReturn {
            print("🎯 [TAKT-120] Generating paired trains (T1+T2) for Taktfahrplan 120-minute cadence")
            
            let iterations: Int
            if mode == .single { iterations = 1 }
            else {
                let sMin = calendar.component(.hour, from: normalizedStart) * 60 + calendar.component(.minute, from: normalizedStart)
                var eMin = calendar.component(.hour, from: normalizedEnd) * 60 + calendar.component(.minute, from: normalizedEnd)
                if eMin < sMin { eMin += 24 * 60 }
                iterations = (eMin - sMin) / intervalMinutes + 1
            }
            
            for i in 0..<iterations {
                let departureTime = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedStart) ?? normalizedStart
                
                // T1: Outward train (odd number)
                let t1Number = currentStart + (i * 2)
                let t1FinalNumber = (line.numberPrefix ?? 0) * 100 + t1Number
                
                let t1Train = manager.instantiateTrain(
                    number: t1FinalNumber,
                    category: selectedTrainType,
                    departureTime: departureTime,
                    line: line,
                    stationSequence: stationSequence,
                    acceleration: physics.acceleration,
                    deceleration: physics.deceleration,
                    mass: physics.mass,
                    power: physics.power,
                    preferredTrack: "1",
                    vehicleId: effectiveVehicle?.id,
                    skippedStopIds: skippedStopIds,
                    isMainTrain: isMainLine
                )
                generatedTrains.append(t1Train)
                print("   🚆 T1 (Outward): \(t1Train.name) #\(t1FinalNumber) @ \(formatTime(departureTime))")
                
                // T2: Return train (even number) - SAME departure time
                let t2Number = returnStartNumber + (i * 2)
                let t2FinalNumber = (rLineObj.numberPrefix ?? line.numberPrefix ?? 0) * 100 + t2Number
                
                let t2Train = manager.instantiateTrain(
                    number: t2FinalNumber,
                    category: selectedTrainType,
                    departureTime: departureTime, // ← SAME TIME AS T1
                    line: rLineObj,
                    stationSequence: Array(stationSequence.reversed()),
                    acceleration: physics.acceleration,
                    deceleration: physics.deceleration,
                    mass: physics.mass,
                    power: physics.power,
                    preferredTrack: "2",
                    vehicleId: effectiveVehicle?.id,
                    skippedStopIds: skippedStopIds,
                    isMainTrain: isMainLine
                )
                generatedTrains.append(t2Train)
                print("   🚆 T2 (Return):  \(t2Train.name) #\(t2FinalNumber) @ \(formatTime(departureTime)) [paired with T1]")
            }
            
            print("✅ [TAKT-120] Generated \(generatedTrains.count) trains in \(iterations) pairs")
        }
        // STANDARD GENERATION FOR OTHER MODES
        else {
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
                let finalNumber = (line.numberPrefix ?? 0) * 100 + outwardNumber
                
                let outwardTrain = manager.instantiateTrain(
                    number: finalNumber,
                    category: selectedTrainType,
                    departureTime: departureTime,
                    line: line,
                    stationSequence: stationSequence,
                    acceleration: physics.acceleration,
                    deceleration: physics.deceleration,
                    mass: physics.mass,
                    power: physics.power,
                    preferredTrack: "1",
                    vehicleId: effectiveVehicle?.id,
                    skippedStopIds: skippedStopIds,
                    isMainTrain: isMainLine
                )
                #if DEBUG
                print("🚂 [GEN] Created outward train \(outwardTrain.name) with \(outwardTrain.stops.count) stops, departure: \(departureTime)")
                #endif
                generatedTrains.append(outwardTrain)
            }
            
            // 3. GENERATE RETURN
            if scheduleReturn {
                let normalizedRStart = normalizeDate(startTime)
                let normalizedREnd = normalizeDate(endTime)
                
                let returnIterations: Int
                if mode == .single { returnIterations = 1 }
                else {
                    let sMin = calendar.component(.hour, from: normalizedRStart) * 60 + calendar.component(.minute, from: normalizedRStart)
                    var eMin = calendar.component(.hour, from: normalizedREnd) * 60 + calendar.component(.minute, from: normalizedREnd)
                    if eMin < sMin { eMin += 24 * 60 }
                    returnIterations = (eMin - sMin) / intervalMinutes + 1
                }
                
                for i in 0..<returnIterations {
                    let departureTime = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedRStart) ?? normalizedRStart
                    let returnNumber = returnStartNumber + (i * 2)
                    let finalNumber = (rLineObj.numberPrefix ?? line.numberPrefix ?? 0) * 100 + returnNumber
                    
                    let returnTrain = manager.instantiateTrain(
                        number: finalNumber,
                        category: selectedTrainType,
                        departureTime: departureTime,
                        line: rLineObj,
                        stationSequence: Array(stationSequence.reversed()),
                        acceleration: physics.acceleration,
                        deceleration: physics.deceleration,
                        mass: physics.mass,
                        power: physics.power,
                        preferredTrack: "2",
                        vehicleId: effectiveVehicle?.id,
                        skippedStopIds: skippedStopIds,
                        isMainTrain: isMainLine
                    )
                    generatedTrains.append(returnTrain)
                }
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
        
        // PIGNOLO UI FIX: Chiudi la tastiera e attendi un ciclo di runloop per evitare glitch RTIInputSystemClient
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s di pausa per stabilità UI
        
        // PIGNOLO PROTOCOL: Integration of new unified pipeline
        // PIGNOLO PROTOCOL: Capture thread-safe copies of nodes/edges while on MainActor
        let nodesCopy = network.nodes
        let edgesCopy = network.edges
        
        print("🔧 [GEN] Avvio pipeline con \(generatedTrains.count) treni, \(nodesCopy.count) nodi, \(edgesCopy.count) edges")
        
        // Usa il pipeline unificato con le opzioni selezionate
        // TAKTFAHRPLAN: disabilita tutti gli algoritmi di ottimizzazione per mantenere orari deterministici
        let optimizedTrains = await RailwayScheduleOptimizer.shared.executePipeline(
            newTrains: generatedTrains,
            existingTrains: manager.trains.filter { $0.lineId != line.id },
            nodes: nodesCopy,
            edges: edgesCopy,
            useAI: false,  // AI sempre disabilitata
            useGA: mode == .taktfahrplan ? false : useDepartureOptimizer, // TAKT: no ottimizzazione, usa solo orari calcolati
            geneticOptimizer: nil,
            preferredTaktNodeId: mode == .taktfahrplan && !taktStationId.isEmpty ? taktStationId : nil
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
                // Calculate gradient
                var legGradient: Double = 0
                if let fromNode = network.nodes.first(where: { $0.id == prevId }),
                   let toNode = network.nodes.first(where: { $0.id == currentId }),
                   let fromAlt = fromNode.altitude,
                   let toAlt = toNode.altitude {
                    let deltaAlt = toAlt - fromAlt
                    legGradient = (deltaAlt / (legDistance * 1000.0)) * 100.0
                }

                let hours = FDCSchedulerEngine.calculateTravelTime(
                    distanceKm: legDistance,
                    maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed,
                    train: dummyTrain,
                    initialSpeedKmh: 0,
                    finalSpeedKmh: 0,
                    gradient: legGradient
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
        .onChange(of: startStationId) { old, new in
            // Don't override station sequence during initialization
            guard !isInitializing else { return }
            
            if !new.isEmpty && !endStationId.isEmpty {
                // Build station sequence from line.stations between start and end
                updateStationSequenceFromSelection()
            }
        }
        .onChange(of: endStationId) { old, new in
            // Don't override station sequence during initialization
            guard !isInitializing else { return }
            
            if !new.isEmpty && !startStationId.isEmpty {
                // Build station sequence from line.stations between start and end
                updateStationSequenceFromSelection()
            }
        }
        .onChange(of: mode) { _ in updatePreview() }
        .onChange(of: startTime) { _ in updatePreview() }
        .onChange(of: endTime) { _ in updatePreview() }
        .onChange(of: intervalMinutes) { _ in updatePreview() }
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
        .onChange(of: preferredParity) { _, newValue in
            startNumber = (newValue == .odd) ? 1 : 2
            returnStartNumber = (newValue == .odd) ? 2 : 1
        }
        .onChange(of: startNumber) { _, newValue in
            // Keep return start logic
            returnStartNumber = (newValue % 2 == 0) ? 1 : 2
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
            
            stopPatternSection
            
            pathInfoRow
            
            if mode == .taktfahrplan {
                taktfahrplanSection
            }
            
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
        
        // Initial calculations for the default full-line path
        updatePathCalculations()
        updatePreview()
        
        // Debug: Check optimized times state
        print("🔍 [handleOnAppear] Checking optimized times state:")
        print("   optimizedTimesConfirmed: \(appState.optimizedTimesConfirmed)")
        print("   optimizedTimesPreviewData exists: \(appState.optimizedTimesPreviewData != nil)")
        
        // Check if there are confirmed optimized times to apply
        if appState.optimizedTimesConfirmed, let previewData = appState.optimizedTimesPreviewData {
            print("✅ [handleOnAppear] Found confirmed optimized times, applying and generating...")
            // Apply optimized times
            startTime = previewData.proposedOutboundTime
            if let interval = previewData.proposedInterval {
                intervalMinutes = interval
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
        
        // Initial setup complete
        
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
        
        // Check if line is electrified
        let isElectrified = checkLineElectrification()
        
        // Filter by train type capabilities and electrification
        var filtered = allVehicles.filter { vehicle in
            // Basic performance filter
            let performanceMatch: Bool = {
                switch selectedTrainType {
                case .highSpeed:
                    return vehicle.maxSpeed >= 200 // Expanded range for TAV
                case .direct:
                    return vehicle.maxSpeed >= 160 && vehicle.maxSpeed < 250
                case .regional:
                    return vehicle.maxSpeed >= 100 && vehicle.maxSpeed < 200
                case .freight:
                    return vehicle.maxSpeed < 120
                case .support:
                    return true
                }
            }()
            
            // Electrification filter: Cannot run electric train on non-electrified line
            if !isElectrified && vehicle.isElectric {
                return false
            }
            
            return performanceMatch
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
        
        // 1. Speed match (most important - 35% weight, reduced to make room for altitude)
        let speedDiff = abs(vehicle.maxSpeed - lineMaxSpeed)
        let speedScore = max(0, 100 - speedDiff)
        score += speedScore * 0.35
        
        // 2. Altitude profile analysis (15% weight) - NEW!
        let altitudeInfo = calculateAltitudeCharacteristics()
        if let totalElevationGain = altitudeInfo.totalElevationGain,
           let maxGradient = altitudeInfo.maxGradient {
            
            // Calculate altitude difficulty score
            var altitudeScore = 0.0
            
            // For steep gradients, prioritize high acceleration and power
            if maxGradient > 25 { // Very steep (> 2.5%)
                altitudeScore = min(vehicle.acceleration * 40, 100)
            } else if maxGradient > 15 { // Moderate (> 1.5%)
                altitudeScore = min(vehicle.acceleration * 30, 100)
            } else if maxGradient > 10 { // Gentle (> 1.0%)
                altitudeScore = min(vehicle.acceleration * 20, 100)
            } else {
                // Flat terrain - acceleration less critical
                altitudeScore = 50
            }
            
            // Bonus for total elevation gain handling
            let elevationPerKm = totalElevationGain / lineDistance
            if elevationPerKm > 10 { // Very hilly (> 10m/km)
                if vehicle.acceleration >= 1.5 {
                    altitudeScore += 20
                }
            } else if elevationPerKm > 5 { // Moderately hilly (> 5m/km)
                if vehicle.acceleration >= 1.2 {
                    altitudeScore += 10
                }
            }
            
            score += altitudeScore * 0.15
        }
        
        // 3. Number of stops and acceleration (25% weight, reduced from 30%)
        let numberOfStops = stationSequence.count
        let avgStopDistance = lineDistance / Double(max(numberOfStops - 1, 1))
        
        // For frequent stops (< 10km average), prioritize good acceleration
        if avgStopDistance < 10 {
            let accelerationScore = min(vehicle.acceleration * 30, 100) // Max 100 points
            score += accelerationScore * 0.25
        } else if avgStopDistance < 20 {
            // Medium stops - balanced acceleration/speed
            let accelerationScore = min(vehicle.acceleration * 20, 100)
            score += accelerationScore * 0.15
            // Add some speed bonus for longer distances
            score += min((vehicle.maxSpeed / lineMaxSpeed) * 50, 50) * 0.1
        } else {
            // Long distances - prioritize high speed and capacity
            let speedCapabilityScore = min((vehicle.maxSpeed / lineMaxSpeed) * 100, 100)
            score += speedCapabilityScore * 0.25
        }
        
        // 4. Line distance vs vehicle range/capacity (15% weight, reduced from 20%)
        // Prefer vehicles suitable for the total distance
        if lineDistance > 100 {
            // Long lines - prefer high-capacity, long-range vehicles
            if vehicle.maxSpeed >= 160 {
                score += 20 * 0.15
            }
        } else if lineDistance > 50 {
            // Medium lines - balanced vehicles
            if vehicle.maxSpeed >= 120 && vehicle.maxSpeed <= 200 {
                score += 20 * 0.15
            }
        } else {
            // Short lines - agile vehicles with good acceleration
            if vehicle.acceleration > 1.0 {
                score += 20 * 0.15
            }
        }
        
        // 5. Station infrastructure compatibility (10% weight)
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
        
        // 6. Prefer vehicles with photos (aesthetic bonus - 5% weight)
        if vehicle.imageName != nil {
            score += 5 * 0.05
        }
        
        // 7. Critical line parameters - Special recommendations (10% weight)
        var criticalBonus = 0.0
        
        // Check if line is electrified
        let isElectrified = checkLineElectrification()
        
        // Reuse altitude info already calculated above
        let criticalMaxGradient = altitudeInfo.maxGradient ?? 0
        
        // Rule 1: Infrastructure matching (Electrification)
        if !isElectrified {
            if !vehicle.isElectric {
                // Good match: diesel train on diesel line
                criticalBonus += 40
            } else {
                // Physical impossibility or extreme penalty
                criticalBonus -= 100
            }
        } else {
            // Electrified line
            if vehicle.isElectric {
                // Preferred match
                criticalBonus += 25
            } else {
                // Diesel on electrified line is possible but less efficient/sustainable
                criticalBonus += 10 
            }
        }
        
        // Rule 2: High passenger demand (> 800 estimated) → Double-decker (Rock family)
        let estimatedPassengers = Double(numberOfStops) * 100 // Rough estimate
        if estimatedPassengers > 800 {
            let isDoubleDecker = vehicle.name.lowercased().contains("rock") ||
                                 vehicle.name.lowercased().contains("double") ||
                                 vehicle.name.lowercased().contains("tav") ||
                                 vehicle.maxSpeed >= 200 // High-speed usually has high capacity
            if isDoubleDecker {
                criticalBonus += 25
            }
        }
        
        // Rule 3: Steep gradients (> 20‰) → High power vehicles (Rock family)
        if criticalMaxGradient > 20 {
            let isHighPower = vehicle.acceleration >= 1.5 ||
                             vehicle.name.lowercased().contains("rock") ||
                             vehicle.name.lowercased().contains("e.6") ||
                             vehicle.name.lowercased().contains("tav")
            if isHighPower {
                criticalBonus += 30
            }
        }
        
        // Rule 4: Frequent short stops (< 5 km average) → Agile vehicles (Jazz/Pop family)
        if avgStopDistance < 5 {
            let isAgile = vehicle.acceleration >= 1.2 ||
                         vehicle.name.lowercased().contains("jazz") ||
                         vehicle.name.lowercased().contains("pop") ||
                         vehicle.name.lowercased().contains("metro") ||
                         vehicle.name.lowercased().contains("suburban")
            if isAgile {
                criticalBonus += 25
            }
        }
        
        score += criticalBonus * 0.10
        
        // 8. Bonus for matching service type (5% weight, renumbered)
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
    
    private func checkLineElectrification() -> Bool {
        // TODO: Implement proper electrification checking when Edge model includes electrification field
        // For now, check track type as a proxy:
        // - High speed tracks are always electrified
        // - Single/Double tracks without electrification info are assumed electrified (conservative)
        
        let stations = stationSequence.compactMap { stationId in
            network.nodes.first(where: { $0.id == stationId })
        }
        
        guard stations.count >= 2 else {
            return true
        }
        
        let service = InfrastructureService(network: network)
        
        for i in 0..<(stations.count - 1) {
            let station1 = stations[i]
            let station2 = stations[i + 1]
            
            guard let pathResult = service.findPath(from: station1.id, to: station2.id) else {
                continue
            }
            
            // Check track types along the path
            for segment in pathResult.segments {
                let fromId = segment.from
                let toId = segment.to
                
                // Find edge in either direction
                let edge = network.edges.first(where: {
                    ($0.from == fromId && $0.to == toId) || ($0.from == toId && $0.to == fromId)
                })
                
                // If we find an edge and it's explicitly marked for diesel, consider non-electrified
                // Otherwise assume electrified (safer assumption)
                if let trackType = edge?.trackType {
                    // Currently all track types are assumed electrified
                    // In future, add specific check for diesel/non-electric tracks
                    continue
                }
            }
        }
        
        return true // Default: assume electrified (most common case)
    }
    
    private func calculateAltitudeCharacteristics() -> (totalElevationGain: Double?, maxGradient: Double?, avgGradient: Double?) {
        // Get stations in sequence
        let stations = stationSequence.compactMap { stationId in
            network.nodes.first(where: { $0.id == stationId })
        }
        
        guard stations.count >= 2 else {
            return (nil, nil, nil)
        }
        
        // Use InfrastructureService to get accurate path with all nodes (including junctions)
        let service = InfrastructureService(network: network)
        
        var totalElevationGain = 0.0
        var totalElevationLoss = 0.0
        var maxGradient = 0.0
        var totalDistance = 0.0
        
        // Calculate for each segment
        for i in 0..<(stations.count - 1) {
            let station1 = stations[i]
            let station2 = stations[i + 1]
            
            guard let pathResult = service.findPath(from: station1.id, to: station2.id) else {
                continue
            }
            
            // Analyze altitude changes along the path
            for j in 0..<(pathResult.nodes.count - 1) {
                let node1 = pathResult.nodes[j]
                let node2 = pathResult.nodes[j + 1]
                
                guard let alt1 = node1.altitude,
                      let alt2 = node2.altitude,
                      j < pathResult.segments.count else {
                    continue
                }
                
                let segmentDistance = pathResult.segments[j].distance
                let altitudeDiff = alt2 - alt1
                
                // Accumulate elevation gain/loss
                if altitudeDiff > 0 {
                    totalElevationGain += altitudeDiff
                } else {
                    totalElevationLoss += abs(altitudeDiff)
                }
                
                // Calculate gradient (in ‰ - per mille)
                if segmentDistance > 0 {
                    let gradient = abs(altitudeDiff / (segmentDistance * 1000)) * 1000 // Convert to ‰
                    maxGradient = max(maxGradient, gradient)
                }
                
                totalDistance += segmentDistance
            }
        }
        
        let avgGradient = totalDistance > 0 ? ((totalElevationGain + totalElevationLoss) / (totalDistance * 1000)) * 1000 : 0
        
        return (totalElevationGain, maxGradient, avgGradient)
    }
    
    private func calculateLineCharacteristics() -> LineCharacteristics {
        let totalDistance = estimatedDistance
        let numberOfStops = stationSequence.count
        let averageStopDistance = totalDistance / Double(max(numberOfStops - 1, 1))
        let maxLineSpeed = Double(selectedTrainType.defaultMaxSpeed)
        let frequency: Int?
        switch mode {
        case .single:
            frequency = nil
        case .cadenced, .taktfahrplan:
            frequency = intervalMinutes  // Taktfahrplan: 60 o 120 minuti
        }
        
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


