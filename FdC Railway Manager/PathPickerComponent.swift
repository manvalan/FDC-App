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
        viaStationIds.enumerated().map { ViaItem(id: $0, stationId: $1) }
    }
    
    @State private var alternatives: [(path: [String], distance: Double, description: String)] = []
    @State private var selectedAlternativeIndex: Int? = nil
    @State private var errorMessage: String? = nil
    @State var useAutomaticSelection = true
    
    @Binding var activePicker: PickerType?
    @Binding var manualStationId: String
    var lineContext: RailwayLine? = nil
    
    @State private var isCalculating = false

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
                    if !new {
                        stationSequence = startStationId.isEmpty ? [] : [startStationId]
                    }
                }
            }
            
            if useAutomaticSelection {
                Section(header: Text("define_terminals".localized)) {
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
                            
                            Button(action: { 
                                viaStationIds.append("")
                                activePicker = .via(viaStationIds.count - 1)
                            }) {
                                Label("add_via_point".localized, systemImage: "plus.circle")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if lineContext == nil {
                        HStack {
                            Text("to".localized)
                            Spacer()
                            Button(action: { activePicker = .end }) {
                                Text(stationName(endStationId))
                                    .foregroundColor(endStationId.isEmpty ? .secondary : .primary)
                            }
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
                        .padding(.vertical, 8)
                    } else {
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
                                    Text(String(format: "path_alt_fmt".localized, alt.description, alt.path.count, alt.distance))
                                        .tag(Int?.some(index))
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            // Only one alternative, show info
                            let alt = alternatives[0]
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text(String(format: "path_found_fmt".localized, alt.description))
                                Spacer()
                                Text(String(format: "%.1f km", alt.distance))
                                    .font(.caption).bold()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if let selectedIdx = selectedAlternativeIndex, selectedIdx < alternatives.count {
                        let alt = alternatives[selectedIdx]
                        HStack {
                            Text("total_distance".localized)
                            Spacer()
                            Text(String(format: "%.1f km", alt.distance))
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
        lineContext: RailwayLine?,
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
            let stations = line.stations
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
            
            let dist = RailwayNetwork.calculatePathDistance(path, edges: edges)
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
                    let desc = (currentPath.first != nil && currentPath.last != nil) ? 
                        "\(stationName(currentPath.first!)) → \(stationName(currentPath.last!))" : localize("multi_line_path")
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
            let trueDist = RailwayNetwork.calculatePathDistance(item.path, edges: edges)
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
        let connectedIds = network.edges.compactMap { edge -> String? in
            if edge.from == lastId { return edge.to }
            if edge.to == lastId { return edge.from }
            return nil
        }
        // Filter out stations already in sequence to avoid immediate loops, 
        // but allow them if the user explicitly wants them (unfiltered in picker).
        // For quick suggestions, we prioritize new stations.
        return network.nodes.filter { connectedIds.contains($0.id) && !stationSequence.contains($0.id) }
            .sorted { $0.name < $1.name }
    }
}
