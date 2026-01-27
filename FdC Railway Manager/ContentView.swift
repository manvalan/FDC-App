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
    @State private var sidebarSelection: SidebarItem? = .lines
    @State private var selectedLine: RailwayLine? = nil
    @State private var selectedNode: Node? = nil
    @State private var selectedEdgeId: String? = nil // New state for edge selection
    @State private var selectedTrains: Set<UUID> = [] // Multi-selection support
    @State private var inspectorVisible: Bool = false
    
    // Global Settings State (lifted for easy access)
    @State private var showGrid: Bool = false
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case network = "Rete"
        case lines = "Linee"
        case trains = "Treni"
        case ai = "Railway AI"
        case io = "I/O"
        case settings = "Impostazioni"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .network: return "map"
            case .lines: return "point.topleft.down.to.point.bottomright.curvepath"
            case .trains: return "train.side.front.car"
            case .ai: return "sparkles"
            case .io: return "arrow.up.doc.on.arrow.down.doc"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $sidebarSelection) { item in
                NavigationLink(value: item) {
                    HStack {
                        Label(item.rawValue, systemImage: item.icon)
                        Spacer()
                        if item == .ai {
                            connectionIndicator
                        }
                    }
                }
            }
            .navigationTitle("FdC Manager")
        } content: {
            if let selection = sidebarSelection {
                switch selection {
                case .network:
                   NetworkListView(network: network, selectedNode: $selectedNode)
                case .lines:
                    LinesListView(network: network, selectedLine: $selectedLine)
                case .trains:
                    TrainsListView(selectedTrains: $selectedTrains)
                case .ai:
                    RailwayAIView(network: network)
                case .io:
                    RailwayIOView(showGrid: $showGrid)
                case .settings:
                    SettingsView(showGrid: $showGrid) // Pass binding
                }
            } else {
                Text("Seleziona una categoria")
            }
        } detail: {
            RailwayMapView(
                network: network,
                selectedNode: $selectedNode,
                selectedLine: $selectedLine,
                selectedEdgeId: $selectedEdgeId,
                showGrid: $showGrid,
                mode: (sidebarSelection == .lines || sidebarSelection == .trains || sidebarSelection == .io) ? .lines : .network
            )
            .overlay(alignment: .bottomTrailing) {
                // Floating button to toggle inspector if selection active
                if selectedLine != nil || selectedNode != nil || selectedEdgeId != nil {
                    Button(action: { inspectorVisible.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .inspector(isPresented: $inspectorVisible) {
            Group {
                if let node = selectedNode, let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                    StationEditView(station: $network.nodes[index]) {
                        // On Delete
                        network.nodes.remove(at: index)
                        selectedNode = nil
                    }
                } else if let line = selectedLine {
                    // Binding hack for selectedLine
                    LineDetailView(line: Binding(
                        get: { line },
                        set: { newVal in
                            if let idx = network.lines.firstIndex(where: { $0.id == line.id }) {
                                network.lines[idx] = newVal
                                selectedLine = newVal
                            }
                        }
                    ))
                } else if let edgeId = selectedEdgeId, let index = network.edges.firstIndex(where: { $0.id.uuidString == edgeId }) {
                    TrackEditView(edge: $network.edges[index]) {
                        // On Delete
                        network.edges.remove(at: index)
                        selectedEdgeId = nil
                    }
                } else if !selectedTrains.isEmpty {
                    if selectedTrains.count == 1, let trainId = selectedTrains.first, let train = trainManager.trains.first(where: { $0.id == trainId }) {
                        TrainDetailView(train: train)
                    } else {
                        BatchTrainEditView(selectedIds: selectedTrains)
                    }
                } else {
                    ContentUnavailableView("Nessuna selezione", systemImage: "cursorarrow.click")
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { inspectorVisible = false }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onChange(of: selectedLine) { newVal in 
            if newVal != nil { 
                selectedNode = nil
                selectedEdgeId = nil
                selectedTrains = []
                inspectorVisible = true 
            } 
        }
        .onChange(of: selectedNode) { newVal in 
            if newVal != nil { 
                selectedLine = nil
                selectedEdgeId = nil
                selectedTrains = []
                inspectorVisible = true 
            } 
        }
        .onChange(of: selectedEdgeId) { newVal in 
            if newVal != nil { 
                selectedLine = nil
                selectedNode = nil
                selectedTrains = []
                inspectorVisible = true 
            } 
        }
        .onChange(of: selectedTrains) { newVal in
            if !newVal.isEmpty {
                selectedLine = nil
                selectedNode = nil
                selectedEdgeId = nil
                inspectorVisible = true
            }
        }
        .onChange(of: network.relations) { _ in
            trainManager.validateSchedules(with: network)
        }
    }
    
    private func releaseOthers() {} // Deprecated by specific handlers
    
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

// MARK: - Subviews for Content Column

struct NetworkListView: View {
    @ObservedObject var network: RailwayNetwork
    @Binding var selectedNode: Node?
    
    private func stationName(for id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? "Unknown (\(id.prefix(4)))"
    }
    
    var body: some View {
        List {
            Section("Stazioni (\(network.nodes.count))") {
                ForEach(network.nodes) { node in
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
                }
            }
            Section("Binari (\(network.edges.count))") {
                ForEach(network.edges) { edge in
                    VStack(alignment: .leading) {
                         Text("\(stationName(for: edge.from)) → \(stationName(for: edge.to))")
                         Text("\(Int(edge.distance)) km - \(edge.trackType.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Rete")
    }
}

struct LinesListView: View {
    @ObservedObject var network: RailwayNetwork
    @Binding var selectedLine: RailwayLine?
    @State private var showCreate = false
    
    var body: some View {
        List {
            ForEach(network.lines) { line in
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
                .listRowBackground(selectedLine?.id == line.id ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            .onDelete { idx in
                network.lines.remove(atOffsets: idx)
                if let sel = selectedLine, !network.lines.contains(where: { $0.id == sel.id }) {
                    selectedLine = nil
                }
            }
        }
        .navigationTitle("Linee")
        .toolbar {
            Button(action: { showCreate = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showCreate) {
            LineCreationView()
        }
    }
}

struct TrainsListView: View {
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    
    @State private var showAddRelationForLine: RailwayLine? = nil
    @State private var showScheduleForLine: RailwayLine? = nil // New State
    
    @State private var selectedRelation: TrainRelation? = nil // For editing
    @State private var scheduleRelation: TrainRelation? = nil // For scheduling
    @Binding var selectedTrains: Set<UUID> // Multi-selection support (Lifted to parent)
    @State private var showAddTrain = false
    
    // AI State
    @State private var suggestingForRelation: TrainRelation? = nil
    @State private var aiSuggestion: String? = nil
    @State private var isAiLoading = false
    
    var body: some View {
        List {
            ForEach(network.lines) { line in
                Section(header: LineHeader(
                    line: line,
                    onAddRelation: { showAddRelationForLine = line },
                    onShowSchedule: { showScheduleForLine = line }
                )) {
                    // Relations for this line
                    let lineRelations = network.relations.filter { $0.lineId == line.id }
                    
                    if lineRelations.isEmpty {
                        Text("Nessuna relazione definita.").font(.caption).foregroundColor(.secondary)
                    }
                    
                    ForEach(lineRelations) { relation in
                        RelationRow(
                            relation: relation,
                            trains: manager.trains.filter { $0.relationId == relation.id },
                            selectedIds: selectedTrains,
                            onSelectTrain: { train in
                                // Exclusive Selection (Inspect)
                                selectedTrains = [train.id]
                            },
                            onToggleSelection: { train in
                                // Multi-Selection Toggle
                                if selectedTrains.contains(train.id) {
                                    selectedTrains.remove(train.id)
                                } else {
                                    selectedTrains.insert(train.id)
                                }
                            },
                            onSuggest: { suggestFrequency(for: relation) },
                            onEdit: { selectedRelation = relation },
                            onSchedule: { scheduleRelation = relation }
                        )
                    }
                    .onDelete { idx in
                        // Delete relation logic
                        let toDelete = idx.map { lineRelations[$0] }
                        for rel in toDelete {
                            if let index = network.relations.firstIndex(where: { $0.id == rel.id }) {
                                network.relations.remove(at: index)
                            }
                            // Unassign trains?
                             for i in manager.trains.indices {
                                if manager.trains[i].relationId == rel.id {
                                    manager.trains[i].relationId = nil
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Treni Non Assegnati") {
                let unassigned = manager.trains.filter { $0.relationId == nil }
                ForEach(unassigned) { train in
                    Button(action: {
                        if selectedTrains.contains(train.id) {
                             selectedTrains.remove(train.id)
                        } else {
                             // Exclusive select?
                             // selectedTrains = [train.id]
                             // Let's stick to additive logic/toggle or exclusive?
                             // Consistent with RelationRow:
                             selectedTrains = [train.id]
                        }
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                            Text(train.name)
                            Spacer()
                            Text(train.type).font(.caption)
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
        .navigationTitle("Gestione Orari")
        .sheet(item: $showAddRelationForLine) { line in
            TrainRelationView(line: line) { newRel in
                network.relations.append(newRel)
            }
        }
        .sheet(item: $selectedRelation) { relation in
            // Find line
            if let line = network.lines.first(where: { $0.id == relation.lineId }) {
                TrainRelationView(line: line, relation: relation) { updatedRel in
                    if let idx = network.relations.firstIndex(where: { $0.id == relation.id }) {
                        network.relations[idx] = updatedRel
                    }
                }
            }
        }
        .sheet(item: $scheduleRelation) { relation in
            ScheduleCreationView(relation: relation)
        }
        .fullScreenCover(item: $showScheduleForLine) { line in
            NavigationStack {
                LineScheduleView(line: line)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Chiudi") {
                                showScheduleForLine = nil
                            }
                        }
                    }
            }
        }
        // Popover removed - using Inspector in ContentView
        .alert("Suggerimento AI", isPresented: Binding(get: { aiSuggestion != nil }, set: { if !$0 { aiSuggestion = nil } })) {
            Button("Ok", role: .cancel) { }
        } message: {
            Text(aiSuggestion ?? "")
        }
    }
    
    private func suggestFrequency(for relation: TrainRelation) {
        // Construct prompt
        guard let line = network.lines.first(where: { $0.id == relation.lineId }) else { return }
        
        let stopNames = relation.stops.compactMap { s in 
            if let name = network.nodes.first(where: { $0.id == s.stationId })?.name {
                return s.isSkipped ? "\(name) (Transito)" : name
            }
            return nil
        }.joined(separator: ", ")

        // Improved Prompt
        let prompt = """
        Sto pianificando l'orario ferroviario per la relazione "\(relation.name)".
        Linea di appartenenza: \(line.name). 
        Fermate (\(relation.stops.count)): \(stopNames).
        Tempo di sosta medio per fermata: 3 minuti.
        
        Suggerisci una frequenza oraria ottimale (es. ogni 30 min, ogni ora) basandoti sulla lunghezza del percorso e sul tipo di servizio (Regionale/Diretto). Fornisci una risposta concisa con la frequenza e una breve motivazione.
        """
        
        isAiLoading = true
        sendToRailwayAI(prompt: prompt, network: network, endpoint: appState.aiEndpoint) { result in
            DispatchQueue.main.async {
                isAiLoading = false
                switch result {
                case .success(let resp):
                    aiSuggestion = resp
                case .failure(let err):
                    aiSuggestion = "Errore durante la richiesta AI: \(err.localizedDescription)"
                }
            }
        }
    }
}

// Helpers
struct LineHeader: View {
    let line: RailwayLine
    let onAddRelation: () -> Void
    let onShowSchedule: () -> Void // New closure
    
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
            
            Button(action: onAddRelation) {
                Label("Nuova Relazione", systemImage: "plus.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
        }
    }
}

struct RelationRow: View {
    let relation: TrainRelation
    let trains: [Train]
    let selectedIds: Set<UUID>
    let onSelectTrain: (Train) -> Void
    let onToggleSelection: (Train) -> Void // New closure
    let onSuggest: () -> Void
    let onEdit: () -> Void
    let onSchedule: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Relation Header
            HStack {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                        Text(relation.name).font(.subheadline).bold()
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onSchedule) {
                    Image(systemName: "calendar.badge.plus").foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                
                Button(action: onSuggest) {
                    Image(systemName: "sparkles").foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil").foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            
            if isExpanded {
                if trains.isEmpty {
                    Text("Nessun treno assegnato.").font(.caption2).padding(.leading)
                } else {
                    ForEach(trains) { train in
                        HStack(spacing: 0) {
                            // Checkbox for Multi-Selection
                            Button(action: { onToggleSelection(train) }) {
                                Image(systemName: selectedIds.contains(train.id) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedIds.contains(train.id) ? .blue : .secondary)
                                    .padding(.trailing, 8)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)

                            // Main Row for Inspection (Exclusive Select)
                            Button(action: { onSelectTrain(train) }) {
                                HStack {
                                    Image(systemName: "train.side.front.car").font(.caption)
                                    Text(train.name).font(.callout)
                                    Spacer()
                                    Text(train.type).font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(selectedIds.contains(train.id) ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                        Divider().padding(.leading, 32)
                    }
                }
            }
        }
    }
}

struct LineDetailView: View {
    @Binding var line: RailwayLine
    @EnvironmentObject var network: RailwayNetwork
    
    private var colorBinding: Binding<Color> {
         Binding(
             get: { Color(hex: line.color ?? "") ?? .black },
             set: { if let hex = $0.toHex() { line.color = hex } }
         )
     }
     
     var body: some View {
         Form {
             Section("Proprietà") {
                 TextField("Nome Linea", text: $line.name)
                 ColorPicker("Colore", selection: colorBinding)
                 HStack {
                     Text("Spessore Traccia")
                     Spacer()
                     Text("\(Int(line.width ?? 12)) px")
                         .foregroundColor(.secondary)
                 }
                 Slider(value: Binding(get: { line.width ?? 12 }, set: { line.width = $0 }), in: 4...40, step: 2)
             }
             
             Section("Stazioni e Geometria") {
                 VerticalTrackDiagramView(line: line, network: network)
                     .frame(minHeight: 300)
             }
         }
         .navigationTitle("Modifica Linea")
     }
}


// ... (Subviews)

// MARK: - Document Support
struct RailwayNetworkDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.fdc, UTType.railml] }
    var dto: RailwayNetworkDTO
    
    @MainActor
    init(network: RailwayNetwork, trains: [Train]) { 
        self.dto = network.toDTO(with: trains)
    }
    
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        let decoder = JSONDecoder()
        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
            self.dto = dto
            return
        }
        // Fallback for FDC Legacy / RailML
        throw CocoaError(.fileReadCorruptFile)
    }
    
    @MainActor
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        return .init(regularFileWithContents: data)
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
        let trimmedApiKey = appState.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        appState.aiEndpoint = trimmedEndpoint
        appState.aiUsername = trimmedUsername
        appState.aiPassword = trimmedPassword
        appState.aiApiKey = trimmedApiKey
        
        isTestLoading = true
        testResultMessage = nil
        testErrorMessage = nil
        
        // Use the centralized sync logic to ensure all URL sanitization and formatting is applied
        RailwayAIService.shared.syncCredentials(
            endpoint: trimmedEndpoint,
            apiKey: trimmedApiKey,
            token: appState.aiToken
        )
        
        RailwayAIService.shared.login(username: trimmedUsername, password: trimmedPassword)
            .sink { completion in
                isTestLoading = false
                if case .failure(let error) = completion {
                    testErrorMessage = "Test Fallito: \(error.localizedDescription)"
                }
            } receiveValue: { token in
                isTestLoading = false
                appState.aiToken = token // Persist the token!
                testResultMessage = "Test Riuscito! Token JWT ottenuto e salvato."
                RailwayAIService.shared.verifyConnection() // Refresh status
            }
            .store(in: &cancellables)
    }
    
    private func generateKey() {
        isTestLoading = true
        testResultMessage = "Generazione API Key..."
        testErrorMessage = nil
        
        RailwayAIService.shared.generateApiKey()
            .sink { completion in
                isTestLoading = false
                if case .failure(let error) = completion {
                    testErrorMessage = "Errore generazione: \(error.localizedDescription)"
                }
            } receiveValue: { key in
                isTestLoading = false
                appState.aiApiKey = key
                // Sync to the service instance immediately
                RailwayAIService.shared.syncCredentials(
                    endpoint: appState.aiEndpoint,
                    apiKey: key,
                    token: appState.aiToken
                )
                testResultMessage = "API Key generata e salvata con successo!"
            }
            .store(in: &cancellables)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Visualizzazione")) {
                    Toggle("Mostra Griglia", isOn: $showGrid)
                }

                Section(header: Text("Intelligenza Artificiale")) {
                    TextField("Server API Base URL", text: $appState.aiEndpoint)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Username", text: $appState.aiUsername)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $appState.aiPassword)
                    
                    SecureField("API Key Permanente", text: $appState.aiApiKey)
                    
                    Text("Usa la Password per il login temporaneo o l'API Key per l'accesso permanente.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(action: testConnection) {
                            if isTestLoading && testResultMessage != "Generazione API Key..." {
                                ProgressView()
                            } else {
                                Text("Test Login")
                            }
                        }
                        .disabled(isTestLoading || appState.aiPassword.isEmpty)
                        
                        Spacer()
                        
                        Button(action: generateKey) {
                            if isTestLoading && testResultMessage == "Generazione API Key..." {
                                ProgressView()
                            } else {
                                Text("Genera API Key")
                            }
                        }
                        .disabled(isTestLoading || RailwayAIService.shared.token == nil)
                        .foregroundColor(.orange)
                    }
                    
                    if let result = testResultMessage {
                        Text(result).foregroundColor(.green).font(.caption)
                    }
                    if let error = testErrorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }

                Section(header: Text("Informazioni")) {
                    Button(action: { showCredits = true }) {
                        Label("Credits e Autore", systemImage: "info.circle")
                    }
                }
                
                Section("Debug Dati (JSON)") {
                    Button(action: {
                        showJsonInspector(for: network.relations, title: "Relazioni (\(network.relations.count))")
                    }) {
                        Label("Mostra JSON Relazioni", systemImage: "curlybraces")
                    }
                    Button(action: {
                        showJsonInspector(for: trainManager.trains, title: "Treni (\(trainManager.trains.count))")
                    }) {
                        Label("Mostra JSON Treni", systemImage: "curlybraces")
                    }
                }
            }
            .navigationTitle("Impostazioni")
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
                        ToolbarItem(placement: .primaryAction) {
                            Button("Chiudi") { debugContent = nil }
                        }
                    }
                }
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
    @Binding var showGrid: Bool
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Salvataggio/Caricamento")) {
                    Button(action: { showExporter = true }) {
                        Label("Salva rete su file", systemImage: "square.and.arrow.up")
                    }
                    Button(action: { showImporter = true }) {
                        Label("Carica rete da file", systemImage: "square.and.arrow.down")
                    }
                }
                
                if let importError = importError {
                    Section {
                        Text(importError).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("I/O Dati")
            .fileExporter(isPresented: $showExporter, document: RailwayNetworkDocument(network: network, trains: trainManager.trains), contentType: .json, defaultFilename: "rete-ferroviaria") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .fdc, .railml]) { result in
                do {
                    let url = try result.get()
                    
                    // PIGNOLO PROTOCOL: On iOS/iPadOS, we MUST startAccessingSecurityScopedResource for external files
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Impossibile ottenere l'accesso al file (Security Scoped Resource)"
                        return
                    }
                    
                    defer { url.stopAccessingSecurityScopedResource() }
                    
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
                        let newTrains = parsed.trains.map { fdc in
                            Train(id: UUID(), name: fdc.name, type: fdc.type ?? "Regionale", maxSpeed: fdc.maxSpeed ?? 120, priority: fdc.priority ?? 5, acceleration: fdc.acceleration ?? 0.5, deceleration: fdc.deceleration ?? 0.5, stops: [])
                        }
                        if !newTrains.isEmpty { trainManager.trains = newTrains }
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
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                            network.apply(dto: dto)
                            if let trains = dto.trains {
                                trainManager.trains = trains
                            }
                            trainManager.validateSchedules(with: network)
                        } else {
                            let legacyDecoder = JSONDecoder()
                            if let dto = try? legacyDecoder.decode(RailwayNetworkDTO.self, from: data) {
                                network.apply(dto: dto)
                                if let trains = dto.trains { trainManager.trains = trains }
                                trainManager.validateSchedules(with: network)
                            } else {
                                importError = "Formato file non supportato o corrotto"
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
    
    // Solver State
    @State private var solutions: [AIScheduleSuggestion] = []
    @State private var resolutions: [OptimizerResolution] = []
    @State private var optimizerStats: (delay: Double, conflicts: Int)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Ottimizzatore FDC (v1/v2)")) {
                    Button(action: runStandardOptimization) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Risolvi Conflitti (FDC JSON)")
                        }
                    }
                    .disabled(isLoading || trainManager.trains.isEmpty || trainManager.conflictManager.conflicts.isEmpty)
                }

                Section(header: Text("Ottimizzatore Avanzato (GA C++)")) {
                    Button(action: runAdvancedOptimization) {
                        HStack {
                            Image(systemName: "cpu.fill")
                            Text("Ottimizzazione Globale (Pignolo)")
                        }
                    }
                    .disabled(isLoading || trainManager.trains.isEmpty)
                    
                    if let stats = optimizerStats {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Conflitti rilevati: \(stats.conflicts)")
                            Text("Ritardo totale: \(String(format: "%.1f", stats.delay)) min")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                if !resolutions.isEmpty {
                    Section(header: Text("Analisi Ottimizzazione")) {
                        ForEach(resolutions, id: \.trainId) { res in
                            if let uuid = RailwayAIService.shared.getTrainId(optimizerId: res.trainId),
                               let train = trainManager.trains.first(where: { $0.id == uuid }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(train.name).font(.headline)
                                        Text("Aggiustamento: \(String(format: "%.1f", res.timeAdjustmentMin)) min")
                                            .font(.caption)
                                    }
                                    Spacer()
                                    if res.timeAdjustmentMin > 0 {
                                        Image(systemName: "clock.badge.exclamationmark")
                                            .foregroundColor(.orange)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        
                        Button("Applica Piani di Viaggio") {
                            for res in resolutions {
                                if let uuid = RailwayAIService.shared.getTrainId(optimizerId: res.trainId) {
                                    trainManager.applyAdvancedResolutions([res], network: network)
                                }
                            }
                            // Force complete refresh
                            trainManager.validateSchedules(with: network)
                            trainManager.objectWillChange.send()
                            
                            resolutions = []
                            optimizerStats = nil
                            aiResult = "Piani di viaggio aggiornati. Conflitti rilevati: \(trainManager.conflictManager.conflicts.count)"
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                
                if !solutions.isEmpty {
                    Section(header: Text("Soluzioni Proposte")) {
                        ForEach(solutions, id: \.trainId) { sol in
                            let train = trainManager.trains.first(where: { $0.id == sol.trainId })
                            VStack(alignment: .leading) {
                                Text(train?.name ?? "Treno Sconosciuto").bold()
                                Text("Nuova Partenza: \(sol.newDepartureTime)")
                                if let adjustments = sol.stopAdjustments {
                                    Text("Soste modificate: \(adjustments.count)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        Button("Applica Modifiche") {
                            trainManager.applyAdvancedResolutions(resolutions, network: network)
                            trainManager.validateSchedules(with: network)
                            resolutions = []
                            aiResult = "Modifiche applicate con successo."
                        }
                        .foregroundColor(.green)
                    }
                }

                if !aiResult.isEmpty {
                    Section(header: Text("Risultato Ultima Operazione")) {
                        Text(aiResult).font(.body).foregroundColor(.blue)
                    }
                }
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Ottimizzazione in corso...")
                        Spacer()
                    }
                }
                
                if let error = errorMessage {
                    Section(header: Text("Errore Riscontrato")) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Railway AI")
        }
    }
    
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
        
        RailwayAIService.shared.optimize(request: request, useV2: false)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Standard Optimizer Error: \(error.localizedDescription)"
                }
            } receiveValue: { response in
                if response.success {
                    self.aiResult = "Analisi completata. \(response.modifications?.count ?? 0) suggerimenti ricevuti."
                    // Handle modifications if applicable (v2 schema)
                } else {
                    errorMessage = response.error_message ?? "L'AI ha riportato un fallimento."
                }
            }
            .store(in: &cancellables)
    }

    private func performOptimizationCall() {
        aiResult = "Ottimizzazione matematica in corso..."
        print("[AI] Starting Advanced Optimization Call...")
        
        RailwayAIService.shared.advancedOptimize(network: network, trains: trainManager.trains)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Optimizer Error: \(error.localizedDescription)"
                    print("[AI] Request Failed: \(error)")
                }
            } receiveValue: { response in
                print("[AI] Received Response. Success: \(response.success)")
                if response.success {
                    self.resolutions = response.resolutions
                    self.optimizerStats = (response.total_delay_minutes, response.conflicts_detected)
                    
                    print("[Optimizer] Received \(response.resolutions.count) resolutions.")
                    print("[Optimizer] API Stats: Conflicts Before: \(response.conflicts_detected), Resolved: \(response.conflicts_resolved)")
                    
                    if response.resolutions.isEmpty {
                        self.aiResult = "Nessuna soluzione trovata dall'AI."
                    } else {
                        self.aiResult = "Ottimizzazione completata! \(response.resolutions.count) modifiche proposte."
                    }
                } else {
                    errorMessage = "L'ottimizzatore ha riportato un fallimento."
                }
            }
            .store(in: &cancellables)
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

#Preview {
    ContentView()
        .environmentObject(RailwayNetwork(name: "Preview"))
        .environmentObject(TrainManager())
        .environmentObject(AppState())
}
