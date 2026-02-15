import SwiftUI

// MARK: - Station Inspector
struct StationInspectorView: View {
    @Binding var station: Node
    @Binding var isMoveModeEnabled: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    
    var onDelete: (() -> Void)?
    
    @State private var isEditingEnabled = false
    @State private var isRoutingSheetPresented = false
    @State private var localConstraints: [RoutingConstraint] = []
    
    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }
    
    var body: some View {
        InspectorView(
            title: station.name,
            icon: "building.2.fill",
            iconColor: .blue,
            onBack: nil,
            onClose: {
                withAnimation {
                    appState.clearSelection()
                }
            }
        ) {
            EditingModeBanner(isEditingEnabled: $isEditingEnabled)
            
            basicInfoSection
            hubsSection
            visualStyleSection
            coordinatesSection
            routingSection
            
            if onDelete != nil {
                InspectorDeleteButton(label: "delete_station".localized, onDelete: onDelete ?? {})
            }
        }
        .disabled(!isEditingEnabled)
        .onLongPressGesture(minimumDuration: 1.0) {
            isEditingEnabled.toggle()
        }
        .onAppear {
            isEditingEnabled = true
            localConstraints = station.routingConstraints
        }
        .onDisappear {
            isEditingEnabled = false
            Task { loader.saveCurrentState() }
        }
        .sheet(isPresented: $isRoutingSheetPresented) {
            routingConstraintsSheet
        }
    }
    
    // MARK: - Sections
    
    private var basicInfoSection: some View {
        InspectorSection(title: "station_data".localized, icon: "info.circle.fill", iconColor: .blue) {
            InspectorTextField(label: "station_name".localized, text: $station.name)
            
            InspectorPicker(label: "functional_type".localized, selection: $station.type) {
                Text("standard_station".localized).tag(Node.NodeType.station)
                Text("interchange".localized).tag(Node.NodeType.interchange)
                Text("depot".localized).tag(Node.NodeType.depot)
            }
            .pickerStyle(.segmented)
            
            platformsStepper
        }
    }
    
    private var platformsStepper: some View {
        Stepper(
            onIncrement: {
                if (station.platforms ?? 2) < 20 {
                    station.platforms = (station.platforms ?? 2) + 1
                }
            },
            onDecrement: {
                if (station.platforms ?? 2) > 1 {
                    station.platforms = (station.platforms ?? 2) - 1
                }
            }
        ) {
            HStack {
                Text("platform_count".localized)
                Spacer()
                Text("\(station.platforms ?? 2)")
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)
            }
        }
    }
    
    private var hubsSection: some View {
        InspectorSection(title: "hubs_interchanges".localized, icon: "arrow.triangle.branch", iconColor: .purple) {
            Picker("belongs_to_hub".localized, selection: $station.parentHubId) {
                Text("no_hub".localized).tag(String?.none)
                Divider()
                ForEach(availableHubs) { node in
                    Text(node.name).tag(String?.some(node.id))
                }
            }
            
            if station.parentHubId != nil {
                hubPositionPicker
            }
        }
    }
    
    private var hubPositionPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("hub_position".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("hub_position".localized, selection: $station.hubOffsetDirection) {
                Text("hub_standard_pos".localized).tag(Node.HubOffsetDirection?.none)
                ForEach(Node.HubOffsetDirection.allCases) { dir in
                    Text(dir.localizedName).tag(Node.HubOffsetDirection?.some(dir))
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var availableHubs: [Node] {
        network.nodes.filter { $0.id != station.id }.sorted { $0.name < $1.name }
    }
    
    private var visualStyleSection: some View {
        InspectorSection(title: "visual_style".localized, icon: "paintbrush.fill", iconColor: .orange) {
            Picker("type".localized, selection: $station.visualType) {
                ForEach(Node.StationVisualType.allCases) { type in
                    symbolImage(for: type).tag(Node.StationVisualType?.some(type))
                }
            }
            .pickerStyle(.segmented)
            
            HStack {
                Text("custom_color".localized)
                Spacer()
                ColorPicker("", selection: Binding<Color>(
                    get: { Color(hex: station.customColor ?? station.defaultColor) ?? .black },
                    set: { if let hex = $0.toHex() { station.customColor = hex } }
                ))
                .labelsHidden()
            }
        }
    }
    
    private var coordinatesSection: some View {
        InspectorSection(title: "coordinates".localized, icon: "location.fill", iconColor: .green) {
            HStack {
                Text("latitude".localized)
                Spacer()
                TextField("lat", value: Binding(
                    get: { station.latitude ?? 0.0 },
                    set: { station.latitude = $0 }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            }
            
            HStack {
                Text("longitude".localized)
                Spacer()
                TextField("lon", value: Binding(
                    get: { station.longitude ?? 0.0 },
                    set: { station.longitude = $0 }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            }
            
            InspectorInfoBanner(
                type: .info,
                title: nil,
                message: "coordinates_drag_hint".localized
            )
        }
    }
    
    private var routingSection: some View {
        InspectorSection(title: "routing_constraints".localized, icon: "arrow.triangle.swap", iconColor: .purple) {
            HStack {
                if station.routingConstraints.isEmpty {
                    Text("no_constraints".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(station.routingConstraints.prefix(3)) { constraint in
                            let lineName = lines.lines.first(where: { $0.id == constraint.lineId })?.name ?? "???"
                            Text("• \(lineName): [\(constraint.allowedTracks.joined(separator: ", "))]")
                                .font(.caption)
                        }
                        if station.routingConstraints.count > 3 {
                            Text("+ \(station.routingConstraints.count - 3) ...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button("configure".localized) {
                    localConstraints = station.routingConstraints
                    isRoutingSheetPresented = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func symbolImage(for type: Node.StationVisualType) -> some View {
        switch type {
        case .filledStar: return Image(systemName: "star.fill")
        case .filledSquare: return Image(systemName: "square.fill")
        case .emptySquare: return Image(systemName: "square")
        case .filledCircle: return Image(systemName: "circle.fill")
        case .emptyCircle: return Image(systemName: "circle")
        }
    }
    
    // MARK: - Routing Sheet (semplificato, mantiene la logica esistente)
    
    @ViewBuilder
    private var routingConstraintsSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name).font(.headline).foregroundColor(.blue)
                    Text("routing_config_hint".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                List {
                    if directionGroups.isEmpty {
                        Text("no_lines_at_station".localized)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    ForEach(directionGroups) { group in
                        Section(header: Text(String(format: "connection_to".localized, group.name)).font(.caption.bold()).foregroundColor(.blue)) {
                            ForEach(group.lines) { line in
                                let dirId: String? = (group.id == "terminus" ? nil : group.id)
                                RoutingLineRow(
                                    line: line,
                                    allowedTracks: Binding(
                                        get: { localConstraints.first { $0.lineId == line.id && $0.directionStationId == dirId }?.allowedTracks ?? [] },
                                        set: { updateTracks(lineId: line.id, directionId: dirId, tracks: $0) }
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
                    Button("done".localized) {
                        isRoutingSheetPresented = false
                    }
                }
            }
        }
    }
    
    private struct DirectionGroup: Identifiable {
        let id: String
        let name: String
        let lines: [RailwayLine]
    }
    
    private var directionGroups: [DirectionGroup] {
        let stationLines = lines.lines.filter { line in
            line.stops.contains { $0.stationId == station.id }
        }
        
        var groupsMap: [String: Set<String>] = [:]
        
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
    
    private func updateTracks(lineId: String, directionId: String?, tracks: [String]) {
        if let idx = localConstraints.firstIndex(where: { $0.lineId == lineId && $0.directionStationId == directionId }) {
            if tracks.isEmpty {
                localConstraints.remove(at: idx)
            } else {
                localConstraints[idx].allowedTracks = tracks
            }
        } else if !tracks.isEmpty {
            localConstraints.append(RoutingConstraint(lineId: lineId, directionStationId: directionId, allowedTracks: tracks))
        }
        station.routingConstraints = localConstraints
    }
}
