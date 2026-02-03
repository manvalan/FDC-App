import SwiftUI
import UniformTypeIdentifiers

struct IOManagementView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError: String? = nil
    @State private var lastSaveTime: Date? = nil
    @State private var isSaving = false
    
    var body: some View {
        Form {
            Section(header: Text("current_project".localized)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text(network.name.isEmpty ? "unnamed_network".localized : network.name)
                            .font(.headline)
                    }
                    
                    HStack {
                        Label(String(format: "stations_count_label".localized, network.nodes.count), systemImage: "mappin.circle")
                        Spacer()
                        Label(String(format: "tracks_count_label".localized, network.edges.count), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Label(String(format: "lines_count_label".localized, network.lines.count), systemImage: "line.horizontal.3")
                        Spacer()
                        Label(String(format: "trains_count_label".localized, trainManager.trains.count), systemImage: "train.side.front.car")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if let saveTime = lastSaveTime {
                        Text(String(format: "last_save".localized, saveTime.formatted(.relative(presentation: .numeric))))
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("quick_save".localized)) {
                Button(action: saveCurrentState) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("save_current_state".localized)
                                .foregroundColor(.primary)
                            Text("auto_save_local_desc".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .disabled(isSaving)
            }
            
            Section(header: Text("import_export_files".localized)) {
                Button(action: { showExporter = true }) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("export_project".localized)
                                .foregroundColor(.primary)
                            Text("save_rail_file_desc".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: { showImporter = true }) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("import_project".localized)
                                .foregroundColor(.primary)
                            Text("support_formats_desc".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Section(header: Text("legacy_formats".localized), 
                    footer: Text("legacy_formats_footer".localized)) {
                Button(action: { showImporter = true }) {
                    Label("import_fdc_legacy".localized, systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                }
                
                Button(action: { showImporter = true }) {
                    Label("import_railml".localized, systemImage: "doc.text")
                        .foregroundColor(.purple)
                }
            }
            
            if let error = importError {
                Section(header: Text("import_error_title".localized)) {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Button("close".localized) {
                        importError = nil
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("io_management".localized)
        .fileExporter(
            isPresented: $showExporter,
            document: RailwayNetworkDocument(network: network, trains: trainManager.trains),
            contentType: .rail,
            defaultFilename: network.name.isEmpty ? "rete-ferroviaria" : network.name
        ) { result in
            switch result {
            case .success:
                print("export_completed".localized)
            case .failure(let error):
                importError = String(format: "export_error_fmt".localized, error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .fdc, .railml, .rail]
        ) { result in
            handleImport(result: result)
        }
    }
    
    private func saveCurrentState() {
        isSaving = true
        Task {
            await loader.saveCurrentState()
            await MainActor.run {
                lastSaveTime = Date()
                isSaving = false
            }
        }
    }
    
    private func handleImport(result: Result<URL, Error>) {
        do {
            let url = try result.get()
            
            // Store the URL for future reference
            UserDefaults.standard.set(url.absoluteString, forKey: "lastOpenedURL")
            
            // PIGNOLO PROTOCOL: On iOS/iPadOS, we MUST startAccessingSecurityScopedResource for external files
            guard url.startAccessingSecurityScopedResource() else {
                importError = "security_scoped_error".localized
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
            let ext = url.pathExtension.lowercased()
            
            switch ext {
            case "fdc":
                try importFDC(data: data)
            case "railml":
                try importRailML(data: data, filename: url.deletingPathExtension().lastPathComponent)
            default:
                try importJSON(data: data)
            }
            
            importError = nil
            print(String(format: "import_completed_fmt".localized, url.lastPathComponent))
            
        } catch {
            importError = String(format: "import_error_fmt".localized, error.localizedDescription)
        }
    }
    
    private func importFDC(data: Data) throws {
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
    }
    
    private func importRailML(data: Data, filename: String) throws {
        let parser = RailMLParser()
        if let res = parser.parse(data: data) {
            network.name = filename
            network.nodes = res.nodes
            network.edges = res.edges
            network.lines = []
            trainManager.validateSchedules(with: network)
        } else {
            throw NSError(domain: "IOManagement", code: 1, userInfo: [NSLocalizedDescriptionKey: "railml_parsing_failed".localized])
        }
    }
    
    private func importJSON(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 1. Try Container (RAIL)
        if let container = try? decoder.decode(RailFileContainer.self, from: data) {
            network.apply(dto: container.network)
            if let trains = container.network.trains {
                trainManager.trains = trains
            }
            print(String(format: "loaded_rail_file_fmt".localized, container.qualifier))
            trainManager.validateSchedules(with: network)
            return
        }
        
        // 2. Fallback to Simple DTO (JSON)
        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
            network.apply(dto: dto)
            if let trains = dto.trains {
                trainManager.trains = trains
            }
            trainManager.validateSchedules(with: network)
            return
        }
        
        // 3. Try without ISO8601
        let simpleDecoder = JSONDecoder()
        if let dto = try? simpleDecoder.decode(RailwayNetworkDTO.self, from: data) {
            network.apply(dto: dto)
            if let trains = dto.trains {
                trainManager.trains = trains
            }
            trainManager.validateSchedules(with: network)
            return
        }
        
        throw NSError(domain: "IOManagement", code: 2, userInfo: [NSLocalizedDescriptionKey: "decode_error".localized])
    }
}
