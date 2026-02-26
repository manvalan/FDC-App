import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct IOManagementView: View {
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var trainManager: LinesManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    
    @State private var showExporter = false
    @State private var showInfrastructureExporter = false
    @State private var importError: String? = nil
    @State private var stationJsonInput = ""
    @State private var stationImportMessage: String? = nil
    @State private var stationImportIsError = false
    
    @State private var trackJsonInput = ""
    @State private var trackImportMessage: String? = nil
    @State private var trackImportIsError = false
    
    var body: some View {
        VStack(spacing: 16) {
            fileManagementSection
            stationJsonImportSection
            legacySection
            
            if let importError = importError {
                InspectorInfoBanner(
                    type: .error,
                    title: "import_error_title".localized,
                    message: importError
                )
            }
            
        }
        .fileExporter(
            isPresented: $showExporter,
            document: RailwayNetworkDocument(network: network, lines: trainManager.routes, trains: trainManager.trains),
            contentType: .rail,
            defaultFilename: "rete-ferroviaria"
        ) { _ in }
        .fileExporter(
            isPresented: $showInfrastructureExporter,
            document: InfrastructureDocument(nodes: network.nodes, edges: network.edges),
            contentType: .json,
            defaultFilename: "infrastruttura"
        ) { _ in }
        .fileImporter(isPresented: isImporting, allowedContentTypes: [.json, .fdc, .railml, .rail]) { result in
            do {
                let url = try result.get()
                print("🔵 [IO DEBUG] File picker returned URL: \(url.absoluteString)")
                UserDefaults.standard.set(url.absoluteString, forKey: "lastOpenedURL")
                
                guard url.startAccessingSecurityScopedResource() else {
                    print("🔴 [IO DEBUG] Security scoped resource access FAILED")
                    importError = "security_scoped_error".localized
                    return
                }
                print("✅ [IO DEBUG] Security scoped resource access granted")
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                    Task { @MainActor in
                        await loader.saveCurrentState()
                    }
                }
                
                let data = try Data(contentsOf: url)
                let ext = url.pathExtension.lowercased()
                print("🔵 [IO DEBUG] File loaded: \(data.count) bytes, extension: \(ext)")
                
                guard let mode = appState.ioImportMode else {
                    print("🔴 [IO DEBUG] Import mode is nil!")
                    return
                }
                print("🔵 [IO DEBUG] Import mode: \(mode)")
                
                switch mode {
                case .infrastructure:
                    print("🔵 [IO DEBUG] Mode: INFRASTRUCTURE")
                    // Try RailML first if extension matches
                    if ext == "railml" {
                        print("🔵 [IO DEBUG] Trying RailML parser...")
                        let parser = RailMLParser()
                        if let infra = parser.parse(data: data) {
                            print("✅ [IO DEBUG] RailML parsed successfully: \(infra.nodes.count) nodes, \(infra.edges.count) edges")
                            network.nodes = normalizedInfrastructureNodes(infra.nodes)
                            network.edges = infra.edges
                            appState.sidebarSelection = .stations
                            return
                        }
                        print("⚠️ [IO DEBUG] RailML parsing failed")
                    }
                    
                    // Try JSON decodes
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    print("🔵 [IO DEBUG] Trying JSON decode (InfrastructurePayload)...")
                    if let payload = try? decoder.decode(InfrastructurePayload.self, from: data) {
                        print("✅ [IO DEBUG] InfrastructurePayload decoded: \(payload.nodes.count) nodes, \(payload.edges.count) edges")
                        network.nodes = normalizedInfrastructureNodes(payload.nodes)
                        network.edges = payload.edges
                    } else {
                        print("🔵 [IO DEBUG] Trying JSON decode (RailwayNetworkDTO)...")
                        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                            print("✅ [IO DEBUG] RailwayNetworkDTO decoded: \(dto.nodes.count) nodes, \(dto.edges.count) edges")
                            network.nodes = normalizedInfrastructureNodes(dto.nodes)
                            network.edges = dto.edges
                        } else {
                            print("🔵 [IO DEBUG] Trying JSON decode (RailFileContainer)...")
                            if let container = try? decoder.decode(RailFileContainer.self, from: data) {
                                print("✅ [IO DEBUG] RailFileContainer decoded: \(container.network.nodes.count) nodes, \(container.network.edges.count) edges")
                                network.nodes = normalizedInfrastructureNodes(container.network.nodes)
                                network.edges = container.network.edges
                            } else {
                                print("🔴 [IO DEBUG] All JSON decode attempts failed!")
                                throw CocoaError(.fileReadCorruptFile)
                            }
                        }
                    }
                    print("✅ [IO DEBUG] Infrastructure import completed, switching to stations view")
                    appState.sidebarSelection = .stations
                    
                case .project:
                    print("🔵 [IO DEBUG] Mode: PROJECT")
                    // 1. Try Qualified Native Format (.rail) or Container
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    print("🔵 [IO DEBUG] Trying JSON decode (RailFileContainer)...")
                    if let container = try? decoder.decode(RailFileContainer.self, from: data) {
                        print("✅ [IO DEBUG] RailFileContainer decoded successfully")
                        importDTO(container.network)
                        return
                    }
                    
                    // 2. Try Standard DTO
                    print("🔵 [IO DEBUG] Trying JSON decode (RailwayNetworkDTO)...")
                    if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                        print("✅ [IO DEBUG] RailwayNetworkDTO decoded successfully")
                        importDTO(dto)
                        return
                    }
                    
                    // 3. Try RailML Parser if extension matches
                    if ext == "railml" {
                        print("🔵 [IO DEBUG] Trying RailML parser...")
                        let parser = RailMLParser()
                        if let infra = parser.parse(data: data) {
                            print("✅ [IO DEBUG] RailML parsed successfully, converting to DTO")
                            importDTO(RailwayNetworkDTO(name: "RailML Import", nodes: infra.nodes, edges: infra.edges, lines: [], trains: []))
                            return
                        }
                        print("⚠️ [IO DEBUG] RailML parsing failed")
                    }
                    
                    // 4. Try the heavy-duty FDC Parser (handles FDC, Topology, Legacy, Text)
                    print("🔵 [IO DEBUG] Trying FDC parser (last resort)...")
                    do {
                        appState.railroad.createCheckpoint()
                        try appState.railroad.io.importFromFDC(data: data)
                        print("✅ [IO DEBUG] FDC import successful")
                        // Selection and UI refresh happens via RailroadNetwork propagation
                        appState.sidebarSelection = .stations
                        importError = nil
                    } catch {
                        print("🔴 [IO DEBUG] FDC import failed: \(error.localizedDescription)")
                        importError = "decode_error".localized + ": " + error.localizedDescription
                    }
                }
            } catch {
                print("🔴 [IO DEBUG] Import failed with error: \(error.localizedDescription)")
                importError = String(format: "import_error_fmt".localized, error.localizedDescription)
            }
            print("🔵 [IO DEBUG] Resetting import mode")
            appState.ioImportMode = nil
        }
    }

    private var fileManagementSection: some View {
        InspectorSection(title: "file_management".localized, icon: "square.and.arrow.up", iconColor: .blue) {
            actionRow(
                title: "save_project".localized,
                subtitle: nil,
                icon: "square.and.arrow.up",
                iconColor: .accentColor
            ) {
                showExporter = true
            }
            
            actionRow(
                title: "save_infrastructure".localized,
                subtitle: "save_infrastructure_desc".localized,
                icon: "tray.and.arrow.up",
                iconColor: .accentColor
            ) {
                showInfrastructureExporter = true
            }
            
            actionRow(
                title: "import_infrastructure".localized,
                subtitle: "import_infrastructure_desc".localized,
                icon: "tray.and.arrow.down",
                iconColor: .accentColor
            ) {
                print("🔵 [IO DEBUG] 'Import Infrastructure' button clicked")
                appState.ioImportMode = .infrastructure
                print("🔵 [IO DEBUG] appState.ioImportMode set to .infrastructure, isImporting binding should now be true")
            }
            
            actionRow(
                title: "open_project".localized,
                subtitle: "support_format".localized,
                icon: "folder",
                iconColor: .accentColor
            ) {
                print("🔵 [IO DEBUG] 'Open Project' button clicked")
                appState.ioImportMode = .project
                print("🔵 [IO DEBUG] appState.ioImportMode set to .project, isImporting binding should now be true")
            }
            
            actionRow(
                title: "save_local".localized,
                subtitle: "save_local_desc".localized,
                icon: "tray.and.arrow.down",
                iconColor: .green
            ) {
                Task { await loader.saveCurrentState() }
            }
        }
    }

    private var legacySection: some View {
        InspectorSection(title: "legacy_integration".localized, icon: "arrow.triangle.2.circlepath", iconColor: .orange) {
            actionRow(
                title: "import_old".localized,
                subtitle: nil,
                icon: "arrow.triangle.2.circlepath",
                iconColor: .orange
            ) {
                appState.ioImportMode = .project
            }
            
            actionRow(
                title: "export_new".localized,
                subtitle: nil,
                icon: "arrow.up.doc",
                iconColor: .blue
            ) {
                showExporter = true
            }
            
            Text("legacy_footer".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var stationJsonImportSection: some View {
        VStack(spacing: 20) {
            InspectorSection(title: "station_json_import".localized, icon: "plus.square.on.square", iconColor: .purple) {
                Text("station_json_import_desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $stationJsonInput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    
                    if stationJsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("station_json_placeholder".localized)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                }
                
                HStack {
                    Spacer()
                    Button("station_json_add_button".localized) {
                        addStationsFromJson()
                    }
                    .buttonStyle(.borderedProminent)
                }
                

                if let message = stationImportMessage {
                    InspectorInfoBanner(
                        type: stationImportIsError ? .error : .success,
                        title: stationImportIsError ? "import_error_title".localized : nil,
                        message: message
                    )
                }
            }
            
            InspectorSection(title: "track_json_import".localized, icon: "point.topleft.down.curvedto.point.bottomright.up", iconColor: .orange) {
                Text("track_json_import_desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $trackJsonInput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    
                    if trackJsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("track_json_placeholder".localized)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                }
                
                HStack {
                    Spacer()
                    Button("track_json_add_button".localized) {
                        addTracksFromJson()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if let message = trackImportMessage {
                    InspectorInfoBanner(
                        type: trackImportIsError ? .error : .success,
                        title: trackImportIsError ? "import_error_title".localized : nil,
                        message: message
                    )
                }
            }
        }
    }

    private func actionRow(
        title: String,
        subtitle: String?,
        icon: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func importDTO(_ dto: RailwayNetworkDTO) {
        let currentNetwork = self.network
        appState.railroad.createCheckpoint()
        
        currentNetwork.nodes = normalizedInfrastructureNodes(dto.nodes)
        currentNetwork.edges = dto.edges
        currentNetwork.lines = dto.lines ?? []
        
        if let l = dto.routes { trainManager.routes = l }
        if let t = dto.trains { trainManager.trains = t }
        if let v = dto.vehicles { trainManager.vehicles = v }
        
        trainManager.validateSchedules()
        appState.simulator.schedules = trainManager.generateSchedulesPreview()
        
        appState.sidebarSelection = .stations
        importError = nil
    }
    
    private var isImporting: Binding<Bool> {
        Binding(
            get: {
                let isPresenting = appState.ioImportMode != nil
                print("🔵 [IO DEBUG] isImporting getter called, returning: \(isPresenting)")
                return isPresenting
            },
            set: { isPresented in
                print("🔵 [IO DEBUG] isImporting setter called with: \(isPresented)")
                // IMPORTANT: Don't reset ioImportMode here!
                // SwiftUI calls this setter multiple times during presentation/dismissal
                // We only reset ioImportMode after file selection completes (in fileImporter callback)
                if !isPresented {
                    print("⚠️ [IO DEBUG] isImporting setter wants to dismiss, but NOT resetting ioImportMode (would lose state!)")
                }
            }
        )
    }
    
    private func normalizedInfrastructureNodes(_ nodes: [RailwayNode]) -> [RailwayNode] {
        nodes.map { node in
            var updated = node
            let trimmedName = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if name is empty or has pattern "N-\d+" (e.g. "N-123")
            let hasInvalidPattern = trimmedName.isEmpty || trimmedName.range(of: "^N-\\d+$", options: .regularExpression) != nil
            
            if hasInvalidPattern {
                // Generate a descriptive name based on node type
                switch updated.type {
                case .station:
                    updated.name = "Stazione \(updated.id.prefix(6))"
                case .interchange:
                    updated.name = "Scambio \(updated.id.prefix(6))"
                case .junction:
                    updated.name = "Junction \(updated.id.prefix(6))"
                case .depot:
                    updated.name = "Deposito \(updated.id.prefix(6))"
                }
                print("⚠️ [IO DEBUG] Fixed invalid node name from '\(trimmedName)' to '\(updated.name)'")
            }
            
            if updated.platforms == nil || (updated.platforms ?? 0) <= 0 {
                updated.platforms = 2
            }
            if updated.visualType == nil {
                updated.visualType = updated.defaultVisualType
            }
            if updated.customColor == nil {
                updated.customColor = updated.defaultColor
            }
            return updated
        }
    }
    
    private func addStationsFromJson() {
        let trimmed = stationJsonInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            stationImportIsError = true
            stationImportMessage = "station_json_empty".localized
            return
        }
        
        do {
            let sanitized = sanitizeJsonSnippet(trimmed)
            let data = Data(sanitized.utf8)
            let decoder = JSONDecoder()
            
            // Try single object first
            if let singleSnippet = try? decoder.decode(StationSnippet.self, from: data) {
                processStationSnippets([singleSnippet])
                return
            }
            
            // Try array
            let snippets = try decoder.decode([StationSnippet].self, from: data)
            processStationSnippets(snippets)
            
        } catch {
            stationImportIsError = true
            stationImportMessage = String(
                format: "station_json_error_fmt".localized,
                error.localizedDescription
            )
        }
    }
    
    private func processStationSnippets(_ snippets: [StationSnippet]) {
        let fallbackCoordinate = lastValidCoordinate()
        var existingIds = Set(network.nodes.map { $0.id })
        var added = 0
        var skipped = 0
        
        for snippet in snippets {
            let id = snippet.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if id.isEmpty {
                skipped += 1
                continue
            }
            if existingIds.contains(id) {
                skipped += 1
                continue
            }
            
            let name = snippet.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let coordinate = normalizedCoordinate(
                latitude: snippet.latitude,
                longitude: snippet.longitude,
                fallback: fallbackCoordinate,
                offsetIndex: added
            )
            let node = RailwayNode(
                id: id,
                name: (name?.isEmpty == false ? name! : id),
                type: mapNodeType(snippet.type),
                visualType: nil,
                customColor: nil,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                capacity: nil,
                platforms: 2
            )
            network.nodes.append(node)
            existingIds.insert(id)
            added += 1
        }
        
        stationImportIsError = false
        stationImportMessage = String(
            format: "station_json_result_fmt".localized,
            added,
            skipped
        )
    }
    
    private func addTracksFromJson() {
        let trimmed = trackJsonInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            trackImportIsError = true
            trackImportMessage = "track_json_empty".localized
            return
        }
        
        do {
            let sanitized = sanitizeJsonSnippet(trimmed)
            let data = Data(sanitized.utf8)
            let decoder = JSONDecoder()
            
            // Try single object first
            if let singleSnippet = try? decoder.decode(TrackSnippet.self, from: data) {
                processTrackSnippets([singleSnippet])
                return
            }
            
            // Try array
            let snippets = try decoder.decode([TrackSnippet].self, from: data)
            processTrackSnippets(snippets)
            
        } catch {
            trackImportIsError = true
            trackImportMessage = String(
                format: "track_json_error_fmt".localized,
                error.localizedDescription
            )
        }
    }
    
    private func processTrackSnippets(_ snippets: [TrackSnippet]) {
        var added = 0
        var failed = 0
        
        for snippet in snippets {
            let fromId = snippet.from.trimmingCharacters(in: .whitespacesAndNewlines)
            let toId = snippet.to.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !fromId.isEmpty, !toId.isEmpty else {
                failed += 1
                continue
            }
            
            // Check if stations exist
            guard network.nodes.contains(where: { $0.id == fromId }),
                  network.nodes.contains(where: { $0.id == toId }) else {
                failed += 1 // One or both stations missing
                continue
            }
            
            let dist = snippet.distance > 0 ? snippet.distance : 10.0
            let speed = snippet.maxSpeed > 0 ? snippet.maxSpeed : Int(appState.regionalTrackMaxSpeed)
            let type = mapTrackType(snippet.type)
            
            let edge = RailwayEdge(
                from: fromId,
                to: toId,
                distance: dist,
                trackType: type,
                maxSpeed: speed,
                capacity: 10
            )
            network.edges.append(edge)
            added += 1
        }
        
        trackImportIsError = false
        trackImportMessage = String(
            format: "track_json_result_fmt".localized,
            added,
            failed
        )
    }
    
    private func mapTrackType(_ rawType: String?) -> Edge.TrackType {
        switch rawType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "highspeed", "av": return .highSpeed
        case "double", "doppio": return .double
        case "single", "singolo": return .single
        default: return .regional
        }
    }
    
    private func mapNodeType(_ rawType: String?) -> Node.NodeType {
        switch rawType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "interchange":
            return .interchange
        case "depot", "industrial", "port":
            return .depot
        case "junction", "bridge", "technical":
            return .junction
        case "terminus", "station", nil, "":
            return .station
        default:
            return .station
        }
    }
    
    private func sanitizeJsonSnippet(_ input: String) -> String {
        var output = input
        
        if let blockRegex = try? NSRegularExpression(pattern: "/\\*.*?\\*/", options: [.dotMatchesLineSeparators]) {
            output = blockRegex.stringByReplacingMatches(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count), withTemplate: "")
        }
        
        if let lineRegex = try? NSRegularExpression(pattern: "(?m)//.*$", options: []) {
            output = lineRegex.stringByReplacingMatches(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count), withTemplate: "")
        }
        
        // Remove trailing commas before closing braces/brackets
        if let trailingCommaRegex = try? NSRegularExpression(pattern: ",\\s*([}\\]])", options: []) {
            output = trailingCommaRegex.stringByReplacingMatches(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count), withTemplate: "$1")
        }
        
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        output = output.trimmingCharacters(in: CharacterSet(charactersIn: ","))
        
        // Handle single objects by wrapping NOT needed here if we try-catch both
        // But for UI safety:
        if !output.hasPrefix("[") && !output.hasPrefix("{") {
             // Assume partial? No, if it's "{" it's valid single object
             // If it is just fields... hard to guess. Assume valid JSON object or array.
        }
        
        if !output.hasPrefix("[") && !output.hasPrefix("{") {
             // It might be a list of objects without []? e.g. {...}, {...}
             // For now assume the user pastes valid JSON or array body
             // If it starts with { it is single
             // If it starts with [ it is array
        }
        
        if !output.hasPrefix("[") && output.hasPrefix("{") == false {
             // Try wrapping in [] just in case it is multiple objects comma separated?
             output = "[\(output)]"
        }
        
        return output
    }
    
    private func lastValidCoordinate() -> CLLocationCoordinate2D? {
        for node in network.nodes.reversed() {
            if let lat = node.latitude, let lon = node.longitude,
               lat.isFinite, lon.isFinite {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return nil
    }
    
    private func normalizedCoordinate(
        latitude: Double?,
        longitude: Double?,
        fallback: CLLocationCoordinate2D?,
        offsetIndex: Int
    ) -> CLLocationCoordinate2D? {
        if let lat = latitude, let lon = longitude, lat.isFinite, lon.isFinite {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        guard let fallback = fallback else { return nil }
        let offsetStep = 0.02
        let row = offsetIndex / 5
        let col = offsetIndex % 5
        let lat = fallback.latitude + (Double(row) * offsetStep)
        let lon = fallback.longitude + (Double(col) * offsetStep)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Document Support
struct RailwayNetworkDocument: @preconcurrency FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.fdc, UTType.railml, UTType.rail] }
    var dto: RailwayNetworkDTO
    
    @MainActor
    init(network: NetworkModel, lines: [TrainRoute], trains: [RailwayTrain]) { 
        self.dto = RailwayNetworkDTO(name: network.name, nodes: network.nodes, edges: network.edges, lines: network.lines, routes: lines, trains: trains)
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

struct InfrastructureDocument: @preconcurrency FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json] }
    private var nodes: [RailwayNode]
    private var edges: [RailwayEdge]

    init(nodes: [RailwayNode], edges: [RailwayEdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.regularFileContents != nil else { throw CocoaError(.fileReadCorruptFile) }
        self.nodes = []
        self.edges = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        struct Payload: Encodable {
            let nodes: [Node]
            let edges: [Edge]
        }
        let payload = Payload(nodes: nodes, edges: edges)
        let data = try encoder.encode(payload)
        return .init(regularFileWithContents: data)
    }
}

private struct InfrastructurePayload: Codable {
    let nodes: [RailwayNode]
    let edges: [RailwayEdge]
}

private struct StationSnippet: Decodable {
    let id: String
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let type: String?
}

private struct TrackSnippet: Decodable {
    let from: String
    let to: String
    let distance: Double
    let maxSpeed: Int
    let type: String?
}
