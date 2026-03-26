import SwiftUI

enum PickerType: Identifiable, Hashable {
    case start, via(Int), end, manual
    var id: String {
        switch self {
        case .start: return "start"
        case .via(let idx): return "via-\(idx)"
        case .end: return "end"
        case .manual: return "manual"
        }
    }
}

struct PathPickerComponent: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var trainManager: TrainManager
    
    @Binding var startStationId: String
    @Binding var viaStationIds: [String]
    @Binding var endStationId: String
    @Binding var stationSequence: [String]
    @Binding var manualAddition: Bool
    
    // Identifiable wrapper to avoid Index Out of Range crashes in ForEach/Sheet
    struct ViaItem: Identifiable {
        let id: Int
        var stationId: String
    }
    
    private var viaItems: [ViaItem] {
        viaStationIds.enumerated().map { (index, stationId) in ViaItem(id: index, stationId: stationId) }
    }
    
    @State private var alternatives: [(path: [String], distance: Double, description: String)] = []
    @State private var selectedAlternativeIndex: Int? = nil
    @State private var errorMessage: String? = nil
    @State var useAutomaticSelection = true
    
    @Binding var activePicker: PickerType?
    @Binding var manualStationId: String
    var lineContext: TrainRoute? = nil
    
    // AI Analysis
    var lineAnalysis: RailwayAIService.RouteAnalysis? = nil
    var isAnalyzing: Bool = false
    
    @State private var isCalculating = false
    
    // Local GA Search
    @StateObject private var cadenceOptimizer = CadenceOptimizer()
    @State private var localProposedOffset: Double? = nil

    var body: some View {
        Group {
            Section(header: Text("path_mode".localized)) {
                Picker("method".localized, selection: $useAutomaticSelection) {
                    Text("auto_calculation".localized).tag(true)
                    Text("manual_composition".localized).tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: useAutomaticSelection) { old, new in
                    manualAddition = !new
                }
            }
            .task {
                // PIGNOLO PROTOCOL: Auto-calculate path on load if terminals are set
                if !startStationId.isEmpty && !endStationId.isEmpty && alternatives.isEmpty {
                    calculatePath()
                }
            }
            .onChange(of: startStationId) { _, _ in if useAutomaticSelection { calculatePath() } }
            .onChange(of: endStationId) { _, _ in if useAutomaticSelection { calculatePath() } }
            .onChange(of: viaStationIds) { _, _ in if useAutomaticSelection { calculatePath() } }
            
            if useAutomaticSelection {
                Section(header: Text("define_terminals".localized)) {
                    HStack {
                        Text("from".localized)
                        Spacer()
                        Group {
                            Button(action: { activePicker = .start }) {
                                Text(stationName(startStationId))
                                    .foregroundColor(startStationId.isEmpty ? .secondary : .primary)
                            }
                            Button(action: { 
                                // Direct map pick without sheet
                                appState.stationPickingCallback = { id in
                                    startStationId = id
                                    appState.stationPickingCallback = nil
                                }
                            }) {
                                Image(systemName: "hand.tap")
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if lineContext == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("via_passage".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(viaItems) { item in
                                HStack {
                                    Button(action: { activePicker = .via(item.id) }) {
                                        HStack {
                                            Image(systemName: "mappin.circle")
                                            Text(stationName(item.stationId))
                                        }
                                        .foregroundColor(item.stationId.isEmpty ? .secondary : .primary)
                                    }
                                    
                                    Button(action: {
                                        appState.stationPickingCallback = { id in
                                            if item.id < viaStationIds.count {
                                                viaStationIds[item.id] = id
                                            }
                                            appState.stationPickingCallback = nil
                                        }
                                    }) {
                                        Image(systemName: "hand.tap")
                                            .foregroundColor(.orange)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    Button(role: .destructive, action: { 
                                        if item.id < viaStationIds.count {
                                            viaStationIds.remove(at: item.id) 
                                        }
                                    }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                            
                            HStack {
                                Button(action: { 
                                    viaStationIds.append("")
                                    activePicker = .via(viaStationIds.count - 1)
                                }) {
                                    Label("add_via_point".localized, systemImage: "plus.circle")
                                        .font(.subheadline)
                                }
                                Spacer()
                                Button(action: {
                                    viaStationIds.append("")
                                    appState.stationPickingCallback = { id in
                                        if let lastIdx = viaStationIds.indices.last {
                                            viaStationIds[lastIdx] = id
                                        }
                                        appState.stationPickingCallback = nil
                                    }
                                }) {
                                    Label("da mappa", systemImage: "hand.tap")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    HStack {
                        Text("to".localized)
                        Spacer()
                        Group {
                            Button(action: { activePicker = .end }) {
                                Text(stationName(endStationId))
                                    .foregroundColor(endStationId.isEmpty ? .secondary : .primary)
                            }
                            Button(action: {
                                appState.stationPickingCallback = { id in
                                    endStationId = id
                                    appState.stationPickingCallback = nil
                                }
                            }) {
                                Image(systemName: "hand.tap")
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if !startStationId.isEmpty && !endStationId.isEmpty {
                        Button(action: invertPath) {
                            Label("invert_path_desc".localized, systemImage: "arrow.up.arrow.down")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 4)
                    }
                    
                    if isCalculating {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("calculating_path_desc".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } 
                    
                    // Display AI Analysis if enabled and available (for both new and existing lines)
                    if isAnalyzing {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("ai_analyzing".localized).font(.caption).foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    } else if let analysis = lineAnalysis {
                        aiAnalysisView(analysis: analysis)
                        localAnalysisView
                    } else if !stationSequence.isEmpty {
                        // Show local analysis even if AI is not available
                        localAnalysisView
                    }
                    
                    if lineContext == nil {
                        Button("calculate_proposed_paths".localized) {
                            calculatePath()
                        }
                        .disabled(startStationId.isEmpty || endStationId.isEmpty || (startStationId == endStationId && viaStationIds.filter({!$0.isEmpty}).isEmpty))
                    }
                    
                    if !alternatives.isEmpty {
                        if alternatives.count > 1 {
                            Picker("proposed_path".localized, selection: $selectedAlternativeIndex) {
                                Text("select_dots".localized).tag(Int?.none)
                                ForEach(alternatives.indices, id: \.self) { index in
                                    let alt = alternatives[index]
                                    let dist = (alt.distance > 500) ? (alt.distance / 1000.0) : alt.distance
                                    Text(String(format: "path_alt_fmt".localized, alt.description, alt.path.count, dist))
                                        .tag(Int?.some(index))
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            // Only one alternative, show info
                            let alt = alternatives[0]
                            let dist = (alt.distance > 500) ? (alt.distance / 1000.0) : alt.distance
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text(String(format: "path_found_fmt".localized, alt.description))
                                Spacer()
                                Text(String(format: "%.1f km", dist))
                                    .font(.caption).bold()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if let selectedIdx = selectedAlternativeIndex, selectedIdx < alternatives.count {
                        let alt = alternatives[selectedIdx]
                        let dist = (alt.distance > 500) ? (alt.distance / 1000.0) : alt.distance
                        HStack {
                            Text("total_distance".localized)
                            Spacer()
                            Text(String(format: "%.1f km", dist))
                                .bold()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    if !stationSequence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("calculated_itinerary".localized).font(.caption).foregroundColor(.secondary)
                            Text(stationSequence.map { stationName($0) }.joined(separator: " → "))
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                Section(header: Text("path_composition".localized)) {
                    if lineContext == nil {
                        HStack {
                            Text("from".localized)
                            Spacer()
                            Button(action: { activePicker = .start }) {
                                Text(stationName(startStationId))
                                    .foregroundColor(startStationId.isEmpty ? .secondary : .primary)
                            }
                        }
                    }
                    
                    Text("manual_composition_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
        }
    }
    
    private func stationName(_ id: String) -> String {
        if id.isEmpty { return "select_dots".localized }
        return network.nodes.first(where: { $0.id == id })?.name ?? "unknown_station".localized
    }
    
    private func calculatePath() {
        isCalculating = true
        errorMessage = nil
        stationSequence = []
        alternatives = []
        selectedAlternativeIndex = nil
        
        let nodesSnapshot = network.nodes
        let edgesSnapshot = network.edges
        let start = startStationId
        let end = endStationId
        let vias = viaStationIds
        let ctx = lineContext
        let language = LocalizationManager.shared.currentLanguage
        
        // Use detached task to ensure it runs on a background thread
        // and doesn't inherit the parent's (MainActor) context
        Task.detached(priority: .userInitiated) {
            let result = await PathPickerComponent.calculatePathBackground(
                nodes: nodesSnapshot,
                edges: edgesSnapshot,
                startStationId: start,
                endStationId: end,
                viaStationIds: vias,
                lineContext: ctx,
                language: language
            )
            
            await MainActor.run {
                self.isCalculating = false
                if let error = result.error {
                    self.errorMessage = error
                } else {
                    self.alternatives = result.alternatives
                    self.selectedAlternativeIndex = result.alternatives.isEmpty ? nil : 0
                    if let first = result.alternatives.first {
                        self.stationSequence = first.path
                    }
                }
            }
        }
    }
    
    // Non-isolated static helper ensures this runs completely off the MainActor
    nonisolated static func calculatePathBackground(
        nodes: [Node],
        edges: [Edge],
        startStationId: String,
        endStationId: String,
        viaStationIds: [String],
        lineContext: TrainRoute?,
        language: AppLanguage
    ) async -> (alternatives: [(path: [String], distance: Double, description: String)], error: String?) {
        
        func localize(_ key: String) -> String {
            LocalizationManager.string(for: key, language: language)
        }
        
        guard !startStationId.isEmpty, !endStationId.isEmpty else { return ([], nil) }
        
        func stationName(_ id: String) -> String {
            if id.isEmpty { return localize("select_dots") }
            return nodes.first(where: { $0.id == id })?.name ?? localize("unknown_station")
        }
        
        // --- CASE A: Calculation restricted to a specific Line context ---
        if let line = lineContext {
            let stations = line.stationIds
            guard let startIndex = stations.firstIndex(of: startStationId),
                  let endIndex = stations.firstIndex(of: endStationId) else {
                return ([], localize("error_stations_not_in_line"))
            }
            
            let path: [String]
            if startIndex <= endIndex {
                path = Array(stations[startIndex...endIndex])
            } else {
                path = Array(stations[endIndex...startIndex]).reversed()
            }
            
            let dist = RailwayNetwork.calculatePathDistance(path: path, edges: edges)
            let desc = "\(stationName(startStationId)) → \(stationName(endStationId))"
            
            return ([(path: path, distance: dist, description: desc)], nil)
        }
        
        // --- CASE B: Global network calculation (Dijkstra) ---
        var points: [String] = [startStationId]
        points.append(contentsOf: viaStationIds.filter { !$0.isEmpty })
        points.append(endStationId)
        
        var fullAlternatives: [[(path: [String], distance: Double, description: String)]] = []
        
        guard points.count >= 2 else {
            return ([], localize("error_select_terminals"))
        }
        
        for i in 0..<(points.count - 1) {
            let results = RailwayNetwork.findAlternativePaths(from: points[i], to: points[i+1], nodes: nodes, edges: edges)
            if results.isEmpty {
                return ([], String(format: localize("error_no_path_found_fmt"), stationName(points[i]), stationName(points[i+1])))
            }
            fullAlternatives.append(results)
        }
        
        var combined: [(path: [String], distance: Double, description: String)] = []
        
        func combineRecursive(segmentIdx: Int, currentPath: [String], currentDist: Double) {
            if segmentIdx == fullAlternatives.count {
                if Set(currentPath).count == currentPath.count {
                    let desc: String
                    if let first = currentPath.first,
                       let last = currentPath.last {
                        desc = "\(stationName(first)) → \(stationName(last))"
                    } else {
                        desc = localize("multi_line_path")
                    }
                    combined.append((path: currentPath, distance: currentDist, description: desc))
                }
                return
            }
            
            for alt in fullAlternatives[segmentIdx].prefix(2) {
                let newPart = segmentIdx == 0 ? alt.path : Array(alt.path.dropFirst())
                combineRecursive(segmentIdx: segmentIdx + 1, 
                                 currentPath: currentPath + newPart, 
                                 currentDist: currentDist + alt.distance)
            }
        }
        
        combineRecursive(segmentIdx: 0, currentPath: [], currentDist: 0)
        
        let finalCombined = combined.map { item -> (path: [String], distance: Double, description: String) in
            let trueDist = RailwayNetwork.calculatePathDistance(path: item.path, edges: edges)
            return (item.path, trueDist, item.description)
        }
        
        let sorted = finalCombined.sorted(by: { $0.distance < $1.distance })
        if sorted.isEmpty {
            return ([], localize("error_no_simple_path"))
        } else {
            return (sorted, nil)
        }
    }
    
    private func selectAlternative(_ index: Int) {
        guard index >= 0 && index < alternatives.count else { return }
        let alt = alternatives[index]
        stationSequence = alt.path
    }
    
    private func invertPath() {
        let oldStart = startStationId
        let oldEnd = endStationId
        
        startStationId = oldEnd
        endStationId = oldStart
        
        if viaStationIds.count > 1 {
            viaStationIds.reverse()
        }
        
        if !stationSequence.isEmpty {
            stationSequence.reverse()
        }
        
        alternatives = []
        selectedAlternativeIndex = nil
        errorMessage = nil
    }
    
    private func getSuggestions() -> [Node] {
        guard let lastId = stationSequence.last else { return [] }
        let connectedIds = network.getNeighborStations(for: lastId)
        // Filter out stations already in sequence to avoid immediate loops, 
        // but allow them if the user explicitly wants them (unfiltered in picker).
        // For quick suggestions, we prioritize new stations.
        return network.nodes.filter { connectedIds.contains($0.id) && !stationSequence.contains($0.id) }
            .sorted { $0.name < $1.name }
    }
    
    @ViewBuilder
    private func aiAnalysisView(analysis: RailwayAIService.RouteAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("railway_ai_analysis".localized).bold()
                
                if analysis.travelTimeMin != nil {
                    Spacer()
                    Text("AI Engine V2")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .font(.subheadline)
            
            if let rec = analysis.recommendation {
                Text(rec)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.bottom, 4)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("est_duration_short".localized).font(.caption2).foregroundColor(.secondary)
                    if let tt = analysis.travelTimeMin {
                        Text(String(format: "duration_min_fmt".localized, tt)).font(.subheadline).bold()
                    } else {
                        Text("N/A").font(.subheadline).bold()
                    }
                }
                VStack(alignment: .leading) {
                    Text("max_frequency_label".localized).font(.caption2).foregroundColor(.secondary)
                    if let maxStr = analysis.maxFrequency, !maxStr.isEmpty {
                        Text(maxStr).font(.subheadline).bold()
                    } else if let headway = analysis.minHeadwayMin {
                        Text(String(format: "every_min_fmt".localized, Int(headway))).font(.subheadline).bold()
                    } else {
                        Text("N/A").font(.subheadline).bold()
                    }
                }
                VStack(alignment: .leading) {
                    Text("recommended_label".localized).font(.caption2).foregroundColor(.secondary)
                    if let recStr = analysis.recommendedFrequency, !recStr.isEmpty {
                        Text(recStr).font(.subheadline).bold()
                    } else if let recommended = analysis.optimalHeadwayMin {
                        Text(String(format: "every_min_fmt".localized, Int(recommended))).font(.subheadline).bold()
                    } else {
                        Text("N/A").font(.subheadline).bold()
                    }
                }
                VStack(alignment: .leading) {
                    Text("optimal_offset_label".localized).font(.caption2).foregroundColor(.secondary)
                    let offset = analysis.optimalOffsetMin ?? Double(analysis.optimalOffsetAB ?? 0)
                    Text(String(format: "interval_min_fmt".localized, Int(offset))).font(.subheadline).bold()
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var localAnalysisView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                Text("local_optimization_pignolo".localized).bold()
                Spacer()
                if cadenceOptimizer.isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Button(action: { findLocalIdealOffset() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.subheadline)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("optimal_offset_label".localized).font(.caption2).foregroundColor(.secondary)
                    if let offset = localProposedOffset {
                        Text(String(format: "interval_min_fmt".localized, Int(offset))).font(.subheadline).bold()
                            .foregroundColor(.green)
                    } else {
                        Text("--").font(.subheadline).bold().foregroundColor(.secondary)
                    }
                }
                
                Text("local_ga_searching_desc".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func findLocalIdealOffset() {
        guard stationSequence.count >= 2 else { return }
        Task {
            // Find frequency from line context or default to 60
            let freq = 60.0 // Default frequency
            
            let tempLine = TrainRoute(
                id: lineContext?.id ?? "preview",
                name: "Preview",
                originStationId: stationSequence.first ?? "",
                destinationStationId: stationSequence.last ?? "",
                stationIds: stationSequence
            )
            
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: tempLine, 
                frequency: freq, 
                existingTrains: trainManager.trains, 
                network: network
            )
            self.localProposedOffset = offset
        }
    }
}
