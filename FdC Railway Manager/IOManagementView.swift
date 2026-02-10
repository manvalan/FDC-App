import SwiftUI
import UniformTypeIdentifiers

struct IOManagementView: View {
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var trainManager: LinesManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    
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
            .fileExporter(isPresented: $showExporter, document: RailwayNetworkDocument(network: network, lines: trainManager.lines, trains: trainManager.trains), contentType: .rail, defaultFilename: "rete-ferroviaria") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .fdc, .railml, .rail]) { result in
                do {
                    let url = try result.get()
                    
                    UserDefaults.standard.set(url.absoluteString, forKey: "lastOpenedURL")
                    
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Impossibile ottenere l'accesso al file (Security Scoped Resource)"
                        return
                    }
                    
                    defer { 
                        url.stopAccessingSecurityScopedResource()
                        Task {
                            await loader.saveCurrentState()
                        }
                    }
                    
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    if let container = try? decoder.decode(RailFileContainer.self, from: data) {
                         importDTO(container.network)
                    } else if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                         importDTO(dto)
                    } else {
                         importError = "Formato file non supportato o corrotto."
                    }
                } catch {
                    importError = "Errore durante l'apertura: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func importDTO(_ dto: RailwayNetworkDTO) {
        network.nodes = dto.nodes
        network.edges = dto.edges
        if let l = dto.lines { trainManager.lines = l }
        if let t = dto.trains { trainManager.trains = t }
        
        trainManager.validateSchedules()
        appState.simulator.schedules = trainManager.generateSchedulesPreview()
        
        // Clear selection to avoid crashes with old IDs
        appState.sidebarSelection = .network
    }
}

// MARK: - Document Support
struct RailwayNetworkDocument: @preconcurrency FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.fdc, UTType.railml, UTType.rail] }
    var dto: RailwayNetworkDTO
    
    @MainActor
    init(network: NetworkModel, lines: [RailwayLine], trains: [Train]) { 
        self.dto = RailwayNetworkDTO(name: network.name, nodes: network.nodes, edges: network.edges, lines: lines, trains: trains)
    }
    
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        let decoder = JSONDecoder()
        
        if let container = try? decoder.decode(RailFileContainer.self, from: data) {
            self.dto = container.network
            return
        }
        
        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
            self.dto = dto
            return
        }
        
        throw CocoaError(.fileReadCorruptFile)
    }
    
    @MainActor
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
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
            let data = try encoder.encode(dto)
            return .init(regularFileWithContents: data)
        }
    }
}
