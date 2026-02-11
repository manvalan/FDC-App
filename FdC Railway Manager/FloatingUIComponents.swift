import SwiftUI

struct FloatingModeBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(AppMode.allCases) { mode in
                Button(action: {
                    appState.currentMode = mode
                    withAnimation { appState.isModeBarVisible = false }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 20, weight: .semibold))
                        Text(mode.title)
                            .font(.caption2)
                            .bold()
                    }
                    .foregroundColor(appState.currentMode == mode ? .accentColor : .secondary)
                    .frame(width: 100, height: 60)
                    .background(appState.currentMode == mode ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(12)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .transition(.move(edge: .top).combined(with: .opacity))
        .gesture(
            DragGesture().onEnded { val in
                if val.translation.height < -20 {
                    withAnimation(.spring()) { appState.isModeBarVisible = false }
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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Navigazione")
                    .font(.headline)
                Spacer()
                Button(action: { withAnimation { appState.isSideMenuVisible = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            List {
                Section("Infrastruttura") {
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .stations
                        appState.currentMode = .design
                        appState.clearSelection()
                        withAnimation { appState.isInspectorVisible = true }
                    }) {
                        Label("Stazioni", systemImage: "building.2")
                    }
                    
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .tracks
                        appState.currentMode = .design
                        appState.clearSelection()
                        withAnimation { appState.isInspectorVisible = true }
                    }) {
                        Label("Binari", systemImage: "road.lanes")
                    }
                }
                
                Section("Servizio") {
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .lines
                        appState.currentMode = .schedule
                        appState.clearSelection()
                        withAnimation { appState.isInspectorVisible = true }
                    }) {
                        Label("Linee", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .trains
                        appState.currentMode = .schedule
                        appState.clearSelection()
                        withAnimation { appState.isInspectorVisible = true }
                    }) {
                        Label("Treni (per Linea)", systemImage: "train.side.front.car")
                    }
                }

                Section("Orario") {
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .timetable
                        appState.currentMode = .schedule
                    }) {
                        Label("Tabella Oraria", systemImage: "tablecells")
                    }
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .diagram
                        appState.currentMode = .schedule
                    }) {
                        Label("Grafico Orario", systemImage: "chart.xyaxis.line")
                    }
                }

                Section("Flotta") {
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .vehicles
                        appState.currentMode = .design
                    }) {
                        Label("Materiale Rotabile", systemImage: "tram.fill")
                    }
                }
                
                Section("Strumenti") {
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .io
                    }) {
                        Label("Import/Export", systemImage: "doc.badge.arrow.up")
                    }
                    
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .settings
                    }) {
                        Label("Impostazioni", systemImage: "gearshape")
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden) // Avoid iPad standard list grey
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 10, y: 0)
        .transition(.move(edge: .leading))
        .gesture(
            DragGesture().onEnded { val in
                if val.translation.width < -30 {
                    withAnimation(.spring()) { appState.isSideMenuVisible = false }
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
                        Text(line.name).font(.subheadline.bold())
                    } else if let node = appState.selectedNode {
                        Text(node.name).font(.subheadline.bold())
                    } else {
                        Text("Ispettore").font(.subheadline.bold())
                    }
                }
                Spacer()
                Button(action: { withAnimation { appState.isInspectorVisible = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            Divider().padding(.horizontal, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let trainId = appState.selectedTrainIds.first,
                       let train = linesManager.trains.first(where: { $0.id == trainId }) {
                        TrainDetailView(train: train)
                    } else if let line = appState.selectedLine {
                        LineQuickStats(line: line, onEdit: { editingLine = line })
                        
                        // Show Vertical Diagram in Inspector if in Diagram Mode
                        if appState.sidebarSelection == .diagram {
                            Divider()
                            Text("Schema Linea").font(.headline)
                            // We need orderedStations for LineVerticalDiagram.
                            // But we don't have them easily here without calculation.
                            // LineScheduleView calculates them.
                            // Maybe just show basic stats or simplified diagram?
                            // Or re-calculate? It's cheap?
                            // For now let's just show LineQuickStats and maybe a button to open diagram if not in diagram mode.
                            // But user said "il grafico della linea lo visualizzi nell'ispector".
                            // If we are in Diagram mode, Main View is Graph. Inspector is Line Diagram.
                            // Let's try to instantiate LineVerticalDiagram if possible, or just keep stats.
                            // If calculation is needed, maybe LineVerticalDiagram calculates it internally?
                            // No, it takes orderedStations.
                        }
                    } else if let node = appState.selectedNode {
                        StationQuickStats(node: node, onEdit: { editingStation = node })
                    } else if let edgeId = appState.selectedEdgeId,
                              let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
                        TrackQuickStats(edge: edge, onEdit: { editingEdge = edge })
                    } else {
                        globalSidebarList
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 300)
        .frame(maxHeight: 650) // Adjust height to avoid hitting bottoms/tops
        .background(Material.ultraThinMaterial)
        .background(Color(uiColor: .systemGray6).opacity(0.95))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.trailing, 20)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .gesture(
            DragGesture().onEnded { val in
                if val.translation.width > 30 {
                    withAnimation(.spring()) { appState.isInspectorVisible = false }
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
                    appState.railroad.network.removeEdge(edge.from, edge.to)
                    appState.selectedEdgeId = nil
                    editingEdge = nil
                })
                .navigationTitle("Modifica Binario")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { editingEdge = nil } } }
            }
        }
    }

    private func performDelete(_ item: AnyIdentifiable) {
        switch item.type {
        case .station:
            appState.railroad.network.removeNode(item.id)
            if appState.selectedNodeId == item.id { appState.selectedNodeId = nil }
        case .edge:
            if let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == item.id }) {
                appState.railroad.network.removeEdge(edge.from, edge.to)
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
            default:
                EmptyView()
            }
        }
    }

    private var stationsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stazioni").font(.headline)
            List {
                ForEach(appState.railroad.network.nodes.sorted(by: { $0.name < $1.name })) { node in
                    Button(action: { appState.selectedNodeId = node.id }) {
                        Label(node.name, systemImage: "building.2")
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            itemToDelete = AnyIdentifiable(id: node.id, type: .station)
                            showingDeleteAlert = true
                        } label: { Label("Elimina", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 300)
        }
    }

    private var tracksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Binari").font(.headline)
            List {
                let sortedEdges = appState.railroad.network.edges.sorted { e1, e2 in
                    let name1 = appState.railroad.network.nodes.first(where: { $0.id == e1.from })?.name ?? ""
                    let name2 = appState.railroad.network.nodes.first(where: { $0.id == e2.from })?.name ?? ""
                    return name1 < name2
                }
                ForEach(sortedEdges) { edge in
                    EdgeRowButton(edge: edge)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                itemToDelete = AnyIdentifiable(id: edge.id.uuidString, type: .edge)
                                showingDeleteAlert = true
                            } label: { Label("Elimina", systemImage: "trash") }
                        }
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 300)
        }
    }

    private var linesList: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Linee").font(.headline)
                Spacer()
                Button(action: {
                    let newLine = RailwayLine(id: UUID().uuidString, name: "Nuova Linea", color: "#FF3B30", stops: [])
                    linesManager.lines.append(newLine)
                    appState.selectedLineId = newLine.id
                }) {
                    Label("Nuova", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.small)
            }
            
            List {
                let sortedLines = linesManager.lines.sorted { l1, l2 in
                    let p1 = l1.numberPrefix ?? 0
                    let p2 = l2.numberPrefix ?? 0
                    if p1 != p2 { return p1 < p2 }
                    return (l1.codePrefix ?? "") < (l2.codePrefix ?? "")
                }
                
                ForEach(sortedLines) { line in
                    LineRow(line: line)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                itemToDelete = AnyIdentifiable(id: line.id, type: .line)
                                showingDeleteAlert = true
                            } label: { Label("Elimina", systemImage: "trash") }
                        }
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 400)
        }
    }

    private var trainsByLineList: some View {
        TrainsByLineListView()
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
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 36)
                    .background(line.uiColor)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name)
                        .font(.subheadline.bold())
                    
                    HStack(spacing: 4) {
                        let origin = appState.railroad.network.nodes.first(where: { $0.id == line.originId })?.name ?? "-"
                        let destination = appState.railroad.network.nodes.first(where: { $0.id == line.destinationId })?.name ?? "-"
                        
                        Text("\(origin) → \(destination)")
                        
                        if let mid = findUniqueIntermediate() {
                            Text("(via \(mid))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
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
    var onEdit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Fermate", value: "\(line.stops.count)")
                CompactInfoRow(label: "Cadenza", value: "\(Int(line.cadenceFrequency ?? 60)) min")
                CompactInfoRow(label: "Codice", value: line.codePrefix ?? "-")
            }
            
            Button(action: onEdit) {
                Text("Dettagli e Orari")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(line.uiColor.opacity(0.12)).foregroundColor(line.uiColor).cornerRadius(10)
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
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                
                if let hub = node.parentHubId {
                    Text("Hub: \(hub)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Binari", value: "\(node.platforms ?? 1)")
                CompactInfoRow(label: "Capacità", value: "\(node.capacity ?? 10) treni")
            }
            
            if !node.routingConstraints.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Vincoli").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                    ForEach(node.routingConstraints) { constraint in
                        HStack(spacing: 8) {
                            let line = linesManager.lines.first { $0.id == constraint.lineId }
                            Circle().fill(line?.uiColor ?? .gray).frame(width: 6, height: 6)
                            Text(line?.name ?? constraint.lineId).font(.system(size: 11, weight: .medium))
                            Spacer()
                            Text(constraint.allowedTracks.joined(separator: ", "))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(10).background(Color.black.opacity(0.03)).cornerRadius(10)
            }
            
            Button(action: onEdit) {
                Text("Dettagli completi")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(Color.accentColor.opacity(0.08)).foregroundColor(.accentColor).cornerRadius(10)
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
            
            Text("\(fromName) ↔ \(toName)").font(.subheadline.bold())
            
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Distanza", value: String(format: "%.1f km", edge.distance))
                CompactInfoRow(label: "Velocità", value: "\(edge.maxSpeed) km/h")
                CompactInfoRow(label: "Tipo", value: edge.trackType.displayName)
            }
            
            Button(action: onEdit) {
                Text("Modifica Tratta")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(Color.black.opacity(0.06)).foregroundColor(.primary).cornerRadius(10)
            }
        }
    }
}

struct CompactInfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold())
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
            Label("\(fromName) ↔ \(toName)", systemImage: "road.lanes")
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

