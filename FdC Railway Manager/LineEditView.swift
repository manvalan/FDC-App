import SwiftUI

struct LineEditView: View {
    @EnvironmentObject var appState: AppState
    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }
    
    @Environment(\.dismiss) var dismiss
    
    let lineId: String
    
    @State private var lineName: String = ""
    @State private var codePrefix: String = ""
    @State private var numberPrefix: Int = 0
    @State private var cadenceFrequency: Double = 60.0
    @State private var lineColor: Color = .blue
    @State private var terminalTracks: [String: String] = [:]
    
    // Path selection state
    @State private var startStationId: String = ""
    @State private var viaStationIds: [String] = []
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = true // Default to true for editing
    
    @State private var manualStationId: String = ""
    @State private var activePicker: PickerType?
    @State private var mapPickingType: PickerType?
    
    @State private var errorMessage: String? = nil
    
    // AI Analysis
    @State private var lineAnalysis: RailwayAIService.LineAnalysis? = nil
    @State private var isAnalyzingLine: Bool = false
    
    // Local Cadence Optimization
    @StateObject private var cadenceOptimizer = CadenceOptimizer()
    @State private var proposedOffset: Double? = nil
    
    var body: some View {
        Form {
            detailsSection
                
                Section(header: Text("path_composition".localized)) {
                    PathPickerComponent(
                        startStationId: $startStationId,
                        viaStationIds: $viaStationIds,
                        endStationId: $endStationId,
                        stationSequence: $stationSequence,
                        manualAddition: $manualAddition,
                        activePicker: $activePicker,
                        manualStationId: $manualStationId,
                        lineAnalysis: lineAnalysis,
                        isAnalyzing: isAnalyzingLine
                    )
                }
                
                if !stationSequence.isEmpty || manualAddition {
                    StationSequenceSection(
                        stationSequence: $stationSequence,
                        lineColor: lineColor,
                        network: network,
                        activePicker: $activePicker,
                        mapPickingType: $mapPickingType,
                        suggestions: getSuggestions()
                    )
                }
                
                Section(header: Text("materiale_rotabile".localized)) {
                    Button(action: {
                        lines.autoAssignRollingStock(for: lineId)
                    }) {
                        Label("Ottimizza Assegnazione Mezzi", systemImage: "sparkles.rectangle.stack")
                    }
                    
                    Text("Assegna i turni macchina minimizzando il materiale rotabile e bilanciando il numero di corse (preferendo turni pari).")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    let assignedVehicleIds = Set(lines.trains.filter { $0.lineId == lineId }.compactMap { $0.vehicleId })
                    let assignedVehicles = lines.vehicles.filter { assignedVehicleIds.contains($0.id) }
                    
                    if !assignedVehicles.isEmpty {
                        Divider().padding(.vertical, 4)
                        Text("Mezzi Attualmente Assegnati:").font(.caption.bold())
                        
                        ForEach(assignedVehicles) { vehicle in
                            let count = lines.trains.filter { $0.lineId == lineId && $0.vehicleId == vehicle.id }.count
                            HStack {
                                Image(systemName: "train.side.front.car")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading) {
                                    Text(vehicle.name).font(.subheadline)
                                    Text(vehicle.model).font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(count) corse")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(count % 2 == 0 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                    .foregroundColor(count % 2 == 0 ? .green : .orange)
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !stationSequence.isEmpty {
                    suggestionsOverlay
                }
            }
            .navigationTitle("edit_line".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveChanges()
                    }
                    .disabled(lineName.isEmpty || stationSequence.count < 2)
                }
            }
            .onAppear {
                loadLineData()
            }
            .onChange(of: startStationId) { old, new in
                if !new.isEmpty {
                    if stationSequence.isEmpty {
                        stationSequence = [new]
                    } else if stationSequence[0] != new {
                        stationSequence[0] = new
                    }
                }
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    stationSequence.append(new)
                    manualStationId = "" 
                }
            }
            .onChange(of: stationSequence) { _, newSeq in
                if appState.useCloudAI && newSeq.count >= 2 {
                    triggerLineAnalysis()
                }
            }
            .onChange(of: activePicker) { old, new in
                if let type = new {
                    setupPickingCallback(for: type)
                } else if mapPickingType == nil {
                    appState.stationPickingCallback = nil
                }
            }
            .onChange(of: mapPickingType) { old, new in
                if let type = new {
                    setupPickingCallback(for: type)
                } else if activePicker == nil {
                    appState.stationPickingCallback = nil
                }
            }
            .onDisappear {
                appState.stationPickingCallback = nil
            }
            .sheet(item: $activePicker) { item in
                Group {
                    switch item {
                    case .start:
                        StationPickerView(selectedStationId: $startStationId)
                    case .via(let idx):
                        if idx >= 0 && idx < viaStationIds.count {
                            StationPickerView(selectedStationId: Binding(
                                get: { viaStationIds[idx] },
                                set: { viaStationIds[idx] = $0 }
                            ))
                        } else {
                            VStack {
                                Text(String(format: "error_index_not_found_fmt".localized, idx))
                                Button("close".localized) { activePicker = nil }
                            }
                            .padding()
                        }
                    case .end:
                        StationPickerView(selectedStationId: $endStationId)
                    case .manual:
                        StationPickerView(selectedStationId: $manualStationId, linkedToStationId: stationSequence.last)
                    }
                }
                .environmentObject(network)
            }
    }
    
    private var detailsSection: some View {
        Section(header: Text("line_details".localized)) {
            TextField("line_name_placeholder".localized, text: $lineName)
            TextField("code_prefix_placeholder".localized, text: $codePrefix)
            TextField("number_prefix_placeholder".localized, value: $numberPrefix, format: .number)
                .keyboardType(.numberPad)
            
            VStack(alignment: .leading) {
                HStack {
                    Text("cadence_frequency".localized)
                    Spacer()
                    TextField("minutes", value: $cadenceFrequency, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                
                HStack {
                    Button(action: { findIdealOffset() }) {
                        Label(cadenceOptimizer.isRunning ? "finding_slot".localized : "propose_ideal_slot".localized, 
                              systemImage: "wand.and.stars")
                    }
                    .disabled(cadenceOptimizer.isRunning || stationSequence.count < 2)
                    
                    if let offset = proposedOffset {
                        Spacer()
                        Text(String(format: "suggested_offset_fmt".localized, Int(offset)))
                            .foregroundColor(.green)
                            .font(.caption.bold())
                    }
                }
            }
            ColorPicker("line_color".localized, selection: $lineColor)
                
            Section(header: Text("capolinea_e_binari".localized)) {
                if let startNode = network.nodes.first(where: { $0.id == stationSequence.first }) {
                    HStack {
                        Text("Origine: \(startNode.name)")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { terminalTracks[startNode.id] ?? "" },
                            set: { terminalTracks[startNode.id] = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("-").tag("")
                            ForEach(1...(startNode.platforms ?? 2), id: \.self) { p in
                                Text("\(p)").tag("\(p)")
                            }
                        }
                    }
                }
                
                if let endNode = network.nodes.first(where: { $0.id == stationSequence.last }), endNode.id != stationSequence.first {
                    HStack {
                        Text("Destinazione: \(endNode.name)")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { terminalTracks[endNode.id] ?? "" },
                            set: { terminalTracks[endNode.id] = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("-").tag("")
                            ForEach(1...(endNode.platforms ?? 2), id: \.self) { p in
                                Text("\(p)").tag("\(p)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func findIdealOffset() {
        Task {
            let line = RailwayLine(
                id: lineId,
                name: lineName,
                stops: stationSequence.map { RelationStop(stationId: $0) }
            )
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: line, 
                frequency: cadenceFrequency, 
                existingTrains: lines.trains.filter { $0.lineId != lineId }, 
                network: network
            )
            self.proposedOffset = offset
        }
    }
    
    
    private func loadLineData() {
        guard let line = lines.lines.first(where: { $0.id == lineId }) else {
            dismiss()
            return
        }
        
        lineName = line.name
        codePrefix = line.codePrefix ?? ""
        numberPrefix = line.numberPrefix ?? 0
        cadenceFrequency = line.cadenceFrequency ?? 60.0
        lineColor = Color(hex: line.color ?? "") ?? .blue
        terminalTracks = line.terminalTracks
        
        startStationId = line.originId
        endStationId = line.destinationId
        stationSequence = line.stops.map { $0.stationId }
        // viaStationIds is trickier since it's used for pathfinding, 
        // but for manual sequence editing we mainly care about stationSequence.
        
        if appState.useCloudAI && stationSequence.count >= 2 {
            triggerLineAnalysis()
        }
    }
    
    private func saveChanges() {
        guard let index = lines.lines.firstIndex(where: { $0.id == lineId }) else { return }
        
        let hexColor = lineColor.toHex()
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        
        // Update the existing line through a checkpoint
        // Update the existing line through a checkpoint
        // lines.createCheckpoint() // TODO: Implement undo for LinesManager
        lines.lines[index].name = lineName
        lines.lines[index].color = hexColor
        lines.lines[index].originId = stationSequence.first ?? startStationId
        lines.lines[index].destinationId = stationSequence.last ?? endStationId
        lines.lines[index].stops = stops
        lines.lines[index].codePrefix = codePrefix.isEmpty ? nil : codePrefix
        lines.lines[index].numberPrefix = numberPrefix == 0 ? nil : numberPrefix
        lines.lines[index].cadenceFrequency = cadenceFrequency
        lines.lines[index].terminalTracks = terminalTracks
        
        // Update all trains of this line to use these tracks at terminal stations
        for tIdx in lines.trains.indices {
            if lines.trains[tIdx].lineId == lineId {
                // Update start stop
                if let firstId = stationSequence.first, let track = terminalTracks[firstId] {
                    if let sIdx = lines.trains[tIdx].stops.firstIndex(where: { $0.stationId == firstId }) {
                        lines.trains[tIdx].stops[sIdx].track = track
                        lines.trains[tIdx].stops[sIdx].isManualTrack = true
                    }
                }
                // Update end stop
                if let lastId = stationSequence.last, let track = terminalTracks[lastId] {
                    if let sIdx = lines.trains[tIdx].stops.firstIndex(where: { $0.stationId == lastId }) {
                        lines.trains[tIdx].stops[sIdx].track = track
                        lines.trains[tIdx].stops[sIdx].isManualTrack = true
                    }
                }
            }
        }
        
        lines.validateSchedules()
        dismiss()
    }
    
    private func getSuggestions() -> [Node] {
        guard let lastId = stationSequence.last else { return [] }
        let connectedIds = network.getNeighborStations(for: lastId)
        return network.nodes.filter { node in
            connectedIds.contains(node.id) &&
            (node.type == .station || node.type == .interchange) &&
            node.id != lastId
        }
        .sorted { $0.name < $1.name }
    }
    
    private func triggerLineAnalysis() {
        Task {
            isAnalyzingLine = true
            do {
                lineAnalysis = try await RailwayAIService.shared.analyzeLine(
                    name: lineName.isEmpty ? "Line" : lineName,
                    stationIds: stationSequence,
                    nodes: network.nodes,
                    edges: network.edges
                )
            } catch {
                print("❌ AI Line Analysis failed: \(error)")
            }
            isAnalyzingLine = false
        }
    }
    
    private var suggestionsOverlay: some View {
        let suggestions = getSuggestions()
        return Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consigliate (Tocca per aggiungere):")
                        .font(.caption2.bold())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(suggestions) { node in
                                Button(action: {
                                    withAnimation(.spring()) {
                                        stationSequence.append(node.id)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                        Text(node.name)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.1), radius: 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.2)), alignment: .top)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func setupPickingCallback(for type: PickerType) {
        appState.stationPickingCallback = { stationId in
            switch type {
            case .start:
                self.startStationId = stationId
            case .via(let idx):
                if idx < viaStationIds.count {
                    viaStationIds[idx] = stationId
                }
            case .end:
                self.endStationId = stationId
            case .manual:
                self.manualStationId = stationId
            }
            
            // Auto-close terminals/via, keep manual sequence open
            if case .manual = type {
                // Keep it open for series of clicks
            } else {
                activePicker = nil
                mapPickingType = nil
            }
        }
    }
}
