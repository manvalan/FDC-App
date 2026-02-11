import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FloatingModeBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(AppMode.allCases) { mode in
                Button(action: {
                    appState.currentMode = mode
                    appState.showPanel(.none)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 20, weight: .semibold))
                        Text(mode.title)
                            .font(.caption2)
                            .bold()
                    }
                    .foregroundColor(appState.currentMode == mode ? appState.theme.accent : appState.theme.medium)
                    .frame(width: 110, height: 75)
                    .background(appState.currentMode == mode ? appState.theme.accent.opacity(0.12) : appState.theme.light.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(appState.currentMode == mode ? appState.theme.accent.opacity(0.3) : appState.theme.line.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .background(appState.theme.background)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        .transition(.move(edge: .top).combined(with: .opacity))
        .gesture(
            DragGesture().onEnded { val in
                if val.translation.height < -20 {
                    appState.showPanel(.none)
                }
            }
        )
    }
    
    private func icon(for mode: AppMode) -> String {
        switch mode {
        case .design: return "pencil.and.outline"
        case .schedule: return "calendar.badge.clock"
        case .live: return "play.fill"
        }
    }
}

struct FloatingSideMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Navigazione")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: { appState.showPanel(.none) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(appState.theme.medium)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
                .background(appState.theme.line.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    SidebarSection(title: "Infrastruttura") {
                        SidebarButton(title: "Stazioni", icon: "building.2") {
                            appState.sidebarSelection = .stations
                            appState.currentMode = .design
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                        
                        SidebarButton(title: "Binari", customIcon: "🛤", isSpecial: true) {
                            appState.sidebarSelection = .tracks
                            appState.currentMode = .design
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                    }
                    
                    SidebarSection(title: "Servizio") {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 12) {
                                Image(systemName: "tram")
                                    .foregroundColor(appState.theme.medium)
                                    .frame(width: 24)
                                Text("Gestione Linee")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(appState.theme.dark)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)

                            VStack(alignment: .leading, spacing: 4) {
                                SidebarSubButton(title: "Infrastruttura", icon: "pencil.and.outline", isSelected: appState.sidebarSelection == .lines && appState.lineInspectorMode == .infrastructure) {
                                    appState.sidebarSelection = .lines
                                    appState.lineInspectorMode = .infrastructure
                                    appState.selectedLineId = nil
                                    appState.showPanel(.inspector)
                                }
                                
                                SidebarSubButton(title: "Orario", icon: "chart.xyaxis.line", isSelected: appState.sidebarSelection == .lines && appState.lineInspectorMode == .schedule) {
                                    appState.sidebarSelection = .lines
                                    appState.lineInspectorMode = .schedule
                                    appState.selectedLineId = nil
                                    appState.showPanel(.inspector)
                                }
                                
                                SidebarSubButton(title: "Mezzi", icon: "tram.fill", isSelected: appState.sidebarSelection == .lines && appState.lineInspectorMode == .vehicles) {
                                    appState.sidebarSelection = .lines
                                    appState.lineInspectorMode = .vehicles
                                    appState.selectedLineId = nil
                                    appState.showPanel(.inspector)
                                }
                            }
                            .padding(.leading, 8)
                        }
                        
                        SidebarButton(title: "Flotta Generale", icon: "tram.fill") {
                            appState.sidebarSelection = .vehicles
                            appState.currentMode = .design
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                    }
                    
                    SidebarSection(title: "Programmazione") {
                        SidebarButton(title: "Treni per Linea", icon: "train.side.front.car") {
                            appState.sidebarSelection = .trains
                            appState.currentMode = .schedule
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                        SidebarButton(title: "Tabella Oraria", icon: "tablecells") {
                            appState.sidebarSelection = .timetable
                            appState.currentMode = .schedule
                        }
                        SidebarButton(title: "Grafico Orario", icon: "chart.xyaxis.line") {
                            appState.sidebarSelection = .diagram
                            appState.currentMode = .schedule
                        }
                    }
                    
                    SidebarSection(title: "Strumenti") {
                        SidebarButton(title: "Import/Export", icon: "doc.badge.arrow.up") {
                            appState.sidebarSelection = .io
                        }
                        
                        SidebarButton(title: "Impostazioni", icon: "gearshape") {
                            appState.sidebarSelection = .settings
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 330)
        .background(appState.theme.background)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
        .padding(.leading, 20)
        .transition(.move(edge: .leading))
        .gesture(
            DragGesture().onEnded { val in
                if val.translation.width < -30 {
                    appState.showPanel(.none)
                }
            }
        )
    }
}

struct ContextualInspector: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @State private var editingStation: Node? = nil
    @State private var editingLine: RailwayLine? = nil
    @State private var editingEdge: Edge? = nil
    @State private var isCreatingVehicle: Bool = false
    
    @State private var itemToDelete: AnyIdentifiable? = nil
    @State private var showingDeleteAlert = false

    struct AnyIdentifiable: Identifiable {
        let id: String
        let type: ItemType
        enum ItemType { case station, edge, line }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let line = appState.selectedLine {
                        Text(line.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let node = appState.selectedNode {
                        Text(node.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if appState.sidebarSelection == .lines {
                        Text("Seleziona Linea").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else {
                        Text("Ispettore").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    }
                }
                Spacer()
                Button(action: { 
                    if !appState.selectedTrainIds.isEmpty {
                        appState.selectedTrainIds = []
                    } else if appState.selectedNodeId != nil {
                        appState.selectedNodeId = nil
                    } else if appState.selectedEdgeId != nil {
                        appState.selectedEdgeId = nil
                    } else if appState.selectedLineId != nil && (appState.sidebarSelection == .lines || appState.sidebarSelection == .trains) {
                        appState.selectedLineId = nil
                    } else {
                        appState.showPanel(.none) 
                    }
                }) {
                    Image(systemName: appState.isSomethingSelected ? "chevron.left.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(appState.theme.medium)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
                .background(appState.theme.line.opacity(0.2))
                .padding(.horizontal, 16)
            
            if let trainId = appState.selectedTrainIds.first,
               let train = linesManager.trains.first(where: { $0.id == trainId }) {
                ScrollView {
                    TrainDetailView(train: train)
                        .padding(16)
                }
            } else if let line = appState.selectedLine {
                VStack(spacing: 0) {
                    LineQuickStats(line: line)
                        .padding(16)
                    
                    Divider()
                        .background(appState.theme.line.opacity(0.1))
                        .padding(.horizontal, 16)
                    
                    switch appState.lineInspectorMode {
                    case .infrastructure:
                        VerticalTrackDiagramView(
                            line: Binding(
                                get: { appState.selectedLine ?? line },
                                set: { newLine in
                                    if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                                        linesManager.lines[idx] = newLine
                                    }
                                }
                            ),
                            network: appState.railroad.network,
                            isMoveModeEnabled: .constant(false),
                            externalSelectedStationID: $appState.selectedNodeId,
                            externalSelectedEdgeID: $appState.selectedEdgeId
                        )
                    case .schedule:
                        // Show vertical diagram as reference when in schedule mode
                        VerticalTrackDiagramView(
                            line: Binding(
                                get: { appState.selectedLine ?? line },
                                set: { newLine in
                                    if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                                        linesManager.lines[idx] = newLine
                                    }
                                }
                            ),
                            network: appState.railroad.network,
                            isMoveModeEnabled: .constant(false),
                            externalSelectedStationID: $appState.selectedNodeId,
                            externalSelectedEdgeID: $appState.selectedEdgeId
                        )
                    case .vehicles:
                        ScrollView {
                            LineVehiclesView(lineId: line.id)
                                .padding(16)
                        }
                    }
                }
            } else if let node = appState.selectedNode {
                ScrollView {
                    StationQuickStats(node: node, onEdit: { editingStation = node })
                        .padding(16)
                }
            } else if let edgeId = appState.selectedEdgeId,
                      let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
                ScrollView {
                    TrackQuickStats(edge: edge, onEdit: { editingEdge = edge })
                        .padding(16)
                }
            } else {
                ScrollView {
                    globalSidebarList
                        .padding(16)
                }
            }
        }
        .frame(width: 360)
        .background(appState.theme.background)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
        .padding(.trailing, 20)
        .colorScheme(.light) // Force light theme for the monochromatic look requested
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .gesture(
            DragGesture().onEnded { val in
                if val.translation.width > 30 {
                    appState.showPanel(.none)
                }
            }
        )
        .alert("Conferma eliminazione", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) { 
                if let item = itemToDelete {
                    performDelete(item)
                }
            }
        } message: {
            Text("Sei sicuro di voler eliminare questo elemento? L'azione non può essere annullata.")
        }
        // Editing Sheets
        .sheet(item: $editingStation) { station in
            NavigationStack {
                StationEditView(station: .constant(station), isMoveModeEnabled: .constant(false))
                    .navigationTitle(station.name)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { editingStation = nil } } }
            }
        }
        .sheet(item: $editingLine) { line in
            NavigationStack {
                LineEditView(lineId: line.id)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { editingLine = nil } } }
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(item: $editingEdge) { edge in
            NavigationStack {
                TrackEditView(edge: .constant(edge), onDelete: {
                    appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                    appState.selectedEdgeId = nil
                    editingEdge = nil
                })
                .navigationTitle("Modifica Binario")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { editingEdge = nil } } }
            }
        }
        .sheet(isPresented: $isCreatingVehicle) {
            VehicleCreationSheet()
        }
    }

    private func performDelete(_ item: AnyIdentifiable) {
        switch item.type {
        case .station:
            appState.railroad.network.removeNode(item.id)
            if appState.selectedNodeId == item.id { appState.selectedNodeId = nil }
        case .edge:
            if let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == item.id }) {
                appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                if appState.selectedEdgeId == item.id { appState.selectedEdgeId = nil }
            }
        case .line:
            linesManager.lines.removeAll { $0.id == item.id }
            linesManager.trains.removeAll { $0.lineId == item.id }
            if appState.selectedLineId == item.id { appState.selectedLineId = nil }
        }
    }
    
    @ViewBuilder
    private var globalSidebarList: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch appState.sidebarSelection {
            case .stations:
                stationsList
            case .tracks:
                tracksList
            case .lines:
                linesList
            case .trains:
                trainsByLineList
            case .vehicles:
                vehiclesList
            default:
                EmptyView()
            }
        }
    }

    private var stationsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stazioni").font(.headline).foregroundColor(appState.theme.dark)
            
            VStack(spacing: 8) {
                ForEach(appState.railroad.network.nodes.sorted(by: { $0.name < $1.name })) { node in
                    HStack {
                        Button(action: { appState.selectedNodeId = node.id }) {
                            HStack(spacing: 12) {
                                Image(systemName: "building.2")
                                    .foregroundColor(appState.theme.medium)
                                    .frame(width: 24)
                                Text(node.name)
                                    .font(.subheadline)
                                    .foregroundColor(appState.theme.dark)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(appState.selectedNodeId == node.id ? appState.theme.accent.opacity(0.1) : appState.theme.light.opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            itemToDelete = AnyIdentifiable(id: node.id, type: .station)
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(appState.theme.medium)
                                .padding(10)
                                .background(appState.theme.light.opacity(0.4))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private var tracksList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Binari").font(.headline).foregroundColor(appState.theme.dark)
            
            VStack(spacing: 8) {
                let sortedEdges = appState.railroad.network.edges.sorted { e1, e2 in
                    let name1 = appState.railroad.network.nodes.first(where: { $0.id == e1.from })?.name ?? ""
                    let name2 = appState.railroad.network.nodes.first(where: { $0.id == e2.from })?.name ?? ""
                    return name1 < name2
                }
                ForEach(sortedEdges) { edge in
                    HStack {
                        Button(action: { appState.selectedEdgeId = edge.id.uuidString }) {
                            let fromName = appState.railroad.network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
                            let toName = appState.railroad.network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
                            HStack(spacing: 12) {
                                Text("🛤")
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                Text("\(fromName) ↔ \(toName)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(appState.theme.dark)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(appState.selectedEdgeId == edge.id.uuidString ? appState.theme.accent.opacity(0.1) : appState.theme.light.opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            itemToDelete = AnyIdentifiable(id: edge.id.uuidString, type: .edge)
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(appState.theme.medium)
                                .padding(10)
                                .background(appState.theme.light.opacity(0.4))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private var linesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Linee").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    let newLine = RailwayLine(id: UUID().uuidString, name: "Nuova Linea", color: "#6B7280", stops: [])
                    linesManager.lines.append(newLine)
                    appState.selectedLineId = newLine.id
                }) {
                    Label("Nuova", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            
            VStack(spacing: 8) {
                let sortedLines = linesManager.lines.sorted { l1, l2 in
                    let p1 = l1.numberPrefix ?? 0
                    let p2 = l2.numberPrefix ?? 0
                    if p1 != p2 { return p1 < p2 }
                    return (l1.codePrefix ?? "") < (l2.codePrefix ?? "")
                }
                
                ForEach(sortedLines) { line in
                    HStack {
                        LineRow(line: line)
                        
                        Button(action: {
                            itemToDelete = AnyIdentifiable(id: line.id, type: .line)
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(appState.theme.medium)
                                .padding(10)
                                .background(appState.theme.light.opacity(0.4))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private var trainsByLineList: some View {
        TrainsByLineListView()
    }

    private var vehiclesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Flotta").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    isCreatingVehicle = true
                }) {
                    Label("Nuovo", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            
            let grouped = Dictionary(grouping: linesManager.vehicles, by: { $0.model })
            VStack(spacing: 10) {
                if linesManager.vehicles.isEmpty {
                    Text("Nessun mezzo in flotta")
                        .font(.subheadline)
                        .foregroundColor(appState.theme.medium)
                        .padding(.vertical, 20)
                }
                
                ForEach(grouped.keys.sorted(), id: \.self) { model in
                    DisclosureGroup {
                        VStack(spacing: 6) {
                            ForEach(grouped[model] ?? []) { vehicle in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vehicle.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(appState.theme.dark)
                                        Text("\(Int(vehicle.length))m • \(Int(vehicle.maxSpeed))km/h")
                                            .font(.system(size: 10))
                                            .foregroundColor(appState.theme.medium)
                                    }
                                    Spacer()
                                    Button(action: {
                                        linesManager.vehicles.removeAll { $0.id == vehicle.id }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(appState.theme.medium)
                                    }
                                }
                                .padding(10)
                                .background(appState.theme.light.opacity(0.3))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                                Text("Tipo Mezzo").font(.system(size: 9)).foregroundColor(appState.theme.medium)
                            }
                            Spacer()
                            Text("\(grouped[model]?.count ?? 0)")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(appState.theme.light)
                                .cornerRadius(10)
                        }
                    }
                    .padding(12)
                    .background(appState.theme.background)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(appState.theme.line.opacity(0.1), lineWidth: 1))
                }
            }
        }
    }
}

struct LineRow: View {
    let line: RailwayLine
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        Button(action: { appState.selectedLineId = line.id }) {
            HStack(spacing: 12) {
                // Large Code
                Text(line.codePrefix ?? "L")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(line.uiColor.isDark ? .white : .black)
                    .frame(width: 44, height: 32)
                    .background(line.uiColor)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name)
                        .font(.subheadline.bold())
                        .foregroundColor(appState.theme.dark)
                    
                    HStack(spacing: 4) {
                        let origin = appState.railroad.network.nodes.first(where: { $0.id == line.originId })?.name ?? "-"
                        let destination = appState.railroad.network.nodes.first(where: { $0.id == line.destinationId })?.name ?? "-"
                        
                        Text("\(origin) → \(destination)")
                        
                        if let mid = findUniqueIntermediate() {
                            Text("(via \(mid))")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(appState.theme.medium)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(appState.selectedLineId == line.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(appState.selectedLineId == line.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func findUniqueIntermediate() -> String? {
        let allLines = linesManager.lines
        let sameTerminals = allLines.filter { $0.originId == line.originId && $0.destinationId == line.destinationId }
        if sameTerminals.count <= 1 { return nil }
        
        let midStops = line.stops.map { $0.stationId }.filter { $0 != line.originId && $0 != line.destinationId }
        for stopId in midStops {
            let isUnique = !sameTerminals.contains { other in
                other.id != line.id && other.stops.contains(where: { $0.stationId == stopId })
            }
            if isUnique {
                return appState.railroad.network.nodes.first(where: { $0.id == stopId })?.name
            }
        }
        return appState.railroad.network.nodes.first(where: { $0.id == (midStops.first ?? "") })?.name
    }
}

// Helpers
struct LineQuickStats: View {
    let line: RailwayLine
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Mode Selector
            HStack(spacing: 0) {
                ForEach(AppState.LineInspectorMode.allCases) { mode in
                    Button(action: { 
                        withAnimation { appState.lineInspectorMode = mode }
                    }) {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(appState.lineInspectorMode == mode ? appState.theme.accent : Color.clear)
                            .foregroundColor(appState.lineInspectorMode == mode ? .white : appState.theme.medium)
                    }
                    .cornerRadius(8)
                }
            }
            .padding(4)
            .background(appState.theme.light.opacity(0.3))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                CompactInfoRow(label: "Fermate", value: "\(line.stops.count)")
                CompactInfoRow(label: "Codice", value: line.codePrefix ?? "-")
            }
        }
    }
}

struct LineVehiclesView: View {
    let lineId: String
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mezzi in servizio").font(.headline).foregroundColor(appState.theme.dark)
            
            let assignedTrains = linesManager.trains.filter { $0.lineId == lineId }
            let groupedTrains = Dictionary(grouping: assignedTrains) { train -> String in
                if let vehicleId = train.vehicleId,
                   let vehicle = linesManager.vehicles.first(where: { $0.id == vehicleId }) {
                    return cleanModelName(vehicle.name)
                }
                return "Non Assegnati"
            }
            
            if assignedTrains.isEmpty {
                Text("Nessun treno assegnato")
                    .font(.caption)
                    .foregroundColor(appState.theme.medium)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(appState.theme.light.opacity(0.2))
                    .cornerRadius(12)
            } else {
                ForEach(groupedTrains.keys.sorted(), id: \.self) { type in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(type.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                            .padding(.horizontal, 4)
                        
                        ForEach(groupedTrains[type] ?? []) { train in
                            Button(action: { appState.selectTrain(train.id) }) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(train.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                                        Text("Corsa \(train.number ?? 0)")
                                            .font(.system(size: 10))
                                            .foregroundColor(appState.theme.medium)
                                    }
                                    Spacer()
                                    if appState.selectedTrainIds.contains(train.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(appState.theme.accent)
                                    }
                                }
                                .padding(12)
                                .background(appState.selectedTrainIds.contains(train.id) ? appState.theme.accent.opacity(0.05) : appState.theme.light.opacity(0.4))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private func cleanModelName(_ name: String) -> String {
        // Rimuove brand come "Alstom", "Hitachi", ecc. se presenti
        let brands = ["Alstom", "Hitachi", "Ansaldo", "Breda", "Stadler", "Pesa", "Siemens", "Bombardier", "Fiat"]
        var cleaned = name
        for brand in brands {
            cleaned = cleaned.replacingOccurrences(of: brand, with: "", options: .caseInsensitive)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LineScheduleSummaryView: View {
    let line: RailwayLine
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prossime Corse").font(.headline).foregroundColor(appState.theme.dark)
            let trains = linesManager.trains.filter { $0.lineId == line.id }.sorted(by: { $0.departureTime ?? Date() < $1.departureTime ?? Date() })
            if trains.isEmpty {
                Text("Non ci sono corse programmate.")
                    .font(.caption).foregroundColor(appState.theme.medium)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(appState.theme.light.opacity(0.1))
                    .cornerRadius(8)
            } else {
                 ForEach(trains) { train in
                     HStack {
                         Text(train.departureTime ?? Date(), style: .time)
                             .font(.system(.subheadline, design: .monospaced))
                             .foregroundColor(appState.theme.medium)
                         Text(train.name)
                             .font(.subheadline.bold())
                             .foregroundColor(appState.theme.dark)
                         Spacer()
                     }
                     .padding(10)
                     .background(appState.theme.light.opacity(0.3))
                     .cornerRadius(8)
                 }
            }
        }
    }
}

struct StationQuickStats: View {
    let node: Node
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    var onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(node.type.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundColor(appState.theme.dark)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(appState.theme.light)
                    .cornerRadius(6)
                
                if let hub = node.parentHubId {
                    Text("Hub: \(hub)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(appState.theme.medium)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Binari", value: "\(node.platforms ?? 1)")
                CompactInfoRow(label: "Capacità", value: "\(node.capacity ?? 10) treni")
            }
            
            if !node.routingConstraints.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Vincoli").font(.system(size: 11, weight: .bold)).foregroundColor(appState.theme.medium)
                    ForEach(node.routingConstraints) { constraint in
                        HStack(spacing: 8) {
                            let line = linesManager.lines.first { $0.id == constraint.lineId }
                            Circle().fill(line?.uiColor ?? .gray).frame(width: 6, height: 6)
                            Text(line?.name ?? constraint.lineId).font(.system(size: 11, weight: .medium)).foregroundColor(appState.theme.dark)
                            Spacer()
                            Text(constraint.allowedTracks.joined(separator: ", "))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(appState.theme.accent)
                        }
                    }
                }
                .padding(10).background(appState.theme.light.opacity(0.3)).cornerRadius(10)
            }
            
            Button(action: onEdit) {
                Text("Dettagli completi")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(appState.theme.light).foregroundColor(appState.theme.dark).cornerRadius(10)
            }
        }
    }
}

struct TrackQuickStats: View {
    let edge: Edge
    @EnvironmentObject var appState: AppState
    var onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            let fromName = appState.railroad.network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
            let toName = appState.railroad.network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
            
            Text("\(fromName) ↔ \(toName)").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
            
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Distanza", value: String(format: "%.1f km", edge.distance))
                CompactInfoRow(label: "Velocità", value: "\(edge.maxSpeed) km/h")
                CompactInfoRow(label: "Tipo", value: edge.trackType.displayName)
            }
            
            Button(action: onEdit) {
                Text("Modifica Tratta")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(appState.theme.light).foregroundColor(appState.theme.dark).cornerRadius(10)
            }
        }
    }
}

struct CompactInfoRow: View {
    let label: String
    let value: String
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(appState.theme.medium)
            Spacer()
            Text(value).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
        }
    }
}

struct EdgeRowButton: View {
    @EnvironmentObject var appState: AppState
    let edge: Edge
    var body: some View {
        Button(action: { appState.selectedEdgeId = edge.id.uuidString }) {
            let fromName = appState.railroad.network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
            let toName = appState.railroad.network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
            HStack(spacing: 8) {
                Text("🛤")
                Text("\(fromName) ↔ \(toName)")
            }
        }
        .buttonStyle(.plain)
    }
}


extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct SidebarSubButton: View {
    let title: String
    let icon: String
    var isSelected: Bool = false
    let action: () -> Void
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? appState.theme.accent : appState.theme.medium)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? appState.theme.accent : appState.theme.dark)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? appState.theme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(10)
        }
    }
}

struct SidebarButton: View {
    let title: String
    var icon: String? = nil
    var customIcon: String? = nil
    var isSpecial: Bool = false
    let action: () -> Void
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let ci = customIcon {
                    Text(ci).frame(width: 24)
                } else if let si = icon {
                    Image(systemName: si)
                        .font(.system(size: 16))
                        .foregroundColor(isSpecial ? appState.theme.accent : appState.theme.medium)
                        .frame(width: 24)
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSpecial ? appState.theme.accent : appState.theme.dark)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.clear) // Full control
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    let content: Content
    @EnvironmentObject var appState: AppState
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(appState.theme.medium)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            content
        }
    }
}
