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
            case .io: return "doc.badge.arrow.up"
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
        .environmentObject(network) // Ensure network is available for Hub Picker
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
        .onChange(of: network.lines) { _ in
            trainManager.validateSchedules(with: network)
        }
        .onChange(of: trainManager.trains) { _ in
            trainManager.validateSchedules(with: network)
            appState.simulator.schedules = trainManager.generateSchedules(with: network)
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
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState
    
    @State private var scheduleLine: RailwayLine? = nil
    @State private var customTrainLine: RailwayLine? = nil
    @State private var showScheduleForLine: RailwayLine? = nil
    @Binding var selectedTrains: Set<UUID>
    @State private var showAddTrain = false
    
    // AI State
    @State private var suggestingForLine: RailwayLine? = nil
    @State private var aiSuggestion: String? = nil
    @State private var isAiLoading = false
    
    var body: some View {
        List {
            ForEach(network.lines) { line in
                Section(header: LineHeader(
                    line: line,
                    onAddTrain: { customTrainLine = line },
                    onAddTrainCadenced: { scheduleLine = line },
                    onShowSchedule: { showScheduleForLine = line }
                )) {
                    let lineTrains = manager.trains.filter { $0.lineId == line.id }
                    
                    if lineTrains.isEmpty {
                        Text("Nessun treno assegnato a questa linea.").font(.caption).foregroundColor(.secondary)
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
            
            Section("Treni Non Assegnati") {
                let unassigned = manager.trains.filter { $0.lineId == nil }
                ForEach(unassigned) { train in
                    Button(action: {
                        selectedTrains = [train.id]
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
        .sheet(item: $scheduleLine) { line in
            ScheduleCreationView(line: line)
        }
        .sheet(item: $customTrainLine) { line in
            TrainCreationView(line: line)
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
    
    private func suggestFrequency(for line: RailwayLine) {
        let stopNames = line.stops.compactMap { s in 
            if let name = network.nodes.first(where: { $0.id == s.stationId })?.name {
                return s.isSkipped ? "\(name) (Transito)" : name
            }
            return nil
        }.joined(separator: ", ")

        let prompt = """
        Sto pianificando l'orario ferroviario per la linea "\(line.name)".
        Fermate (\(line.stops.count)): \(stopNames).
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
             
             Section("Tempi di Sosta e Binari") {
                 ForEach($line.stops) { $stop in
                     HStack {
                         Text(stopName(stop.stationId))
                             .font(.caption)
                             .frame(width: 100, alignment: .leading)
                         
                         TextField("Binario", text: Binding(
                             get: { stop.track ?? "" },
                             set: { stop.track = $0.isEmpty ? nil : $0 }
                         ))
                         .textFieldStyle(.roundedBorder)
                         .frame(width: 60)
                         
                         Stepper("\(stop.minDwellTime)m", value: $stop.minDwellTime, in: 0...120)
                             .font(.caption)
                     }
                 }
             }
         }
         .navigationTitle("Modifica Linea")
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
        isTestLoading = true
        testResultMessage = "Generazione API Key..."
        testErrorMessage = nil
        
        // 1. Use AuthenticationManager to generate the key
        AuthenticationManager.shared.generatePermanentKey { result in
            DispatchQueue.main.async {
                self.isTestLoading = false
                
                switch result {
                case .success(let key):
                    self.appState.aiApiKey = key
                    self.testResultMessage = "API Key Generata e Salvata!"
                    
                    // Sync immediately
                    RailwayAIService.shared.syncCredentials(
                        endpoint: self.appState.aiEndpoint,
                        apiKey: key,
                        token: self.appState.aiToken
                    )
                    
                case .failure(let error):
                    self.testErrorMessage = "Errore Generazione Key: \(error.localizedDescription)"
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Visualizzazione")) {
                    Toggle("Mostra Griglia", isOn: $showGrid)
                }

                Section(header: Text("Intelligenza Artificiale")) {
                    HStack {
                        TextField("Server API Base URL", text: $appState.aiEndpoint)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            appState.aiEndpoint = "http://railway-ai.michelebigi.it:8080"
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Ripristina URL di default")
                    }
                    
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

                Section(header: Text("Diagnostica")) {
                    Button(action: { showLogs = true }) {
                        Label("Mostra Log di Rete", systemImage: "list.bullet.rectangle.portrait")
                    }
                }
                
                Section(header: Text("Informazioni")) {
                    Button(action: { showCredits = true }) {
                        Label("Credits e Autore", systemImage: "info.circle")
                    }
                }
                
                Section("Debug Dati (JSON)") {
                    Button(action: {
                        showJsonInspector(for: network.lines, title: "Linee (\(network.lines.count))")
                    }) {
                        Label("Mostra JSON Linee", systemImage: "curlybraces")
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
                Section("Gestione File") {
                    Button(action: { showExporter = true }) {
                        Label {
                            Text("Salva Progetto")
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Button(action: { showImporter = true }) {
                        Label {
                            Text("Apri Progetto")
                            Text("Supporta .rail, .fdc, .json")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                Section(header: Text("Integrazione Legacy"), footer: Text("Importa file creati con versioni precedenti (FDC 1.x) per convertirli automaticamente al nuovo protocollo Pignolo.")) {
                    Button(action: { showImporter = true }) {
                        Label("Importa Vecchio FDC (.fdc)", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: { showExporter = true }) {
                        Label("Esporta Pignolo V2 (.rail)", systemImage: "arrow.up.doc")
                            .foregroundColor(.blue)
                    }
                }
                
                if let importError = importError {
                    Section {
                        Text(importError).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("I/O Dati")
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
                Section(header: Text("Ottimizzatore FDC (v1/v2)")) {
                    Button(action: runStandardOptimization) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Risolvi Conflitti (FDC JSON)")
                        }
                    }
                    .disabled(isLoading || trainManager.trains.isEmpty)
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

                Section(header: Text("Assistente Pianificazione (Fast Proposer)")) {
                    Stepper("Target Linee: \(targetLines)", value: $targetLines, in: 1...20)
                    
                    Button(action: runFastProposer) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Genera Proposta Orario")
                        }
                    }
                    .disabled(isLoading || network.nodes.count < 2)
                    
                    if !proposedLines.isEmpty {
                        Button("Rivedi Proposte (\(proposedLines.count) linee)") {
                            showLineProposalSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }

                // Unified V2 resolutions are shown below
                
                if !resolutions.isEmpty {
                    Section(header: Text("Soluzioni Ottimizzate")) {
                        ForEach(resolutions, id: \.train_id) { res in
                            if let uuid = RailwayAIService.shared.getTrainUUID(optimizerId: res.train_id),
                               let train = trainManager.trains.first(where: { $0.id == uuid }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(train.name).font(.headline)
                                    HStack {
                                        let sign = res.time_adjustment_min > 0 ? "+" : ""
                                        Text("Partenza: \(sign)\(String(format: "%.1f", res.time_adjustment_min)) min")
                                        
                                        if let dwells = res.dwell_delays, !dwells.isEmpty {
                                            Divider().frame(height: 10)
                                            Text("\(dwells.count) soste allungate")
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
                            aiResult = "Piani di viaggio aggiornati correttamente."
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Applica Cambio Orario")
                            }
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
                            trainManager.applyAISuggestions(solutions)
                            trainManager.validateSchedules(with: network)
                            solutions = []
                            aiResult = "Modifiche applicate con successo."
                        }
                        .foregroundColor(.green)
                    }
                }

                if !aiResult.isEmpty {
                    Section(header: Text("Risultato Ultima Operazione")) {
                        Text(aiResult).font(.body).foregroundColor(.blue)
                        
                        Button(action: { showJSONInspector = true }) {
                            Label("Ispezione JSON Richiesta", systemImage: "doc.text.magnifyingglass")
                        }
                        .font(.caption)
                        .padding(.top, 4)
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
            .sheet(isPresented: $showJSONInspector) {
                NavigationStack {
                    VStack {
                        Text("Questo è il pacchetto dati inviato all'IA. Utile per il debug dei '0 suggerimenti'.")
                            .font(.caption)
                            .padding()
                        
                        TextEditor(text: .constant(RailwayAIService.shared.lastRequestJSON))
                            .font(.system(.caption, design: .monospaced))
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding()
                    }
                    .navigationTitle("Dettaglio JSON")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Chiudi") { showJSONInspector = false }
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
            .navigationTitle("Log Diagnostica")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Cancella") { logger.logs.removeAll() }
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
