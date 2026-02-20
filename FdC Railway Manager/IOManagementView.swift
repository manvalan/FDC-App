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
    @State private var importMode: ImportMode? = nil
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
            document: RailwayNetworkDocument(network: network, lines: trainManager.lines, trains: trainManager.trains),
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
                
                UserDefaults.standard.set(url.absoluteString, forKey: "lastOpenedURL")
                
                guard url.startAccessingSecurityScopedResource() else {
                    importError = "security_scoped_error".localized
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
                
                guard let mode = importMode else { return }
                switch mode {
                case .infrastructure:
                    if url.pathExtension.lowercased() != "json" {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    if let payload = try? decoder.decode(InfrastructurePayload.self, from: data) {
                        network.nodes = normalizedInfrastructureNodes(payload.nodes)
                        network.edges = payload.edges
                    } else if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                        network.nodes = normalizedInfrastructureNodes(dto.nodes)
                        network.edges = dto.edges
                    } else if let container = try? decoder.decode(RailFileContainer.self, from: data) {
                        network.nodes = normalizedInfrastructureNodes(container.network.nodes)
                        network.edges = container.network.edges
                    } else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    appState.sidebarSelection = .stations
                case .project:
                    if let container = try? decoder.decode(RailFileContainer.self, from: data) {
                        importDTO(container.network)
                    } else if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
                        importDTO(dto)
                    } else {
                        importError = "decode_error".localized
                    }
                }
            } catch {
                importError = String(format: "import_error_fmt".localized, error.localizedDescription)
            }
            importMode = nil
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
                importMode = .infrastructure
            }
            
            actionRow(
                title: "open_project".localized,
                subtitle: "support_format".localized,
                icon: "folder",
                iconColor: .accentColor
            ) {
                importMode = .project
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
                importMode = .project
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
        network.nodes = dto.nodes
        network.edges = dto.edges
        if let l = dto.lines { trainManager.lines = l }
        if let t = dto.trains { trainManager.trains = t }
        
        trainManager.validateSchedules()
        appState.simulator.schedules = trainManager.generateSchedulesPreview()
        
        
        // Clear selection to avoid crashes with old IDs
        appState.sidebarSelection = .stations
    }
    
    private var isImporting: Binding<Bool> {
        Binding(
            get: { importMode != nil },
            set: { isPresented in
                if !isPresented {
                    importMode = nil
                }
            }
        )
    }
    
    private func normalizedInfrastructureNodes(_ nodes: [Node]) -> [Node] {
        nodes.map { node in
            var updated = node
            let trimmedName = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                updated.name = updated.id
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
            let node = Node(
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
            
            let edge = Edge(
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

struct InfrastructureDocument: @preconcurrency FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json] }
    private var nodes: [Node]
    private var edges: [Edge]

    init(nodes: [Node], edges: [Edge]) {
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
    let nodes: [Node]
    let edges: [Edge]
}

private enum ImportMode {
    case project
    case infrastructure
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
