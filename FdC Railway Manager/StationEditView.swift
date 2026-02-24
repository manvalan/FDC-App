import SwiftUI

struct StationEditView: View {
    @Binding var station: RailwayNode
    @Binding var isMoveModeEnabled: Bool
    @EnvironmentObject var appState: AppState
    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }
    @EnvironmentObject var loader: AppLoaderService
    @Environment(\.dismiss) var dismiss
    
    var onDelete: (() -> Void)? = nil
    @State private var showDeleteConfirmation = false
    @State private var initialStation: RailwayNode? 
    @State private var isRoutingSheetPresented = false
    
    // Local copy to avoid crashes with List animations and parent bindings
    @State private var localConstraints: [RoutingConstraint] = []
    @State private var localPlatforms: Int = 2
    
    private var allLinesSorted: [RailwayLine] {
        lines.lines.sorted { $0.name < $1.name }
    }
    
    private func isLineAtStation(_ lineId: String) -> Bool {
        lines.lines.first(where: { $0.id == lineId })?.stops.contains(where: { $0.stationId == station.id }) ?? false
    }
    
    private func possibleNextStations(for lineId: String) -> [RailwayNode] {
        guard !lineId.isEmpty, let line = lines.lines.first(where: { $0.id == lineId }) else { return [] }
        let stopIndices = line.stops.enumerated().filter { $0.element.stationId == station.id }.map { $0.offset }
        
        var nextIds = Set<String>()
        for idx in stopIndices {
            if idx > 0 { nextIds.insert(line.stops[idx - 1].stationId) }
            if idx < line.stops.count - 1 { nextIds.insert(line.stops[idx + 1].stationId) }
        }
        
        return network.nodes.filter { nextIds.contains($0.id) }.sorted { $0.name < $1.name }
    }
    
    private var availableHubs: [RailwayNode] {
        network.nodes.filter { $0.id != station.id }.sorted { $0.name < $1.name }
    }
    
    // Identifica le direzioni (nodi adiacenti) e le linee che le percorrono
    private struct DirectionGroup: Identifiable {
        let id: String // ID nodo destinazione o "terminus"
        let name: String
        let lines: [RailwayLine]
    }
    
    private var directionGroups: [DirectionGroup] {
        // Tutte le linee che fermano in questa stazione
        let stationLines = lines.lines.filter { line in
            line.stops.contains { $0.stationId == station.id }
        }
        
        var groupsMap: [String: Set<String>] = [:] // Map neighborId -> Set of lineIds
        
        for line in stationLines {
            let neighborIds = line.stops.enumerated().flatMap { (idx, stop) -> [String] in
                guard stop.stationId == station.id else { return [] }
                var result: [String] = []
                if idx > 0 { result.append(line.stops[idx - 1].stationId) }
                if idx < line.stops.count - 1 { result.append(line.stops[idx + 1].stationId) }
                return result
            }
            
            if neighborIds.isEmpty {
                groupsMap["terminus", default: Set<String>()].insert(line.id)
            } else {
                for nid in neighborIds {
                    groupsMap[nid, default: Set<String>()].insert(line.id)
                }
            }
        }
        
        return groupsMap.map { (key, lineIds) in
            let name: String
            if key == "terminus" {
                name = "Terminus / No neighbors"
            } else {
                name = network.nodes.first(where: { $0.id == key })?.name ?? key
            }
            let groupLines = lines.lines.filter { lineIds.contains($0.id) }.sorted { $0.name < $1.name }
            return DirectionGroup(id: key, name: name, lines: groupLines)
        }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Editing mode banner
                    if !appState.isInspectorEditingMode {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Modalità Sola Lettura")
                                    .font(.subheadline.bold())
                                    .foregroundColor(appState.theme.dark)
                                Text("Tieni premuto per 1 secondo per abilitare le modifiche")
                                    .font(.caption)
                                    .foregroundColor(appState.theme.medium)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(appState.theme.accent)
                            Text("Modalità Modifica Attiva")
                                .font(.subheadline.bold())
                                .foregroundColor(appState.theme.dark)
                            Spacer()
                        }
                        .padding()
                        .background(appState.theme.accent.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    headerSection
                    stationDataSection
                    hubsSection
                    visualStyleSection
                    coordinatesSection
                    routingConstraintsSection
                    deleteSection
                }
                .padding()
                .disabled(!appState.isInspectorEditingMode)
            }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            appState.isInspectorEditingMode.toggle()
        }
        .sheet(isPresented: $isRoutingSheetPresented) {
            routingConstraintsSheet
        }
        .onAppear {
            if initialStation == nil { initialStation = station }
            // Sync local copies
            localConstraints = station.routingConstraints
            localPlatforms = station.platforms ?? 2
            // Enable editing mode by default when opening the editor
            appState.isInspectorEditingMode = true
        }
        .onChange(of: station.routingConstraints) { newValue in
            // Keep local in sync if parent changes (rare)
            if !isRoutingSheetPresented {
                localConstraints = newValue
            }
        }
        .alert("delete_station".localized, isPresented: $showDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) { onDelete?() }
        } message: {
            Text("delete_confirm".localized)
        }
        .onDisappear {
            appState.isInspectorEditingMode = false
            Task { await loader.saveCurrentState() }
        }
    }
    
    // MARK: - Main Sections
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Image(systemName: "building.2.fill").font(.largeTitle).foregroundColor(appState.theme.accent)
            VStack(alignment: .leading) {
                Text(station.name).font(.title).fontWeight(.bold).foregroundColor(appState.theme.dark)
                Text("edit_station".localized).font(.subheadline).foregroundColor(appState.theme.medium)
            }
            Spacer()
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }
    
    @ViewBuilder
    private var stationDataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("station_data".localized.uppercased()).font(.caption.bold()).foregroundColor(appState.theme.medium)
            TextField("station_name".localized, text: $station.name).textFieldStyle(.roundedBorder)
            
            Picker("functional_type".localized, selection: $station.type) {
                Text("standard_station".localized).tag(RailwayNode.NodeType.station)
                Text("interchange".localized).tag(RailwayNode.NodeType.interchange)
                Text("depot".localized).tag(RailwayNode.NodeType.depot)
            }
            .pickerStyle(.segmented)
            
            Stepper(onIncrement: {
                if localPlatforms < 20 { 
                    localPlatforms += 1
                    station.platforms = localPlatforms
                }
            }, onDecrement: {
                if localPlatforms > 1 { 
                    localPlatforms -= 1
                    station.platforms = localPlatforms
                }
            }) {
                HStack {
                    Text("platform_count".localized)
                    Spacer()
                    Text("\(localPlatforms)").foregroundColor(appState.theme.medium).fontWeight(.bold)
                }
            }
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }
    
    @ViewBuilder
    private var hubsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("hubs_interchanges".localized.uppercased()).font(.caption.bold()).foregroundColor(appState.theme.medium)
            
            Picker("belongs_to_hub".localized, selection: $station.parentHubId) {
                Text("no_hub".localized).tag(String?.none)
                Divider()
                ForEach(availableHubs) { node in 
                    Text(node.name).tag(String?.some(node.id)) 
                }
            }
            
            if station.parentHubId != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("hub_position".localized)
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                    
                    Picker("hub_position".localized, selection: $station.hubOffsetDirection) {
                        Text("hub_standard_pos".localized).tag(RailwayNode.HubOffsetDirection?.none)
                        ForEach(RailwayNode.HubOffsetDirection.allCases) { dir in 
                            Text(dir.localizedName).tag(RailwayNode.HubOffsetDirection?.some(dir)) 
                        }
                    }
                    .pickerStyle(.segmented)
                    .id(station.hubOffsetDirection) // Force refresh when value changes
                    
                    // Debug info
                    if let offset = station.hubOffsetDirection {
                        Text("Selezionato: \(offset.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else {
                        Text("Selezionato: Standard (nessuno)")
                            .font(.caption2)
                            .foregroundColor(appState.theme.medium)
                    }
                }
            }
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }
    
    @ViewBuilder
    private var visualStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("visual_style".localized.uppercased()).font(.caption.bold()).foregroundColor(appState.theme.medium)
            Picker("type".localized, selection: $station.visualType) {
                ForEach(RailwayNode.StationVisualType.allCases) { type in symbolImage(for: type).tag(RailwayNode.StationVisualType?.some(type)) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("custom_color".localized)
                Spacer()
                ColorPicker("", selection: Binding<Color>(
                    get: { Color(hex: station.customColor ?? station.defaultColor) ?? .black },
                    set: { if let hex = $0.toHex() { station.customColor = hex } }
                )).labelsHidden()
            }
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }
    
    @ViewBuilder
    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("coordinates".localized.uppercased()).font(.caption.bold()).foregroundColor(appState.theme.medium)
            HStack {
                Text("latitude".localized); Spacer()
                TextField("lat", value: Binding(get: { station.latitude ?? 0.0 }, set: { station.latitude = $0 }), format: .number).textFieldStyle(.roundedBorder).frame(width: 150)
            }
            HStack {
                Text("longitude".localized); Spacer()
                TextField("lon", value: Binding(get: { station.longitude ?? 0.0 }, set: { station.longitude = $0 }), format: .number).textFieldStyle(.roundedBorder).frame(width: 150)
            }
            
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(appState.theme.accent)
                    .font(.caption)
                Text("Le coordinate possono essere modificate anche trascinando la stazione sulla mappa")
                    .font(.caption)
                    .foregroundColor(appState.theme.medium)
            }
            .padding(.top, 4)
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }
    
    @ViewBuilder
    private var routingConstraintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("routing_constraints".localized.uppercased()).font(.caption.bold())
                Spacer()
                Button("configure".localized) { 
                    localConstraints = station.routingConstraints
                    isRoutingSheetPresented = true 
                }.buttonStyle(.bordered).controlSize(.small)
            }
            
            if station.routingConstraints.isEmpty {
                Text("-").font(.caption).foregroundColor(appState.theme.medium)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(station.routingConstraints.prefix(3)) { constraint in
                        let lineName = lines.lines.first(where: { $0.id == constraint.lineId })?.name ?? "???"
                        Text("• \(lineName): [\(constraint.allowedTracks.joined(separator: ", "))]").font(.caption).foregroundColor(appState.theme.dark)
                    }
                    if station.routingConstraints.count > 3 {
                        Text("+ \(station.routingConstraints.count - 3) ...").font(.caption2).foregroundColor(appState.theme.medium)
                    }
                }
            }
        }
        .padding().background(appState.theme.accent.opacity(0.05)).cornerRadius(12)
    }
    
    @ViewBuilder
    private var deleteSection: some View {
        if let _ = onDelete {
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Text("delete_station".localized).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private func symbolImage(for type: RailwayNode.StationVisualType) -> some View {
        switch type {
        case .filledStar: Image(systemName: "star.fill")
        case .filledSquare: Image(systemName: "square.fill")
        case .emptySquare: Image(systemName: "square")
        case .filledCircle: Image(systemName: "circle.fill")
        case .emptyCircle: Image(systemName: "circle")
        }
    }
    
    // MARK: - Routing Constraints SHEET
    
    @ViewBuilder
    private var routingConstraintsSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name).font(.headline).foregroundColor(appState.theme.accent)
                    Text("Scegli una direzione per configurare i binari dedicati alle linee corrispondenti.").font(.caption).foregroundColor(appState.theme.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(UIColor.secondarySystemBackground))
                
                List {
                    if directionGroups.isEmpty {
                        Text("Nessuna linea attraversa questa stazione.").foregroundColor(appState.theme.medium).padding()
                    }
                    
                    // 1. Vincoli per Direzione Specifica (Derivati dalle linee esistenti)
                    ForEach(directionGroups) { group in
                        Section(header: Text("Collegamento: \(group.name)").font(.caption.bold()).foregroundColor(appState.theme.accent)) {
                            ForEach(group.lines) { line in
                                let dirId: String? = (group.id == "terminus" ? nil : group.id)
                                RoutingLineRow(
                                    line: line,
                                    allowedTracks: Binding(
                                        get: { localConstraints.first { $0.lineId == line.id && $0.directionStationId == dirId }?.allowedTracks ?? [] },
                                        set: { updateTracks(lineId: line.id, directionId: dirId, tracks: $0, type: .allowed) }
                                    ),
                                    transitTracks: Binding(
                                        get: { localConstraints.first { $0.lineId == line.id && $0.directionStationId == dirId }?.transitTracks ?? [] },
                                        set: { updateTracks(lineId: line.id, directionId: dirId, tracks: $0, type: .transit) }
                                    ),
                                    stopTracks: Binding(
                                        get: { localConstraints.first { $0.lineId == line.id && $0.directionStationId == dirId }?.stopTracks ?? [] },
                                        set: { updateTracks(lineId: line.id, directionId: dirId, tracks: $0, type: .stop) }
                                    ),
                                    totalPlatforms: station.platforms ?? 2
                                )
                            }
                        }
                    }
                    
                    // 2. Sezione "Generale" per catch-all a livello di stazione/linea
                    let stationLines = lines.lines.filter { line in
                        line.stops.contains { $0.stationId == station.id }
                    }.sorted { $0.name < $1.name }
                    
                    if !stationLines.isEmpty {
                        Section(header: Text("Valido per Tutte le Direzioni").font(.caption.bold()).foregroundColor(appState.theme.medium)) {
                            ForEach(stationLines) { line in
                                RoutingLineRow(
                                    line: line,
                                    allowedTracks: Binding(
                                        get: { localConstraints.first { $0.lineId == line.id && $0.directionStationId == nil }?.allowedTracks ?? [] },
                                        set: { updateTracks(lineId: line.id, directionId: nil, tracks: $0, type: .allowed) }
                                    ),
                                    transitTracks: Binding(
                                        get: { localConstraints.first { $0.lineId == line.id && $0.directionStationId == nil }?.transitTracks ?? [] },
                                        set: { updateTracks(lineId: line.id, directionId: nil, tracks: $0, type: .transit) }
                                    ),
                                    stopTracks: Binding(
                                        get: { localConstraints.first { $0.lineId == line.id && $0.directionStationId == nil }?.stopTracks ?? [] },
                                        set: { updateTracks(lineId: line.id, directionId: nil, tracks: $0, type: .stop) }
                                    ),
                                    totalPlatforms: station.platforms ?? 2
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("routing_constraints".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) { isRoutingSheetPresented = false }
                }
            }
        }
    }
    
    private func isTerminus(lineId: String) -> Bool {
        guard let line = lines.lines.first(where: { $0.id == lineId }) else { return false }
        return line.stops.last?.stationId == station.id
    }
    
    private enum TrackConfigType {
        case allowed, transit, stop
    }
    
    private func updateTracks(lineId: String, directionId: String?, tracks: [String], type: TrackConfigType) {
        if let idx = localConstraints.firstIndex(where: { $0.lineId == lineId && $0.directionStationId == directionId }) {
            switch type {
            case .allowed: localConstraints[idx].allowedTracks = tracks
            case .transit: localConstraints[idx].transitTracks = tracks
            case .stop: localConstraints[idx].stopTracks = tracks
            }
            
            // Cleanup: se tutto è vuoto rimuovi
            if localConstraints[idx].allowedTracks.isEmpty && (localConstraints[idx].transitTracks?.isEmpty ?? true) && (localConstraints[idx].stopTracks?.isEmpty ?? true) {
                localConstraints.remove(at: idx)
            }
        } else if !tracks.isEmpty {
            var newC = RoutingConstraint(lineId: lineId, directionStationId: directionId, allowedTracks: [])
            switch type {
            case .allowed: newC.allowedTracks = tracks
            case .transit: newC.transitTracks = tracks
            case .stop: newC.stopTracks = tracks
            }
            localConstraints.append(newC)
        }
        station.routingConstraints = localConstraints
    }
}

// MARK: - ROW View semplificata per linea e direzione
struct RoutingLineRow: View {
    @EnvironmentObject var appState: AppState
    let line: RailwayLine
    @Binding var allowedTracks: [String]
    @Binding var transitTracks: [String]
    @Binding var stopTracks: [String]
    let totalPlatforms: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: line.color ?? "#666666") ?? .gray).frame(width: 8, height: 8)
                    Text(line.name).font(.subheadline.bold())
                }
                Spacer()
            }
            
            // 1. Binari per Transito
            VStack(alignment: .leading, spacing: 4) {
                Label("Transito (Prioritario)", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.orange)
                trackSelector(for: $transitTracks, color: .orange)
            }
            
            // 2. Binari per Sosta / Origine
            VStack(alignment: .leading, spacing: 4) {
                Label("Sosta / Origine (Prioritario)", systemImage: "parkingsign.circle.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.blue)
                trackSelector(for: $stopTracks, color: .blue)
            }
            
            // 3. Altri binari ammessi
            VStack(alignment: .leading, spacing: 4) {
                Label("Ammessi (Generico)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                trackSelector(for: $allowedTracks, color: appState.theme.accent)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func trackSelector(for tracks: Binding<[String]>, color: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(1...totalPlatforms, id: \.self) { num in
                let track = "\(num)"
                let isSelected = tracks.wrappedValue.contains(track)
                
                Button(action: {
                    if isSelected {
                        tracks.wrappedValue.removeAll { $0 == track }
                    } else {
                        tracks.wrappedValue.append(track)
                    }
                }) {
                    Text(track)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(isSelected ? color : appState.theme.backgroundSecondary)
                        .foregroundColor(isSelected ? .white : appState.theme.dark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
