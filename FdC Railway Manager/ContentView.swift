import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

// MARK: - ContentView Unified UI
struct ContentView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @EnvironmentObject var appState: AppState
    
    // Navigation State
    @State private var sidebarSelection: SidebarItem? = .lines
    @State private var selectedLine: RailwayLine? = nil
    @State private var selectedNode: Node? = nil
    @State private var selectedEdgeId: String? = nil // New state for edge selection
    @State private var selectedTrain: Train? = nil
    @State private var inspectorVisible: Bool = false
    
    // Global Settings State (lifted for easy access)
    @State private var showGrid: Bool = false
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case network = "Rete"
        case lines = "Linee"
        case trains = "Treni"
        case ai = "Railway AI"
        case settings = "Impostazioni"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .network: return "map"
            case .lines: return "point.bottomleft.forward.to.point.topright.scurvedpath"
            case .trains: return "train.side.front.car"
            case .ai: return "sparkles"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $sidebarSelection) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
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
                    TrainsListView()
                case .ai:
                    RailwayAIView(network: network)
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
                mode: (sidebarSelection == .lines || sidebarSelection == .trains) ? .lines : .network
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
                inspectorVisible = true 
            } 
        }
        .onChange(of: selectedNode) { newVal in 
            if newVal != nil { 
                selectedLine = nil
                selectedEdgeId = nil
                inspectorVisible = true 
            } 
        }
        .onChange(of: selectedEdgeId) { newVal in 
            if newVal != nil { 
                selectedLine = nil
                selectedNode = nil
                inspectorVisible = true 
            } 
        }
    }
    
    private func releaseOthers() {} // Deprecated by specific handlers

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
        List(selection: $selectedLine) {
            ForEach(network.lines) { line in
                HStack {
                    if let color = line.color {
                        Circle().fill(Color(hex: color) ?? .black).frame(width: 10, height: 10)
                    }
                    Text(line.name)
                    Spacer()
                }
                .tag(line)
            }
            .onDelete { idx in
                network.lines.remove(atOffsets: idx)
                if selectedLine == nil { } // Handle selection invalidation
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
    @State private var showAdd = false
    
    var body: some View {
        List {
            ForEach(manager.trains) { train in
                VStack(alignment: .leading) {
                    Text(train.name).font(.headline)
                    Text(train.type).font(.caption)
                }
            }
            .onDelete { manager.trains.remove(atOffsets: $0) }
        }
        .navigationTitle("Treni")
        .toolbar {
            Button(action: { showAdd = true }) { Image(systemName: "plus") }
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



 
}

// ... (Subviews)

// MARK: - Document Support
struct RailwayNetworkDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.fdc, UTType.railml] }
    var dto: RailwayNetworkDTO
    @MainActor
    init(network: RailwayNetwork) { self.dto = network.toDTO() }
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        if configuration.contentType == .fdc {
            let parsed = try FDCParser.parse(data: data)
            let nodes = parsed.stations.map { fdc in
                Node(id: fdc.id, name: fdc.name, type: .station, latitude: fdc.latitude, longitude: fdc.longitude, capacity: fdc.capacity, platforms: fdc.platformCount ?? 2)
            }
            let edges = parsed.edges.map { fdc in
                Edge(from: fdc.from, to: fdc.to, distance: fdc.distance ?? 1.0, trackType: .regional, maxSpeed: Int(fdc.maxSpeed ?? 120), capacity: fdc.capacity)
            }
            self.dto = RailwayNetworkDTO(name: parsed.name, nodes: nodes, edges: edges, lines: parsed.lines)
            return
        }
        if configuration.contentType == .railml {
            let parser = RailMLParser()
            if let parsed = parser.parse(data: data) {
                self.dto = RailwayNetworkDTO(name: "Imported RailML", nodes: parsed.nodes, edges: parsed.edges, lines: [])
                return
            }
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
            self.dto = dto
            return
        }
        throw CocoaError(.fileReadCorruptFile)
    }
    @MainActor
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(dto)
        return .init(regularFileWithContents: data)
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @Binding var showGrid: Bool // Added binding
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Visualizzazione")) {
                    Toggle("Mostra Griglia", isOn: $showGrid)
                }
                
                Section(header: Text("Salvataggio/Caricamento")) {
                    Button("Salva rete su file") { showExporter = true }
                    Button("Carica rete da file") { showImporter = true }
                }
                if let importError = importError { Section { Text(importError).foregroundColor(.red) } }
            }
            .navigationTitle("Impostazioni")
            .fileExporter(isPresented: $showExporter, document: RailwayNetworkDocument(network: network), contentType: .json, defaultFilename: "rete-ferroviaria") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .fdc, .railml]) { result in
                do {
                    let url = try result.get()
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
                            Train(id: UUID(), name: fdc.name, type: fdc.type ?? "Regionale", maxSpeed: fdc.maxSpeed ?? 120, priority: fdc.priority ?? 5, acceleration: fdc.acceleration ?? 0.5, deceleration: fdc.deceleration ?? 0.5)
                        }
                        if !newTrains.isEmpty { trainManager.trains = newTrains }
                        network.name = parsed.name
                        network.nodes = nodes
                        network.edges = edges
                        network.lines = parsed.lines
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
                    } else {
                        let decoder = JSONDecoder()
                        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                            network.apply(dto: dto)
                        } else {
                            importError = "Formato file non supportato o corrotto"
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
    @ObservedObject var network: RailwayNetwork
    @State private var aiResult: String = ""
    @State private var isLoading = false
    @State private var userPrompt: String = ""
    @State private var errorMessage: String? = nil
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Chiedi all'AI")) {
                    TextField("Domanda sulla rete ferroviaria...", text: $userPrompt)
                    Button("Invia") {
                        isLoading = true
                        aiResult = "Analisi in corso..."
                        errorMessage = nil
                        sendToRailwayAI(prompt: userPrompt, network: network) { result in
                            DispatchQueue.main.async {
                                isLoading = false
                                switch result {
                                case .success(let response):
                                    aiResult = response
                                case .failure(let error):
                                    aiResult = ""
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }.disabled(userPrompt.isEmpty || isLoading)
                }
                if isLoading { ProgressView() }
                if let errorMessage = errorMessage { Section { Text(errorMessage).foregroundColor(.red) } }
                if !aiResult.isEmpty {
                    Section(header: Text("Risposta AI")) {
                        Text(aiResult).font(.body).foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Railway AI")
        }
    }
}

@MainActor
func sendToRailwayAI(prompt: String, network: RailwayNetwork, completion: @escaping (Result<String, Error>) -> Void) {
    guard let url = URL(string: "http://82.165.138.64:8080/") else { completion(.failure(NSError(domain: "URL non valida", code: 0))); return }
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
        guard let data = data else { completion(.failure(NSError(domain: "Nessun dato ricevuto", code: 0))); return }
        do {
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], let resp = obj["response"] as? String {
                completion(.success(resp))
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
