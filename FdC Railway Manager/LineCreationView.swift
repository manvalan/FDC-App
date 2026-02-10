import SwiftUI

struct LineCreationView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    @State private var lineName: String = ""
    @State private var codePrefix: String = "" // New
    @State private var numberPrefix: Int = 0 // New
    @State private var cadenceFrequency: Double = 60.0 // Default 60 min
    @State private var lineColor: Color = .blue
    
    // Controlled by PathPickerComponent
    @State private var startStationId: String = ""
    @State private var viaStationIds: [String] = []
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = false
    
    @State private var manualStationId: String = ""
    @State private var activePicker: PickerType?
    
    @State private var errorMessage: String? = nil
    
    // AI Analysis
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var trainManager: TrainManager
    @State private var lineAnalysis: RailwayAIService.LineAnalysis? = nil
    @State private var isAnalyzingLine: Bool = false
    
    // Local Cadence Optimization
    @StateObject private var cadenceOptimizer = CadenceOptimizer()
    @State private var proposedOffset: Double? = nil
    @State private var analysisTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
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
                
                if !stationSequence.isEmpty {
                    StationSequenceSection(
                        stationSequence: $stationSequence,
                        lineColor: lineColor,
                        network: network,
                        activePicker: $activePicker,
                        suggestions: getSuggestions()
                    )
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
            .navigationTitle("new_line".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveLine()
                    }
                    .disabled(lineName.isEmpty || stationSequence.count < 2)
                }
            }
            .onChange(of: startStationId) { old, new in
                if !new.isEmpty {
                    if manualAddition {
                        if stationSequence.isEmpty {
                            stationSequence = [new]
                        } else {
                            // Sincronizziamo il primo elemento se stiamo cambiando l'origine
                            stationSequence[0] = new
                        }
                    } else if stationSequence.isEmpty {
                        // In auto mode, inizializziamo la sequenza se vuota
                        stationSequence = [new]
                    }
                }
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    // PIGNOLO: Permettiamo loop o ritorni (rimosso check .contains)
                    stationSequence.append(new)
                    manualStationId = "" 
                }
            }
        }
        .onChange(of: stationSequence) { _, newSeq in
            if appState.useCloudAI && newSeq.count >= 2 {
                triggerLineAnalysis()
            }
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
            TextField("line_name_example".localized, text: $lineName)
            TextField("code_prefix_placeholder".localized, text: $codePrefix)
            TextField("number_prefix_example".localized, value: $numberPrefix, format: .number)
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
        }
    }
    
    private func findIdealOffset() {
        Task {
            // Find best offset against current traffic manager trains
            // For now, use appState.trainManager.trains as reference
            let line = RailwayLine(
                id: "temp",
                name: lineName,
                stops: stationSequence.map { RelationStop(stationId: $0) }
            )
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: line, 
                frequency: cadenceFrequency, 
                existingTrains: trainManager.trains, 
                network: network
            )
            self.proposedOffset = offset
        }
    }
    
    private func saveLine() {
        let hexColor = lineColor.toHex()
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        let newLine = RailwayLine(
            id: UUID().uuidString,
            name: lineName,
            color: hexColor,
            originId: stationSequence.first ?? startStationId,
            destinationId: stationSequence.last ?? endStationId,
            stops: stops,
            codePrefix: codePrefix.isEmpty ? nil : codePrefix,
            numberPrefix: numberPrefix == 0 ? nil : numberPrefix,
            cadenceFrequency: cadenceFrequency
        )
        trainManager.lines.append(newLine)
        dismiss()
    }
    
    private func getSuggestions() -> [Node] {
        guard let lastId = stationSequence.last else { return [] }
        let connectedIds = network.getNeighborStations(for: lastId)
        
        return network.nodes.filter { node in
            // 1. Deve essere connessa
            connectedIds.contains(node.id) &&
            // 2. Deve essere una stazione passeggeri (no bivi/depositi nei suggerimenti linea)
            (node.type == .station || node.type == .interchange) &&
            // 3. Non deve essere l'ultima appena aggiunta (evitiamo micro-loop immediati)
            node.id != lastId
        }
        .sorted { $0.name < $1.name }
    }
    
    private func triggerLineAnalysis() {
        analysisTask?.cancel()
        analysisTask = Task {
            // Debounce delay
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            
            isAnalyzingLine = true
            do {
                lineAnalysis = try await RailwayAIService.shared.analyzeLine(
                    name: lineName.isEmpty ? "New Line" : lineName,
                    stationIds: stationSequence,
                    nodes: network.nodes,
                    edges: network.edges
                )
            } catch {
                if !(error is CancellationError) {
                    print("❌ AI Line Analysis failed: \(error)")
                }
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
}
