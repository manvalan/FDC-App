import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

// MARK: - ContentView Unified UI
struct ContentView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @EnvironmentObject var appState: AppState
    @StateObject private var aiService = RailwayAIService.shared
    
    // Navigation State
    // @State private var sidebarSelection: SidebarItem? = .lines <-- Moved to AppState
    @State private var selectedLine: RailwayLine? = nil
    @State private var selectedNode: Node? = nil
    @State private var selectedEdgeId: String? = nil // New state for edge selection
    @State private var selectedTrains: Set<UUID> = [] // Multi-selection support
    @State private var highlightedConflictLocation: String? = nil // State for map highlighting
    @State private var isExporting = false
    @State private var showCredits = false
    
    @State private var inspectorVisible: Bool = false
    
    // Global Settings State (lifted for easy access)
    @State private var showGrid: Bool = false
    @State private var isMoveModeEnabled: Bool = false
    
    // Infrastructure validation
    @State private var missingTracks: [(from: String, to: String, type: Edge.TrackType)] = []
    @State private var showInfrastructureAlert = false
    

    var body: some View {
        VStack(spacing: 0) {
            topNavigationBar
            
            HStack(spacing: 0) {
                // 1. MASTER LIST (Left)
                if appState.sidebarSelection != nil {
                    sidebarContent
                        .frame(width: 300)
                        .background(Color.secondary.opacity(0.05))
                        .background(.ultraThinMaterial)
                    
                    Divider()
                        .edgesIgnoringSafeArea(.all)
                }
                
                // 2. MAIN VIEW (Center Map)
                detailContent
                    .layoutPriority(1)
                
                // 3. PROPERTIES / DIAGRAM (Right)
                if isSomethingSelected {
                    Divider()
                        .edgesIgnoringSafeArea(.all)
                    
                    sidebarPropertiesContent
                        .frame(width: 350)
                        .background(Color.secondary.opacity(0.05))
                        .background(.ultraThinMaterial)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.spring(), value: appState.sidebarSelection)
        .animation(.spring(), value: isSomethingSelected)
        .environmentObject(network)
        .onMainStateChanges(
            selectedLine: $selectedLine,
            selectedNode: $selectedNode,
            selectedEdgeId: $selectedEdgeId,
            selectedTrains: $selectedTrains,
            inspectorVisible: $inspectorVisible
        )
        .onNetworkStateChanges(appState: appState, network: network, trainManager: trainManager, selectedTrains: $selectedTrains)
        .onChange(of: appState.sidebarSelection) { _ in
            // Clear selection when switching modes to avoid 'confusion'
            selectedLine = nil
            selectedNode = nil
            selectedEdgeId = nil
            selectedTrains = []
        }
    }

    
    @ViewBuilder
    private var sidebarPropertiesContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("details".localized)
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        selectedLine = nil
                        selectedNode = nil
                        selectedEdgeId = nil
                        selectedTrains = []
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    if let node = selectedNode, let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        StationEditView(
                            station: $network.nodes[index],
                            isMoveModeEnabled: $isMoveModeEnabled,
                            onDelete: {
                                withAnimation {
                                    network.removeNode(node.id)
                                    selectedNode = nil
                                }
                            }
                        )
                        .id("node-\(node.id)")
                    } else if let line = selectedLine {
                        LineDetailView(line: Binding(
                            get: { line },
                            set: { newVal in
                                if let idx = network.lines.firstIndex(where: { $0.id == line.id }) {
                                    network.lines[idx] = newVal
                                    selectedLine = newVal
                                }
                            }
                        ), isMoveModeEnabled: $isMoveModeEnabled, selectedNode: $selectedNode, selectedEdgeId: $selectedEdgeId)
                        .id("line-\(line.id)")
                    } else if let edgeId = selectedEdgeId, let index = network.edges.firstIndex(where: { $0.id.uuidString == edgeId }) {
                        TrackEditView(edge: $network.edges[index]) {
                            withAnimation {
                                network.removeEdge(network.edges[index].from, network.edges[index].to)
                                selectedEdgeId = nil
                            }
                        }
                        .id("edge-\(edgeId)")
                    } else if !selectedTrains.isEmpty {
                        if selectedTrains.count == 1, let trainId = selectedTrains.first, let train = trainManager.trains.first(where: { $0.id == trainId }) {
                            TrainDetailView(train: train)
                                .id("train-\(trainId)")
                        } else {
                            BatchTrainEditView(selectedIds: selectedTrains)
                        }
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if let selection = appState.sidebarSelection {
            switch selection {
            case .network:
                NetworkListView(network: network, selectedNode: $selectedNode, selectedEdgeId: $selectedEdgeId)
            case .lines:
                LinesListView(network: network, selectedLine: $selectedLine)
            case .trains:
                TrainsListView(selectedTrains: $selectedTrains)
            case .ai:
                RailwayAIView(network: network)
            case .io:
                IOManagementView()
            case .settings:
                SettingsView(showGrid: $showGrid)
            }
        } else {
            Text("select_category".localized)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        RailwayMapView(
            network: network,
            selectedNode: $selectedNode,
            selectedLine: $selectedLine,
            selectedEdgeId: $selectedEdgeId,
            showGrid: $showGrid,
            isMoveModeEnabled: $isMoveModeEnabled,
            highlightedConflictLocation: $highlightedConflictLocation,
            mode: (appState.sidebarSelection == .lines || appState.sidebarSelection == .trains || appState.sidebarSelection == .io) ? .lines : .network
        )
    }
    
    private var isSomethingSelected: Bool {
        selectedLine != nil || selectedNode != nil || selectedEdgeId != nil || !selectedTrains.isEmpty
    }
    private var topNavigationBar: some View {
        HStack(spacing: 0) {
            Text("🚊 FdC Manager")
                .font(.system(size: 16, weight: .black))
                .padding(.horizontal, 20)
                .foregroundStyle(.primary)
            
            Divider()
                .frame(height: 24)
            
            HStack(spacing: 8) {
                ForEach(SidebarItem.allCases) { item in
                    tabButton(for: item)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Connection Status and global info
            HStack(spacing: 20) {
                if let selection = appState.sidebarSelection, selection == .ai {
                    connectionIndicator
                }
                
                exportMenu
                
                Button(action: { showCredits = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showCredits) {
            CreditsView()
        }
        .frame(height: 50)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("exporting_in_progress".localized)
                            .font(.subheadline.bold())
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    
    private var exportMenu: some View {
        Menu {
            Section("current_screen".localized) {
                Button(action: { exportCurrentScreen(as: .jpeg) }) {
                    Label("export_jpg".localized, systemImage: "photo")
                }
                Button(action: { exportCurrentScreen(as: .pdf) }) {
                    Label("export_pdf".localized, systemImage: "doc.text")
                }
                Button(action: { printCurrentScreen() }) {
                    Label("print".localized, systemImage: "printer")
                }
            }
            
            if appState.sidebarSelection == .network || appState.sidebarSelection == .lines {
                Section("map".localized) {
                    Button(action: { /* Triggers map-specific high-res export */ }) {
                        Label("high_res_map".localized, systemImage: "map")
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14))
                .padding(8)
                .background(Circle().fill(Color.primary.opacity(0.05)))
        }
    }
    
    @MainActor
    private func exportCurrentScreen(as format: ExportFormat) {
        isExporting = true
        
        let mode: RailwayMapView.MapVisualizationMode = (appState.sidebarSelection == .lines || appState.sidebarSelection == .trains) ? .lines : .network
        
        // Prepare High-Res Snapshot Data for the MAP (the central view)
        let snapshotData = RailwayMapView.MapSnapshotData.prepare(
            nodes: network.nodes,
            edges: network.edges,
            lines: network.lines,
            schedules: appState.simulator.schedules,
            mode: mode,
            globalFontSize: 24, // High res labels
            globalLineWidth: 14 // High res lines
        )
        
        // Global Export from TOP bar always exports the MAP (viewed at center)
        let finalView = RailwayMapView.RailwayMapSnapshot(data: snapshotData)
            .environmentObject(appState)
            .frame(width: 2048, height: 1536)
        
        Task {
            if format == .jpeg {
                if let image = ExportUtils.exportViewAsImage(content: finalView) {
                    ExportUtils.shareItem(image)
                }
            } else {
                if let url = ExportUtils.exportViewAsPDF(content: finalView, fileName: "FdC_Mappa_Rete") {
                    ExportUtils.shareItem(url)
                }
            }
            isExporting = false
        }
    }
    
    @MainActor
    private func printCurrentScreen() {
        isExporting = true
        
        let mode: RailwayMapView.MapVisualizationMode = (appState.sidebarSelection == .lines || appState.sidebarSelection == .trains) ? .lines : .network
        let snapshotData = RailwayMapView.MapSnapshotData.prepare(
            nodes: network.nodes,
            edges: network.edges,
            lines: network.lines,
            schedules: appState.simulator.schedules,
            mode: mode,
            globalFontSize: 20,
            globalLineWidth: 12
        )
        
        let finalView = RailwayMapView.RailwayMapSnapshot(data: snapshotData)
            .environmentObject(appState)
            .frame(width: 1600, height: 1200)
        
        Task {
            if let image = ExportUtils.exportViewAsImage(content: finalView) {
                ExportUtils.printImage(image, jobName: "print_job_map".localized)
            }
            isExporting = false
        }
    }
    
    private func tabButton(for item: SidebarItem) -> some View {
        let isSelected = appState.sidebarSelection == item
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.sidebarSelection = item
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.15))
                        .matchedGeometryEffect(id: "tab_background", in: tabNameSpace)
                }
            }
            .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
    
    @Namespace private var tabNameSpace
    
    private var connectionIndicator: some View {
        return Group {
            switch aiService.connectionStatus {
            case .connected:
                Circle().fill(Color.green).frame(width: 8, height: 8)
            case .connecting:
                ProgressView().scaleEffect(0.5).frame(width: 8, height: 8)
            case .unauthorized, .error:
                Circle().fill(Color.red).frame(width: 8, height: 8)
            case .disconnected:
                Circle().fill(Color.gray).frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Navigation Logic Extensions
extension View {
    func onMainStateChanges(
        selectedLine: Binding<RailwayLine?>,
        selectedNode: Binding<Node?>,
        selectedEdgeId: Binding<String?>,
        selectedTrains: Binding<Set<UUID>>,
        inspectorVisible: Binding<Bool>
    ) -> some View {
        self
            .onChange(of: selectedLine.wrappedValue) { newVal in
                if newVal != nil {
                    selectedNode.wrappedValue = nil
                    selectedEdgeId.wrappedValue = nil
                    selectedTrains.wrappedValue = []
                    inspectorVisible.wrappedValue = true
                }
            }
            .onChange(of: selectedNode.wrappedValue) { newVal in
                if newVal != nil {
                    print("📍 [ContentView] selectedNode changed to: \(newVal?.name ?? "nil")")
                    selectedLine.wrappedValue = nil
                    selectedEdgeId.wrappedValue = nil
                    selectedTrains.wrappedValue = []
                    inspectorVisible.wrappedValue = true
                }
            }
            .onChange(of: selectedEdgeId.wrappedValue) { newVal in
                if newVal != nil {
                    print("🛤️ [ContentView] selectedEdgeId changed to: \(newVal ?? "nil")")
                    selectedLine.wrappedValue = nil
                    selectedNode.wrappedValue = nil
                    selectedTrains.wrappedValue = []
                    inspectorVisible.wrappedValue = true
                }
            }
            .onChange(of: selectedTrains.wrappedValue) { newVal in
                if !newVal.isEmpty {
                    selectedLine.wrappedValue = nil
                    selectedNode.wrappedValue = nil
                    selectedEdgeId.wrappedValue = nil
                    inspectorVisible.wrappedValue = true
                }
            }
    }
    
    func onNetworkStateChanges(
        appState: AppState,
        network: RailwayNetwork,
        trainManager: TrainManager,
        selectedTrains: Binding<Set<UUID>>
    ) -> some View {
        self
            .onChange(of: appState.jumpToTrainId) { trainId in
                if let tId = trainId {
                    appState.sidebarSelection = .trains
                    selectedTrains.wrappedValue = [tId]
                    appState.jumpToTrainId = nil
                }
            }
            .onChange(of: network.lines) { _ in
                trainManager.validateSchedules(with: network)
            }
            .onChange(of: trainManager.trains) { _ in
                trainManager.validateSchedules(with: network)
                appState.simulator.schedules = trainManager.generateSchedules(with: network)
            }
    }
}

// MARK: - Legacy Inspector Removed
// SidebarInspectorView functionality merged into sidebarContainer

// MARK: - Subviews for Content Column

struct NetworkListView: View {
    @ObservedObject var network: RailwayNetwork
    @Binding var selectedNode: Node?
    @Binding var selectedEdgeId: String?
    
    @State private var mode: NetworkListMode = .stations
    
    enum NetworkListMode: String, CaseIterable, Identifiable {
        case stations = "stations"
        case tracks = "tracks"
        var id: String { rawValue }
        
        var localizedName: String {
            self.rawValue.localized
        }
    }
    
    private func stationName(for id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? "Unknown (\(id.prefix(4)))"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("visualization".localized, selection: $mode) {
                ForEach(NetworkListMode.allCases) { m in
                    Text(m.localizedName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                if mode == .stations {
                    Section(String(format: "stations_count".localized, network.nodes.count)) {
                        ForEach(network.sortedNodes) { node in
                            HStack {
                                Text(node.name)
                                    .foregroundColor(node.id == selectedNode?.id ? .blue : .primary)
                                Spacer()
                                if node.type == .interchange {
                                    Image(systemName: "star.fill").foregroundColor(.yellow)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNode = node
                            }
                            .listRowBackground(node.id == selectedNode?.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                        .onDelete { indexSet in
                            let sorted = network.sortedNodes
                            for index in indexSet {
                                let node = sorted[index]
                                network.removeNode(node.id)
                                if selectedNode?.id == node.id {
                                    selectedNode = nil
                                }
                            }
                        }
                    }
                } else {
                    Section(String(format: "tracks_count".localized, network.edges.count)) {
                        ForEach(network.sortedEdges) { edge in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(stationName(for: edge.from)) → \(stationName(for: edge.to))")
                                        .fontWeight(selectedEdgeId == edge.id.uuidString ? .bold : .regular)
                                        .foregroundColor(selectedEdgeId == edge.id.uuidString ? .blue : .primary)
                                    Text("\(Int(edge.distance)) km - \(edge.trackType.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedEdgeId == edge.id.uuidString {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEdgeId = edge.id.uuidString
                            }
                            .listRowBackground(selectedEdgeId == edge.id.uuidString ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                        .onDelete { indexSet in
                            let sorted = network.sortedEdges
                            for index in indexSet {
                                let edge = sorted[index]
                                network.removeEdge(edge.from, edge.to)
                                if selectedEdgeId == edge.id.uuidString {
                                    selectedEdgeId = nil
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("network".localized)
    }
}

struct LinesListView: View {
    @ObservedObject var network: RailwayNetwork
    @Binding var selectedLine: RailwayLine?
    @State private var showCreate = false
    @State private var editingLineId: String? = nil
    
    var body: some View {
        List {
            ForEach(network.sortedLines) { line in
                HStack {
                    if let color = line.color {
                        Circle().fill(Color(hex: color) ?? .black).frame(width: 10, height: 10)
                    }
                    Text(line.name)
                        .fontWeight(selectedLine?.id == line.id ? .bold : .regular)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedLine = line
                }
                .contextMenu {
                    Button(action: { editingLineId = line.id }) {
                        Label("edit_line".localized, systemImage: "pencil")
                    }
                    Button(role: .destructive, action: {
                        if let idx = network.lines.firstIndex(where: { $0.id == line.id }) {
                            network.lines.remove(at: idx)
                            if selectedLine?.id == line.id { selectedLine = nil }
                        }
                    }) {
                        Label("delete_line".localized, systemImage: "trash")
                    }
                }
                .listRowBackground(selectedLine?.id == line.id ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            .onDelete { indexSet in
                let sorted = network.sortedLines
                for index in indexSet {
                    let line = sorted[index]
                    if let idx = network.lines.firstIndex(where: { $0.id == line.id }) {
                        network.lines.remove(at: idx)
                        if selectedLine?.id == line.id { selectedLine = nil }
                    }
                }
            }
        }
        .navigationTitle("lines".localized)
        .toolbar {
            Button(action: { showCreate = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showCreate) {
            LineCreationView()
        }
        .sheet(item: Binding(
            get: { editingLineId.map { IdentifiableString(id: $0) } },
            set: { editingLineId = $0?.id }
        )) { ident in
            LineEditView(lineId: ident.id)
        }
    }
}
struct TrainsListView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState
    
    @Binding var selectedTrains: Set<UUID>
    @State private var showAddTrain = false
    @State private var customTrainLine: RailwayLine? = nil
    @State private var showScheduleForLine: RailwayLine? = nil

    // AI State
    @State private var suggestingForLine: RailwayLine? = nil
    @State private var aiSuggestion: String? = nil
    @State private var isAiLoading = false
    
    struct ScheduleRequest: Identifiable {
        let id = UUID()
        let line: RailwayLine
        let mode: ScheduleCreationView.ScheduleMode
    }
    @State private var activeScheduleRequest: ScheduleRequest? = nil
    
    var body: some View {
        List {
            ForEach(network.sortedLines) { line in
                Section(header: LineHeader(
                    line: line,
                    onAddTrain: { 
                        activeScheduleRequest = ScheduleRequest(line: line, mode: .single)
                    },
                    onAddTrainCadenced: { 
                        activeScheduleRequest = ScheduleRequest(line: line, mode: .cadenced)
                    },
                    onShowSchedule: { showScheduleForLine = line }
                )) {
                    let lineTrains = manager.trains.filter { $0.lineId == line.id }
                    
                    if lineTrains.isEmpty {
                        Text("no_trains_assigned".localized).font(.caption).foregroundColor(.secondary)
                    }
                    
                    ForEach(lineTrains) { train in
                        TrainRow(
                            train: train,
                            selectedIds: selectedTrains,
                            onSelectTrain: { t in selectedTrains = [t.id] },
                            onToggleSelection: { t in
                                if selectedTrains.contains(t.id) { selectedTrains.remove(t.id) }
                                else { selectedTrains.insert(t.id) }
                            }
                        )
                    }
                    .onDelete { idx in
                        let toDel = idx.map { lineTrains[$0] }
                        manager.trains.removeAll { t in toDel.contains(where: { t.id == $0.id }) }
                    }
                }
            }
            
            Section("unassigned_trains".localized) {
                let unassigned = manager.trains.filter { $0.lineId == nil }
                ForEach(unassigned) { train in
                    Button(action: {
                        selectedTrains = [train.id]
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                            Text(train.name)
                            Spacer()
                            Text(train.type.localized).font(.caption)
                        }
                        .background(selectedTrains.contains(train.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { idx in
                    let toDel = idx.map { unassigned[$0] }
                    manager.trains.removeAll { t in toDel.contains(where: { $0.id == t.id }) }
                }
            }
        }
        .navigationTitle("schedule_management".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    manager.trains.removeAll()
                    appState.simulator.schedules.removeAll()
                    selectedTrains.removeAll()
                }) {
                    Label("delete_all_trains".localized, systemImage: "trash.fill")
                }
                .foregroundColor(.red)
                .help("delete_all_trains_help".localized)
            }
        }
        .sheet(item: $activeScheduleRequest) { req in
            ScheduleCreationView(line: req.line, initialMode: req.mode)
        }
        .sheet(item: $customTrainLine) { line in
            TrainCreationView(line: line)
        }
        .fullScreenCover(item: $showScheduleForLine) { line in
            NavigationStack {
                LineScheduleView(line: line)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("close".localized) {
                                showScheduleForLine = nil
                            }
                        }
                    }
            }
        }
        // Popover removed - using Inspector in ContentView
        .alert("ai_suggestion_alert".localized, isPresented: Binding(get: { aiSuggestion != nil }, set: { if !$0 { aiSuggestion = nil } })) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text(aiSuggestion ?? "")
        }
    }
    
    private func suggestFrequency(for line: RailwayLine) {
        let stopNames = line.stops.compactMap { s in 
            if let name = network.nodes.first(where: { $0.id == s.stationId })?.name {
                return s.isSkipped ? "\(name) (Transito)" : name
            }
            return nil
        }.joined(separator: ", ")

        let prompt = String(format: "frequency_suggestion_prompt_fmt".localized, line.name, stopNames)
        
        isAiLoading = true
        sendToRailwayAI(prompt: prompt, network: network, endpoint: appState.aiEndpoint) { result in
            DispatchQueue.main.async {
                isAiLoading = false
                switch result {
                case .success(let resp):
                    aiSuggestion = resp
                case .failure(let err):
                    aiSuggestion = String(format: "ai_error_fmt".localized, err.localizedDescription)
                }
            }
        }
    }
}

// Helpers
struct LineHeader: View {
    let line: RailwayLine
    let onAddTrain: () -> Void
    let onAddTrainCadenced: () -> Void
    let onShowSchedule: () -> Void
    
    var body: some View {
        HStack {
            if let c = line.color {
                Circle().fill(Color(hex: c) ?? .black).frame(width: 10, height: 10)
            }
            Text(line.name).font(.headline)
            Spacer()
            
            Button(action: onShowSchedule) {
                Label("Orario Grafico", systemImage: "chart.xyaxis.line")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            Menu {
                Button(action: onAddTrain) {
                    Label("Nuova Corsa Singola", systemImage: "train.side.front.car")
                }
                Button(action: onAddTrainCadenced) {
                    Label("Genera Orario Cadenzato", systemImage: "calendar.badge.plus")
                }
            } label: {
                Image(systemName: "plus.circle")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
    }
}

struct TrainRow: View {
    let train: Train
    let selectedIds: Set<UUID>
    let onSelectTrain: (Train) -> Void
    let onToggleSelection: (Train) -> Void
    
    var body: some View {
        Button(action: { onSelectTrain(train) }) {
            HStack {
                Image(systemName: selectedIds.contains(train.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedIds.contains(train.id) ? .blue : .secondary)
                    .onTapGesture { onToggleSelection(train) }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("\(train.number)").font(.subheadline).bold().foregroundColor(.blue)
                        Text(train.name).font(.subheadline)
                    }
                    if let dep = train.departureTime {
                        Text("Partenza: \(formatTime(dep))").font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(train.type).font(.caption2).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }
}

struct LineDetailView: View {
    @Binding var line: RailwayLine
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    @Binding var isMoveModeEnabled: Bool
    @Binding var selectedNode: Node?
    @Binding var selectedEdgeId: String?
    
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: line.color ?? "") ?? .black },
            set: { if let hex = $0.toHex() { line.color = hex } }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Identification
                VStack(alignment: .leading, spacing: 8) {
                    Text("identification".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    TextField("line_name_placeholder".localized, text: $line.name)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("color_label".localized)
                        Spacer()
                        ColorPicker("", selection: colorBinding)
                            .labelsHidden()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 2. Numbering
                VStack(alignment: .leading, spacing: 8) {
                    Text("train_numbering".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("prefix".localized).font(.caption2)
                            TextField("RE", text: Binding(
                                get: { line.codePrefix ?? "" },
                                set: { line.codePrefix = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("code".localized).font(.caption2)
                            TextField("5", value: Binding(
                                get: { line.numberPrefix ?? 0 },
                                set: { line.numberPrefix = $0 == 0 ? nil : $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        }
                    }
                    
                    Text(String(format: "numbering_example".localized, line.codePrefix ?? "RE", line.numberPrefix ?? 5))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 3. Diagram
                VStack(alignment: .leading, spacing: 12) {
                    Text("vertical_diagram".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    VerticalTrackDiagramView(
                        line: $line,
                        network: network,
                        isMoveModeEnabled: $isMoveModeEnabled,
                        externalSelectedStationID: Binding(
                            get: { selectedNode?.id },
                            set: { id in
                                if let id = id {
                                    selectedNode = network.nodes.first(where: { $0.id == id })
                                } else {
                                    selectedNode = nil
                                }
                            }
                        ),
                        externalSelectedEdgeID: $selectedEdgeId
                    )
                    .frame(minHeight: 400)
                    .cornerRadius(8)
                }
                
                // 4. Dwell Times & Tracks
                VStack(alignment: .leading, spacing: 12) {
                    Text("tracks_dwells".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach($line.stops) { $stop in
                        HStack {
                            Text(stopName(stop.stationId))
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("track_label_short".localized, text: Binding(
                                get: { stop.track ?? "" },
                                set: { stop.track = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            
                            Spacer()
                            
                            Stepper(String(format: "dwell_time_min".localized, stop.minDwellTime), value: $stop.minDwellTime, in: 0...120)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }
            .padding()
        }
    }
     
     private func stopName(_ id: String) -> String {
         network.nodes.first(where: { $0.id == id })?.name ?? id
     }
 }




// ... (Subviews)

// MARK: - Document Support
struct RailwayNetworkDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.fdc, UTType.railml, UTType.rail] }
    var dto: RailwayNetworkDTO
    
    @MainActor
    init(network: RailwayNetwork, trains: [Train]) { 
        self.dto = network.toDTO(with: trains)
    }
    
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        let decoder = JSONDecoder()
        
        // 1. Try new Container format
        if let container = try? decoder.decode(RailFileContainer.self, from: data) {
            self.dto = container.network
            return
        }
        
        // 2. Try Standard DTO (Legacy JSON)
        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
            self.dto = dto
            return
        }
        
        // 3. Fallback / Validation Error
        throw CocoaError(.fileReadCorruptFile)
    }
    
    @MainActor
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        // PIGNOLO PROTOCOL: If saving as .rail, wrap in RailFileContainer with qualifier
        if configuration.contentType == .rail {
            let container = RailFileContainer(
                formatVersion: "2.0",
                qualifier: "FDC_RAIL_V2_QUALIFIED",
                network: dto,
                metadata: RailMetadata(
                    createdBy: "FdC Manager App",
                    createdAt: Date(),
                    lastModified: Date(),
                    description: "Qualified output for AI Pignolo Protocol"
                )
            )
            let data = try encoder.encode(container)
            return .init(regularFileWithContents: data)
        } else {
            // Legacy/Standard JSON export
            let data = try encoder.encode(dto)
            return .init(regularFileWithContents: data)
        }
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @EnvironmentObject var appState: AppState
    @Binding var showGrid: Bool 
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showCredits = false
    @State private var importError: String? = nil
    @State private var showLogs = false
    
    // Debug State
    struct DebugContent: Identifiable {
        let id = UUID()
        let title: String
        let json: String
    }
    @State private var debugContent: DebugContent? = nil
    
    private func showJsonInspector<T: Encodable>(for data: T, title: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let jsonData = try? encoder.encode(data), let jsonString = String(data: jsonData, encoding: .utf8) {
             debugContent = DebugContent(title: title, json: jsonString)
        } else {
             debugContent = DebugContent(title: title, json: "Errore serializzazione JSON")
        }
    }
    
    @State private var isTestLoading = false
    @State private var testResultMessage: String?
    @State private var testErrorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    private func testConnection() {
        let trimmedEndpoint = appState.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = appState.aiUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = appState.aiPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save cleaned values
        appState.aiEndpoint = trimmedEndpoint
        appState.aiUsername = trimmedUsername
        appState.aiPassword = trimmedPassword
        
        isTestLoading = true
        testResultMessage = nil
        testErrorMessage = nil
        
        // 1. Use AuthenticationManager for the official login flow
        AuthenticationManager.shared.login(username: trimmedUsername, password: trimmedPassword) { result in
            DispatchQueue.main.async {
                self.isTestLoading = false
                
                switch result {
                case .success(let token):
                    // 2. Persist the token
                    self.appState.aiToken = token
                    self.testResultMessage = "Login OK! Token ottenuto."
                    
                    // 3. Sync everything to RailwayAIService for the rest of the app
                    RailwayAIService.shared.syncCredentials(
                        endpoint: trimmedEndpoint,
                        apiKey: self.appState.aiApiKey,
                        token: token
                    )
                    RailwayAIService.shared.verifyConnection()
                    
                case .failure(let error):
                    switch error {
                    case .inactiveAccount:
                        self.testErrorMessage = "Account Inattivo. Contatta l'amministratore."
                    default:
                        self.testErrorMessage = "Errore Login: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func generateKey() {
        // PIGNOLO PROTOCOL: Proactive Sync
        RailwayAIService.shared.syncCredentials(
            endpoint: appState.aiEndpoint,
            apiKey: appState.aiApiKey,
            token: appState.aiToken
        )
        
        isTestLoading = true
        testResultMessage = "Generazione API Key..."
        testErrorMessage = nil
        
        // Use the centralized service instead of the redundant manager
        RailwayAIService.shared.generateApiKey()
            .sink { completion in
                self.isTestLoading = false
                if case .failure(let error) = completion {
                    self.testErrorMessage = "Errore Generazione Key: \(error.localizedDescription)"
                }
            } receiveValue: { key in
                self.appState.aiApiKey = key
                self.testResultMessage = "API Key Generata e Salvata!"
                // Auto-sync after generation
                RailwayAIService.shared.syncCredentials(
                    endpoint: self.appState.aiEndpoint,
                    apiKey: key,
                    token: self.appState.aiToken
                )
            }
            .store(in: &cancellables)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("language".localized)) {
                    Picker("language".localized, selection: $appState.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("ai_config".localized)) {
                    NavigationLink(destination: TrainTrackParametersView()) {
                        Label("train_params".localized, systemImage: "slider.horizontal.3")
                    }
                    
                    NavigationLink(destination: VisualizationSettingsView(showGrid: $showGrid)) {
                        Label("visualization".localized, systemImage: "eye")
                    }
                }
                
                Section(header: Text("railway_ai".localized)) {
                    NavigationLink(destination: AISettingsView()) {
                        Label("railway_ai".localized, systemImage: "sparkles")
                    }
                }
                
                Section(header: Text("settings".localized)) {
                    NavigationLink(destination: DiagnosticsSettingsView()) {
                        Label("diagnostics".localized, systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("settings".localized)
            .sheet(item: $debugContent) { content in
                NavigationStack {
                    ScrollView {
                        Text(content.json)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .textSelection(.enabled)
                    }
                    .navigationTitle(content.title)
                    .toolbar {
                        Button("Chiudi") { debugContent = nil }
                    }
                }
            }
            .sheet(isPresented: $showLogs) {
                LogViewerSheet()
            }
            .sheet(isPresented: $showCredits) {
                CreditsView()
            }
        }
    }
}

// MARK: - RailwayIOView
struct RailwayIOView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    @Binding var showGrid: Bool
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section("file_management".localized) {
                    Button(action: { showExporter = true }) {
                        Label {
                            Text("save_project".localized)
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Button(action: { showImporter = true }) {
                        Label {
                            Text("open_project".localized)
                            Text("support_format".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Button(action: { 
                        Task { await loader.saveCurrentState() }
                    }) {
                        Label {
                            Text("save_local".localized)
                            Text("save_local_desc".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "tray.and.arrow.down")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("legacy_integration".localized), footer: Text("legacy_footer".localized)) {
                    Button(action: { showImporter = true }) {
                        Label("import_old".localized, systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: { showExporter = true }) {
                        Label("export_new".localized, systemImage: "arrow.up.doc")
                            .foregroundColor(.blue)
                    }
                }
                
                if let importError = importError {
                    Section {
                        Text(importError).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("io_title".localized)
            .fileExporter(isPresented: $showExporter, document: RailwayNetworkDocument(network: network, trains: trainManager.trains), contentType: .rail, defaultFilename: "rete-ferroviaria") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .fdc, .railml, .rail]) { result in
                do {
                    let url = try result.get()
                    
                    // Store the URL for future reference
                    UserDefaults.standard.set(url.absoluteString, forKey: "lastOpenedURL")
                    
                    // PIGNOLO PROTOCOL: On iOS/iPadOS, we MUST startAccessingSecurityScopedResource for external files
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Impossibile ottenere l'accesso al file (Security Scoped Resource)"
                        return
                    }
                    
                    defer { 
                        url.stopAccessingSecurityScopedResource()
                        // Save the imported state as the new "last session"
                        Task {
                            await loader.saveCurrentState()
                        }
                    }
                    
                    let data = try Data(contentsOf: url)
                    if url.pathExtension.lowercased() == "fdc" {
                        let parsed = try FDCParser.parse(data: data)
                        let nodes = parsed.stations.map { fdc in
                            let type: Node.NodeType = {
                                switch fdc.type?.lowercased() {
                                case "interchange": return .interchange
                                case "depot": return .depot
                                default: return .station
                                }
                            }()
                            return Node(id: fdc.id, name: fdc.name, type: type, latitude: fdc.latitude, longitude: fdc.longitude, capacity: fdc.capacity, platforms: fdc.platformCount ?? 2)
                        }
                        let edges = parsed.edges.map { fdc in
                            Edge(from: fdc.from, to: fdc.to, distance: fdc.distance ?? 1.0, trackType: .regional, maxSpeed: Int(fdc.maxSpeed ?? 120), capacity: fdc.capacity)
                        }
                        var trainIdMap: [String: UUID] = [:]
                        let newTrains = parsed.trains.enumerated().map { (idx, fdc) -> Train in
                            let mid = UUID()
                            trainIdMap[fdc.id] = mid
                            
                            // Parse number from name or use sequence
                            let components = fdc.name.components(separatedBy: .whitespaces)
                            let number = components.compactMap { Int($0) }.first ?? (1000 + idx)
                            
                            return Train(id: mid, 
                                        number: number,
                                        name: fdc.name, 
                                        type: fdc.type ?? "Regionale", 
                                        maxSpeed: fdc.maxSpeed ?? 120, 
                                        priority: fdc.priority ?? 5, 
                                        acceleration: fdc.acceleration ?? 0.5, 
                                        deceleration: fdc.deceleration ?? 0.5, 
                                        stops: [])
                        }
                        
                        // Map schedules into trains
                        let df = ISO8601DateFormatter()
                        var tFinal = newTrains
                        
                        for sch in parsed.rawSchedules {
                            if let mid = trainIdMap[sch.train_id], let tIdx = tFinal.firstIndex(where: { $0.id == mid }) {
                                tFinal[tIdx].departureTime = sch.stops.first.flatMap { df.date(from: $0.departure) }
                                tFinal[tIdx].stops = sch.stops.map { stop in
                                    RelationStop(stationId: stop.node_id, 
                                                 minDwellTime: 2, 
                                                 track: stop.platform.map { "\($0)" }, 
                                                 arrival: df.date(from: stop.arrival), 
                                                 departure: df.date(from: stop.departure))
                                }
                            }
                        }
                        
                        trainManager.trains = tFinal
                        network.name = parsed.name
                        network.nodes = nodes
                        network.edges = edges
                        network.lines = parsed.lines
                        trainManager.validateSchedules(with: network)
                        
                    } else if url.pathExtension.lowercased() == "railml" {
                        let parser = RailMLParser()
                        if let res = parser.parse(data: data) {
                            network.name = url.deletingPathExtension().lastPathComponent
                            network.nodes = res.nodes
                            network.edges = res.edges
                            network.lines = []
                        } else {
                            importError = "Parsing RailML fallito"
                        }
                        trainManager.validateSchedules(with: network)
                    } else {
                        // JSON / RAIL Handler
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        
                        // 1. Try Container (RAIL)
                        if let container = try? decoder.decode(RailFileContainer.self, from: data) {
                             network.apply(dto: container.network)
                             if let trains = container.network.trains {
                                 trainManager.trains = trains
                             }
                             print("✅ Loaded .rail file: \(container.qualifier)")
                             trainManager.validateSchedules(with: network)
                        }
                        // 2. Fallback to Simple DTO (JSON)
                        do {
                            if let container = try? decoder.decode(RailFileContainer.self, from: data) {
                                network.apply(dto: container.network)
                                if let trains = container.network.trains {
                                    trainManager.trains = trains
                                }
                                trainManager.validateSchedules(with: network)
                            } else if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                                network.apply(dto: dto)
                                if let trains = dto.trains {
                                    trainManager.trains = trains
                                }
                                trainManager.validateSchedules(with: network)
                            } else {
                                // Try without ISO8601 if it was just a simple DTO
                                let simpleDecoder = JSONDecoder()
                                if let dto = try? simpleDecoder.decode(RailwayNetworkDTO.self, from: data) {
                                    network.apply(dto: dto)
                                    if let trains = dto.trains { trainManager.trains = trains }
                                    trainManager.validateSchedules(with: network)
                                } else {
                                    importError = "Impossibile decodificare il file. Formato non riconosciuto."
                                }
                            }
                        }
                    }
                } catch {
                    importError = "Errore caricamento: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - RailwayAIView
struct RailwayAIView: View {
    @EnvironmentObject var trainManager: TrainManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var network: RailwayNetwork
    @State private var aiResult: String = ""
    @State private var isLoading = false
    @State private var userPrompt: String = ""
    @State private var errorMessage: String? = nil
    
    // Proposer State
    @State private var proposedLines: [ProposedLine] = []
    @State private var schedulePreview: String = ""
    @State private var targetLines: Int = 6
    @State private var showLineProposalSheet = false
    
    // Solver State
    @State private var solutions: [AIScheduleSuggestion] = []
    @State private var resolutions: [RailwayAIResolution] = []
    @State private var optimizerStats: (delay: Double, conflicts: Int)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("ai_optimizer_fdc".localized)) {
                    Button(action: runStandardOptimization) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("solve_conflicts_json".localized)
                        }
                    }
                    .disabled(isLoading || trainManager.trains.isEmpty)
                }

                Section(header: Text("advanced_optimizer_cpp".localized)) {
                    Button(action: runAdvancedOptimization) {
                        HStack {
                            Image(systemName: "cpu.fill")
                            Text("global_optimization_pignolo".localized)
                        }
                    }
                    .disabled(isLoading || trainManager.trains.isEmpty)
                    
                    if let stats = optimizerStats {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "conflicts_detected_fmt".localized, stats.conflicts))
                            Text(String(format: "total_delay_fmt".localized, stats.delay))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("planning_assistant_fast".localized)) {
                    Stepper(String(format: "target_lines_fmt".localized, targetLines), value: $targetLines, in: 1...20)
                    
                    Button(action: runFastProposer) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("generate_schedule_proposal".localized)
                        }
                    }
                    .disabled(isLoading || network.nodes.count < 2)
                    
                    if !proposedLines.isEmpty {
                        Button(String(format: "review_proposals_fmt".localized, proposedLines.count)) {
                            showLineProposalSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }

                // Unified V2 resolutions are shown below
                
                if !resolutions.isEmpty {
                    Section(header: Text("optimized_solutions".localized)) {
                        ForEach(resolutions, id: \.train_id) { res in
                            if let uuid = RailwayAIService.shared.getTrainUUID(optimizerId: res.train_id),
                               let train = trainManager.trains.first(where: { $0.id == uuid }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(train.name).font(.headline)
                                    HStack {
                                        let sign = res.time_adjustment_min > 0 ? "+" : ""
                                        Text(String(format: "departure_adj_fmt".localized, sign, res.time_adjustment_min))
                                        
                                        if let dwells = res.dwell_delays, !dwells.isEmpty {
                                            Divider().frame(height: 10)
                                            Text(String(format: "dwells_extended_fmt".localized, dwells.count))
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        Button(action: {
                            trainManager.applyResolutions(resolutions, network: network, trainMapping: RailwayAIService.shared.getTrainMapping())
                            resolutions = []
                            aiResult = "schedules_updated_success".localized
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("apply_schedule_change".localized)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                
                if !solutions.isEmpty {
                    Section(header: Text("proposed_solutions".localized)) {
                        ForEach(solutions, id: \.trainId) { sol in
                            let train = trainManager.trains.first(where: { $0.id == sol.trainId })
                            VStack(alignment: .leading) {
                                Text(train?.name ?? "unknown_train".localized).bold()
                                Text(String(format: "new_departure_fmt".localized, sol.newDepartureTime))
                                if let adjustments = sol.stopAdjustments {
                                    Text(String(format: "modified_stops_fmt".localized, adjustments.count))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        Button("apply_changes_button".localized) {
                            trainManager.applyAISuggestions(solutions)
                            trainManager.validateSchedules(with: network)
                            solutions = []
                            aiResult = "changes_applied_success".localized
                        }
                        .foregroundColor(.green)
                    }
                }

                if !aiResult.isEmpty {
                    Section(header: Text("last_operation_result".localized)) {
                        Text(aiResult).font(.body).foregroundColor(.blue)
                        
                        Button(action: { showJSONInspector = true }) {
                            Label("json_inspection_request".localized, systemImage: "doc.text.magnifyingglass")
                        }
                        .font(.caption)
                        .padding(.top, 4)
                    }
                }
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("optimization_in_progress".localized)
                        Spacer()
                    }
                }
                
                if let error = errorMessage {
                    Section(header: Text("encountered_error".localized)) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Railway AI")
            .sheet(isPresented: $showJSONInspector) {
                NavigationStack {
                    VStack {
                        Text("json_debug_description".localized)
                            .font(.caption)
                            .padding()
                        
                        TextEditor(text: .constant(RailwayAIService.shared.lastRequestJSON))
                            .font(.system(.caption, design: .monospaced))
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding()
                    }
                    .navigationTitle("json_detail".localized)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("close".localized) { showJSONInspector = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showLineProposalSheet) {
                LineProposalView(
                    network: network,
                    proposals: proposedLines,
                    onApply: { selectedProposals, createTrains in
                        applySelectedProposals(selectedProposals, createTrains: createTrains)
                    }
                )
                .environmentObject(trainManager)
            }
        }
    }
    
    @State private var showJSONInspector = false
    
    private func runAdvancedOptimization() {
        // ROBUST INPUT LOGIC: Trim accidental spaces or newlines
        let trimmedEndpoint = appState.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = appState.aiUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = appState.aiPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Sync back
        appState.aiEndpoint = trimmedEndpoint
        appState.aiUsername = trimmedUsername
        appState.aiPassword = trimmedPassword
        
        isLoading = true
        resolutions = []
        optimizerStats = nil
        errorMessage = nil
        
        // Sync baseURL and Credentials with settings
        RailwayAIService.shared.syncCredentials(
            endpoint: trimmedEndpoint,
            apiKey: appState.aiApiKey,
            token: appState.aiToken
        )
        
        // Check for password or API Key
        if trimmedPassword.isEmpty && appState.aiApiKey.isEmpty {
            isLoading = false
            errorMessage = "Errore: Inserisci la PASSWORD o una API KEY nelle impostazioni."
            return
        }
        
        // Check if login is needed (Skip if we have a valid API Key)
        if RailwayAIService.shared.token == nil && RailwayAIService.shared.apiKey == nil {
            aiResult = "Autenticazione in corso..."
            RailwayAIService.shared.login(username: trimmedUsername, password: trimmedPassword)
                .sink { completion in
                    if case .failure(let error) = completion {
                        isLoading = false
                        errorMessage = "Login fallito: \(error.localizedDescription)"
                    }
                } receiveValue: { token in
                    appState.aiToken = token // Persist!
                    self.performOptimizationCall()
                }
                .store(in: &cancellables)
        } else {
            self.performOptimizationCall()
        }
    }

    private func runStandardOptimization() {
        isLoading = true
        aiResult = "Analisi conflitti in corso..."
        errorMessage = nil
        
        let reporter = trainManager.conflictManager
        let request = RailwayAIService.shared.createRequest(
            network: network,
            trains: trainManager.trains,
            conflicts: reporter.conflicts
        )
        
        RailwayAIService.shared.optimize(request: request)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Optimizer Error: \(error.localizedDescription)"
                }
            } receiveValue: { response in
                if response.success {
                    self.resolutions = response.resolutions ?? []
                    self.optimizerStats = (response.total_delay_minutes ?? 0, response.conflicts_detected ?? 0)
                    self.aiResult = "Analisi completata! \(response.resolutions?.count ?? 0) modifiche proposte."
                } else {
                    errorMessage = response.error_message ?? "L'AI ha riportato un fallimento."
                }
            }
            .store(in: &cancellables)
    }

    private func performOptimizationCall() {
        aiResult = "Ottimizzazione matematica in corso..."
        print("[AI] Starting Advanced Optimization Call...")
        
        RailwayAIService.shared.optimize(request: RailwayAIService.shared.createRequest(network: network, trains: trainManager.trains, conflicts: []))
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Optimizer Error: \(error.localizedDescription)"
                    print("[AI] Request Failed: \(error)")
                }
            } receiveValue: { response in
                print("[AI] Received Response. Success: \(response.success)")
                if response.success {
                    self.resolutions = response.resolutions ?? []
                    self.optimizerStats = (response.total_delay_minutes ?? 0, response.conflicts_detected ?? 0)
                    
                    if (response.resolutions ?? []).isEmpty {
                        self.aiResult = "Nessuna soluzione trovata dall'AI."
                    } else {
                        self.aiResult = "Ottimizzazione completata! \(response.resolutions?.count ?? 0) modifiche proposte."
                    }
                } else {
                    errorMessage = "L'ottimizzatore ha riportato un fallimento."
                }
            }
            .store(in: &cancellables)
    }

    private func runFastProposer() {
        isLoading = true
        errorMessage = nil
        proposedLines = []
        schedulePreview = ""
        
        // Ensure credentials are synced
        RailwayAIService.shared.syncCredentials(
            endpoint: appState.aiEndpoint,
            apiKey: appState.aiApiKey,
            token: appState.aiToken
        )
        
        let graph = RailwayGraphManager.shared
        ScheduleProposer.shared.requestProposal(using: graph, network: network, targetLines: targetLines) { result in
            isLoading = false
            switch result {
            case .success(let proposal):
                self.proposedLines = proposal.proposedLines
                
                // Format the preview items into a single string for the UI
                if let items = proposal.schedulePreviewItems {
                    let text = items.map { item -> String in
                        let nameA = RailwayGraphManager.shared.getOriginalStationId(fromNumericId: item.origin) ?? String(item.origin)
                        let nameB = RailwayGraphManager.shared.getOriginalStationId(fromNumericId: item.destination) ?? String(item.destination)
                        return "\(item.departure) | \(item.line): \(nameA) -> \(nameB)"
                    }.joined(separator: "\n")
                    self.schedulePreview = text
                } else {
                    self.schedulePreview = "Nessun dettaglio disponibile."
                }
                
                self.aiResult = "L'IA ha proposto \(proposal.proposedLines.count) nuove linee!"
            case .failure(let error):
                self.errorMessage = "Errore Proposta: \(error.localizedDescription)"
            }
        }
    }
    
    private func applyProposal() {
        for pline in proposedLines {
            // 1. Create Line
            let lineId = UUID().uuidString
            let stops = pline.stationSequence.map { sid -> RelationStop in
                let node = network.nodes.first(where: { $0.id == sid })
                let dwell = (node?.type == .interchange) ? 5 : 3
                return RelationStop(stationId: sid, minDwellTime: dwell)
            }
            
            let newLine = RailwayLine(
                id: lineId,
                name: pline.name,
                color: pline.color ?? "#007AFF",
                originId: pline.stationSequence.first ?? "",
                destinationId: pline.stationSequence.last ?? "",
                stops: stops
            )
            network.lines.append(newLine)
            
            // 2. Create sample trains for this line (Cadenced)
            let freq = pline.frequencyMinutes > 0 ? pline.frequencyMinutes : 60
            let startHour = 6
            let endHour = 22
            
            let calendar = Calendar.current
            let baseDate = calendar.startOfDay(for: Date())
            
            for hour in stride(from: startHour, to: endHour, by: 1) {
                for min in stride(from: 0, to: 60, by: freq) {
                    let departureTime = calendar.date(bySettingHour: hour, minute: min, second: 0, of: baseDate)
                    let trainNum = 1000 + network.lines.count * 100 + (hour * 10) + (min / 10)
                    
                    let newTrain = Train(
                        id: UUID(),
                        number: trainNum,
                        name: "\(pline.name) - \(trainNum)",
                        type: "Regionale",
                        maxSpeed: 120,
                        priority: 5,
                        lineId: lineId,
                        departureTime: departureTime,
                        stops: stops
                    )
                    trainManager.trains.append(newTrain)
                }
            }
        }
        
        proposedLines = []
        schedulePreview = ""
        aiResult = "Sistema aggiornato con la nuova pianificazione."
        trainManager.validateSchedules(with: network)
    }
    
    private func applySelectedProposals(_ selectedProposals: [ProposedLine], createTrains: Bool) {
        for pline in selectedProposals {
            // 1. Create Line
            let lineId = UUID().uuidString
            let stops = pline.stationSequence.map { sid -> RelationStop in
                let node = network.nodes.first(where: { $0.id == sid })
                let dwell = (node?.type == .interchange) ? 5 : 3
                return RelationStop(stationId: sid, minDwellTime: dwell)
            }
            
            let newLine = RailwayLine(
                id: lineId,
                name: pline.name,
                color: pline.color ?? "#007AFF",
                originId: pline.stationSequence.first ?? "",
                destinationId: pline.stationSequence.last ?? "",
                stops: stops
            )
            network.lines.append(newLine)
            
            // 2. Create sample trains ONLY if requested
            if createTrains {
                let freq = pline.frequencyMinutes > 0 ? pline.frequencyMinutes : 60
                let startHour = 6
                let endHour = 22
                
                let calendar = Calendar.current
                let baseDate = calendar.startOfDay(for: Date())
                
                for hour in stride(from: startHour, to: endHour, by: 1) {
                    for min in stride(from: 0, to: 60, by: freq) {
                        let departureTime = calendar.date(bySettingHour: hour, minute: min, second: 0, of: baseDate)
                        let trainNum = 1000 + network.lines.count * 100 + (hour * 10) + (min / 10)
                        
                        let newTrain = Train(
                            id: UUID(),
                            number: trainNum,
                            name: "\(pline.name) - \(trainNum)",
                            type: "Regionale",
                            maxSpeed: 120,
                            priority: 5,
                            lineId: lineId,
                            departureTime: departureTime,
                            stops: stops
                        )
                        trainManager.trains.append(newTrain)
                    }
                }
            }
        }
        
        proposedLines = []
        let trainsMsg = createTrains ? " con treni di esempio" : ""
        aiResult = "Creazione completata: \(selectedProposals.count) linee aggiunte\(trainsMsg)."
        trainManager.validateSchedules(with: network)
    }

    @State private var cancellables = Set<AnyCancellable>()
    
    private func solveConflicts() {
        isLoading = true
        solutions = []
        aiResult = "Elaborazione scenari..."
        
        let report = trainManager.generateConflictReport(network: network)
        let solverPrompt = """
        \(report)
        
        Per favore, risolvi questi conflitti suggerendo nuovi orari di partenza (newDepartureTime in formato HH:mm) ed eventualmente modificando i tempi minimi di sosta (newMinDwellTime in minuti). 
        Rispondi ESCLUSIVAMENTE con un array JSON di oggetti con questa struttura:
        [
          {
            "trainId": "UUID-DEL-TRENO",
            "newDepartureTime": "HH:mm",
            "stopAdjustments": [
              { "stationId": "ID-STAZIONE", "newMinDwellTime": 5 }
            ]
          }
        ]
        Assicurati che i nuovi orari risolvano fisicamente i conflitti mantenendo una distanza di sicurezza tra i treni.
        """
        
        sendToRailwayAI(prompt: solverPrompt, network: network, endpoint: appState.aiEndpoint) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    // Extract JSON if AI wrapped it in markdown
                    let cleanJson = response.replacingOccurrences(of: "```json", with: "")
                                        .replacingOccurrences(of: "```", with: "")
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let data = cleanJson.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode([AIScheduleSuggestion].self, from: data) {
                        self.solutions = decoded
                        self.aiResult = "Ho trovato una soluzione per \(decoded.count) treni."
                    } else {
                        self.aiResult = response
                        self.errorMessage = "L'AI non ha restituito un formato JSON valido per la risoluzione automatica."
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

@MainActor
func sendToRailwayAI(prompt: String, network: RailwayNetwork, endpoint: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Updated to use dynamic endpoint from AppState
    guard let url = URL(string: endpoint) else { completion(.failure(NSError(domain: "URL non valida", code: 0))); return }
    struct Payload: Codable { let prompt: String; let network: RailwayNetworkDTO }
    let payload = Payload(prompt: prompt, network: network.toDTO())
    guard let data = try? JSONEncoder().encode(payload) else { completion(.failure(NSError(domain: "Serializzazione JSON fallita", code: 0))); return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(Secrets.railwayAiToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = data
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error { completion(.failure(error)); return }
        
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        
        guard let data = data else {
            completion(.failure(NSError(domain: "Nessun dato ricevuto (Status: \(statusCode))", code: statusCode)))
            return
        }
        
        if statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "Nessun corpo risposta"
            let errorMsg = "Errore Server (\(statusCode)) su \(url.path): \(body)"
            completion(.failure(NSError(domain: errorMsg, code: statusCode)))
            return
        }

        do {
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let resp = obj["response"] as? String {
                    completion(.success(resp))
                } else if let choices = obj["choices"] as? [[String: Any]], 
                          let first = choices.first, 
                          let message = first["message"] as? [String: Any], 
                          let content = message["content"] as? String {
                    // Support for OpenAI-like structure
                    completion(.success(content))
                } else if let result = obj["result"] as? String {
                    completion(.success(result))
                } else {
                    // If it's valid JSON but no known field, return the raw JSON stringified
                    let raw = String(data: data, encoding: .utf8) ?? "JSON Valido ma formato ignoto"
                    completion(.success(raw))
                }
            } else if let text = String(data: data, encoding: .utf8) {
                 completion(.success(text))
            } else {
                completion(.failure(NSError(domain: "Parsing risposta AI fallito", code: 0)))
            }
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}



// MARK: - Log Viewer
struct LogViewerSheet: View {
    @ObservedObject var logger = RailwayAILogger.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(logger.logs.reversed()) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(typeString(entry.type))
                            .font(.caption2.bold())
                            .foregroundColor(typeColor(entry.type))
                    }
                    
                    Text(entry.message)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle("diagnostics_log".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("clear".localized) { logger.logs.removeAll() }
                }
            }
        }
    }
    
    private func typeString(_ type: RailwayAILogger.LogType) -> String {
        switch type {
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERR"
        case .success: return "OK"
        }
    }
    
    private func typeColor(_ type: RailwayAILogger.LogType) -> Color {
        switch type {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RailwayNetwork(name: "Preview"))
        .environmentObject(TrainManager())
        .environmentObject(AppState())
}
