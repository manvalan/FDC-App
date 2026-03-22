import SwiftUI

struct RouteCreationView: View {
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var aiService: RailwayAIService
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
    @State private var mapPickingType: PickerType?
    
    @State private var errorMessage: String? = nil
    
    // AI Analysis
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var trainManager: LinesManager
    @State private var routeAnalysis: RailwayAIService.RouteAnalysis? = nil
    @State private var isAnalyzingLine: Bool = false
    
    // Local Cadence Optimization
    @StateObject private var cadenceOptimizer = CadenceOptimizer()
    @State private var proposedOffset: Double? = nil
    @State private var analysisTask: Task<Void, Never>? = nil
    
    @State private var showDetailsSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if !stationSequence.isEmpty {
                stationsScrollview
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
            
            // Error bar if any
            if let error = errorMessage {
                Text(error)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.8))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 20)
        .shadow(color: Color.gray.opacity(0.3), radius: 15, x: 0, y: 10)
        .onAppear {
            setupMapPicking()
        }
        .onDisappear {
            cleanupMapPicking()
        }
        .sheet(isPresented: $showDetailsSheet) {
            detailsForm
        }
    }
    
    private var headerView: some View {
        HStack {
            headerLabels
            Spacer()
            headerActions
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(blurredBackground)
    }
    
    private var headerLabels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stationSequence.isEmpty ? "Crea nuova linea" : "Configurazione percorso")
                .font(.system(.subheadline, design: .rounded).bold())
            
            if !stationSequence.isEmpty {
                Text("\(stationSequence.count) stazioni • \(String(format: "%.1f", totalDistance)) km")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text("Tocca le stazioni sulla mappa per tracciare")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var headerActions: some View {
        HStack(spacing: 8) {
            if !stationSequence.isEmpty {
                Button(action: finishSelection) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: {
                cancelSelection()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var totalDistance: Double {
        return network.calculatePathDistance(path: stationSequence)
    }
    
    private var stationsScrollview: some View {
        ScrollViewReader { proxy in
            stationsHorizontalList
                .frame(height: 60)
                .background(blurredBackground)
                .onChange(of: stationSequence.count) { count in
                    withAnimation {
                        if count > 0 { proxy.scrollTo(count - 1, anchor: .trailing) }
                    }
                }
        }
    }
    
    private var stationsHorizontalList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(stationSequence.indices), id: \.self) { index in
                    stationChip(at: index)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
    
    private func stationChip(at index: Int) -> some View {
        let stationId = stationSequence[index]
        return StationChip(
            stationId: stationId,
            index: index,
            isLast: index == stationSequence.count - 1,
            onRemove: { removeStation(at: index) }
        )
        .id(index)
    }
    
    private func removeStation(at index: Int) {
        withAnimation {
            if stationSequence.indices.contains(index) {
                stationSequence.remove(at: index)
                // Keep appState in sync
                appState.lineDraftStations = stationSequence
            }
        }
    }
    
    private var blurredBackground: some View {
        ZStack {
            Rectangle().fill(Material.ultraThinMaterial)
            Color.gray.opacity(0.05)
        }
    }
    
    private struct StationChip: View {
        let stationId: String
        let index: Int
        let isLast: Bool
        let onRemove: () -> Void
        @EnvironmentObject var appState: AppState // Access network via appState or directly passed

        var body: some View {
            HStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.caption2)
                    .padding(4)
                    .background(Circle().stroke(Color.secondary))
                
                Text(stationName)
                    .font(.caption)
                    .bold()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                if !isLast {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
            .padding(8)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 1)
        }
        
        private var stationName: String {
            appState.railroad.network.nodes.first { $0.id == stationId }?.name ?? stationId
        }
    }
    
    private func setupMapPicking() {
        appState.stationPickingCallback = { stationId in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring()) {
                if let lastId = appState.lineDraftStations.last {
                    let routeError = RouteCreationView.appendStation(
                        stationId, after: lastId,
                        network: self.network,
                        into: &self.appState.lineDraftStations
                    )
                    self.stationSequence = self.appState.lineDraftStations
                    self.errorMessage = routeError
                } else {
                    self.appState.lineDraftStations.append(stationId)
                    self.stationSequence = self.appState.lineDraftStations
                }
            }
        }
    }

    /// Appends `stationId` to `draft` using direct connection or shortest-path fallback.
    /// Returns an error message if no path exists, nil on success (or same-station no-op).
    private static func appendStation(
        _ stationId: String,
        after lastId: String,
        network: NetworkModel,
        into draft: inout [String]
    ) -> String? {
        guard lastId != stationId else { return nil }
        let neighbors = network.getConnectedNodeIds(for: lastId)
        if neighbors.contains(stationId) {
            draft.append(stationId)
            return nil
        }
        guard let (path, _) = network.findShortestPath(from: lastId, to: stationId) else {
            return "Nessuna connessione trovata tra le stazioni"
        }
        for nodeId in path.dropFirst() where !draft.contains(nodeId) || nodeId == stationId {
            draft.append(nodeId)
        }
        return nil
    }
    
    private func cleanupMapPicking() {
        appState.stationPickingCallback = nil
    }
    
    private func finishSelection() {
        // Show details form
        showDetailsSheet = true
    }
    
    private func cancelSelection() {
        cleanupMapPicking()
        appState.lineDraftStations.removeAll()
        stationSequence.removeAll()
    }
    
    private var detailsForm: some View {
        NavigationStack {
            Form {
                detailsSection
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Dettagli Linea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Indietro") {
                        showDetailsSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveAndFinish()
                    }
                    .disabled(lineName.isEmpty || stationSequence.count < 2)
                }
            }
        }
    }
    
    private var detailsSection: some View {
        Section(header: Text("line_details".localized)) {
            TextField("line_name_example".localized, text: $lineName)
            
            if appState.currentMode != .design {
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
            }
            
            ColorPicker("line_color".localized, selection: $lineColor)
        }
    }
    
    private func findIdealOffset() {
        Task {
            // Find best offset against current traffic manager trains
            // For now, use appState.trainManager.trains as reference
            let route = TrainRoute(
                id: "temp",
                name: lineName,
                stationIds: stationSequence
            )
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: route, 
                frequency: cadenceFrequency, 
                existingTrains: trainManager.trains, 
                network: network
            )
            self.proposedOffset = offset
        }
    }
    private func saveAndFinish() {
        let hexColor = lineColor.toHex()
        
        let newRoute = TrainRoute(
            id: UUID().uuidString,
            name: lineName,
            color: hexColor,
            originStationId: stationSequence.first ?? "",
            destinationStationId: stationSequence.last ?? "",
            stationIds: stationSequence,
            serviceCodePrefix: codePrefix.isEmpty ? nil : codePrefix,
            numberPrefix: numberPrefix == 0 ? nil : numberPrefix
        )
        trainManager.routes.append(newRoute)
        
        // Se c'è una cadenza, propone di creare i treni (opzionale, semplificato qui)
        
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
                routeAnalysis = try await aiService.analyzeRoute(
                    name: lineName.isEmpty ? "New Route" : lineName,
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
                    
                    suggestionsHorizontalList(suggestions)
                }
                .padding(.vertical, 12)
                .background(blurredBackground)
                .overlay(topDivider, alignment: .top)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func suggestionsHorizontalList(_ suggestions: [Node]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions) { node in
                    suggestionButton(for: node)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func suggestionButton(for node: Node) -> some View {
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
            .shadow(color: Color.black.opacity(0.1), radius: 3)
        }
        .buttonStyle(.plain)
    }
    
    private var topDivider: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Color.gray.opacity(0.2))
    }
}

