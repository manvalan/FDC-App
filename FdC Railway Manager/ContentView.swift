import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

// MARK: - ContentView stile iPad/iPhone
struct ContentView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NetworkView(network: network)
                .tabItem {
                    Label("Rete", systemImage: "map")
                }.tag(0)
            PathFinderView(network: network)
                .tabItem {
                    Label("Percorsi", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }.tag(1)
            TrainsView()
                .tabItem {
                    Label("Treni", systemImage: "train.side.front.car")
                }.tag(2)
            SettingsView()
                .environmentObject(network)
                .tabItem {
                    Label("Impostazioni", systemImage: "gear")
                }.tag(3)
            SchedulerView(network: network)
                .tabItem {
                    Label("Scheduler", systemImage: "calendar")
                }.tag(5)
            RailwayAISchedulerView(network: network)
                .tabItem {
                    Label("RailwayAI", systemImage: "sparkles")
                }.tag(6)
        }
    }
}

// MARK: - NetworkView
struct NetworkView: View {
    @ObservedObject var network: RailwayNetwork
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Stazioni")) {
                    ForEach(network.nodes) { node in
                        VStack(alignment: .leading) {
                            Text(node.name).font(.headline)
                            Text(node.id).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Section(header: Text("Binari")) {
                    ForEach(network.edges) { edge in
                        VStack(alignment: .leading) {
                            Text("\(edge.from) → \(edge.to)")
                            Text("Tipo: \(edge.trackType.rawValue), Velocità max: \(edge.maxSpeed) km/h").font(.caption)
                        }
                    }
                }
                if !network.lines.isEmpty {
                    Section(header: Text("Linee")) {
                        ForEach(network.lines) { line in
                            VStack(alignment: .leading) {
                                HStack {
                                    if let color = line.color {
                                        Circle().fill(Color(hex: color) ?? .gray).frame(width: 10, height: 10)
                                    }
                                    Text(line.name).font(.headline)
                                }
                                Text("\(line.stations.count) stazioni").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rete Ferroviaria")
        }
    }
}

// MARK: - PathFinderView
struct PathFinderView: View {
    @ObservedObject var network: RailwayNetwork
    @State private var from: String = ""
    @State private var to: String = ""
    @State private var result: ([String], Double)? = nil
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Seleziona stazioni")) {
                    Picker("Da", selection: $from) {
                        ForEach(network.nodes.map { $0.id }, id: \ .self) { id in
                            Text(id)
                        }
                    }
                    Picker("A", selection: $to) {
                        ForEach(network.nodes.map { $0.id }, id: \ .self) { id in
                            Text(id)
                        }
                    }
                    Button("Calcola percorso") {
                        result = network.findShortestPath(from: from, to: to)
                    }.disabled(from.isEmpty || to.isEmpty || from == to)
                }
                if let result = result {
                    Section(header: Text("Percorso")) {
                        Text(result.0.joined(separator: " → "))
                        Text("Distanza: \(String(format: "%.1f", result.1)) km")
                    }
                }
            }
            .navigationTitle("Percorsi")
        }
    }
}

// MARK: - TrainsView
// Using Train and TrainManager from TrainManager.swift

struct TrainsView: View {
    @EnvironmentObject var manager: TrainManager
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newType = "Regionale"
    @State private var newMaxSpeed = 120
    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.trains) { train in
                    VStack(alignment: .leading) {
                        Text(train.name).font(.headline)
                        Text("Tipo: \(train.type), Velocità max: \(train.maxSpeed) km/h").font(.caption)
                    }
                }
                .onDelete { manager.trains.remove(atOffsets: $0) }
            }
            .navigationTitle("Treni e Orari")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Label("Aggiungi treno", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                NavigationStack {
                    Form {
                        TextField("Nome treno", text: $newName)
                        TextField("Tipo", text: $newType)
                        TextField("Velocità max (km/h)", value: $newMaxSpeed, format: .number)
                    }
                    .navigationTitle("Nuovo Treno")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annulla") { showAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Aggiungi") {
                                guard !newName.isEmpty else { return }
                                 manager.trains.append(Train(id: UUID(), name: newName, type: newType, maxSpeed: newMaxSpeed, priority: 5, acceleration: 0.5, deceleration: 0.5))
                                newName = ""
                                newType = "Regionale"
                                newMaxSpeed = 120
                                showAdd = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - RailwayNetworkDocument
struct RailwayNetworkDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.fdc] }
    var dto: RailwayNetworkDTO
    init(network: RailwayNetwork) { self.dto = network.toDTO() }
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        // If .fdc, parse text with FDCParser
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
        let decoder = JSONDecoder()
        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
            self.dto = dto
            return
        }
        let legacy = try decoder.decode(RailwayNetwork.self, from: data)
        self.dto = legacy.toDTO()
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
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError: String? = nil
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Salvataggio/Caricamento")) {
                    Button("Salva rete su file") { showExporter = true }
                    Button("Carica rete da file") { showImporter = true }
                }
                if let importError = importError { Section { Text(importError).foregroundColor(.red) } }
            }
            .navigationTitle("Impostazioni")
            .fileExporter(isPresented: $showExporter, document: RailwayNetworkDocument(network: network), contentType: .json, defaultFilename: "rete-ferroviaria") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .fdc]) { result in
                do {
                    let url = try result.get()
                    let data = try Data(contentsOf: url)
                    if url.pathExtension.lowercased() == "fdc" {
                        let parsed = try FDCParser.parse(data: data)
                        let nodes = parsed.stations.map { fdc in
                            Node(id: fdc.id, name: fdc.name, type: .station, latitude: fdc.latitude, longitude: fdc.longitude, capacity: fdc.capacity, platforms: fdc.platformCount ?? 2)
                        }
                        let edges = parsed.edges.map { fdc in
                            Edge(from: fdc.from, to: fdc.to, distance: fdc.distance ?? 1.0, trackType: .regional, maxSpeed: Int(fdc.maxSpeed ?? 120), capacity: fdc.capacity)
                        }
                        network.name = parsed.name
                        network.nodes = nodes
                        network.edges = edges
                        network.lines = parsed.lines
                    } else {
                        let decoder = JSONDecoder()
                        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                            network.apply(dto: dto)
                        } else {
                            let legacy = try decoder.decode(RailwayNetwork.self, from: data)
                            network.name = legacy.name; network.nodes = legacy.nodes; network.edges = legacy.edges
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
                if isLoading {
                    ProgressView()
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
                if !aiResult.isEmpty {
                    Section(header: Text("Risposta AI")) {
                        Text(aiResult)
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Railway AI")
        }
    }
}

// Funzione per chiamare la RailwayAI custom (invocata solo dove serve)
@MainActor
func sendToRailwayAI(prompt: String, network: RailwayNetwork, completion: @escaping (Result<String, Error>) -> Void) {
    guard let url = URL(string: "http://82.165.138.64:8080/") else { completion(.failure(NSError(domain: "URL non valida", code: 0))); return }
    struct Payload: Codable { let prompt: String; let network: RailwayNetworkDTO }
    let payload = Payload(prompt: prompt, network: network.toDTO())
    guard let data = try? JSONEncoder().encode(payload) else { completion(.failure(NSError(domain: "Serializzazione JSON fallita", code: 0))); return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsImV4cCI6MTc2ODkzOTkxN30.a4MzrT4Xlig1DvEbzp2r-H9sAcIu5SD9-i2IRz8DXg4", forHTTPHeaderField: "Authorization")
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
