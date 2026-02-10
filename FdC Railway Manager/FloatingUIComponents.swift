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
                        appState.sidebarSelection = .network
                        appState.currentMode = .design
                        appState.clearSelection()
                        withAnimation { appState.isInspectorVisible = true }
                    }) {
                        Label("Stazioni", systemImage: "building.2")
                    }
                    
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .network
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
                        Label("Treni", systemImage: "train.side.front.car")
                    }
                }
                
                Section("Dati") {
                    Button(action: { 
                        appState.isSideMenuVisible = false
                        appState.sidebarSelection = .io
                    }) {
                        Label("Import/Export", systemImage: "doc.badge.arrow.up")
                    }
                    
                    Button(action: { 
                        withAnimation { appState.isInspectorVisible.toggle() }
                        appState.isSideMenuVisible = false
                    }) {
                        Label("Ispettore (Menu Destra)", systemImage: "sidebar.right")
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 10, y: 0)
        .transition(.move(edge: .leading))
    }
}

struct ContextualInspector: View {
    @EnvironmentObject var appState: AppState
    @State private var editingStation: Node? = nil
    @State private var editingLine: RailwayLine? = nil
    @State private var editingEdge: Edge? = nil

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
                    if let line = appState.selectedLine {
                        LineQuickStats(line: line, onEdit: { editingLine = line })
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
        .frame(maxHeight: 600) // Floating card, not full height
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.trailing, 20)
        .transition(.move(edge: .trailing).combined(with: .opacity))
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
    
    @ViewBuilder
    private var globalSidebarList: some View {
        switch appState.sidebarSelection {
        case .network:
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stazioni").font(.headline)
                    ForEach(appState.railroad.network.nodes) { node in
                        Button(action: { appState.selectedNodeId = node.id }) {
                            Label(node.name, systemImage: "building.2")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Binari (Tratte)").font(.headline)
                    ForEach(appState.railroad.network.edges) { edge in
                        EdgeRowButton(edge: edge)
                    }
                }
            }
        case .lines:
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Linee").font(.headline)
                    Spacer()
                    Button(action: {
                        let newLine = RailwayLine(id: UUID().uuidString, name: "Nuova Linea", color: "#FF3B30", stations: [], stops: [])
                        appState.railroad.lines.lines.append(newLine)
                        appState.selectedLineId = newLine.id
                    }) {
                        Label("Nuova", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
                
                if appState.railroad.lines.lines.isEmpty {
                    Text("Nessuna linea creata. Clicca su 'Nuova' per iniziare.")
                        .font(.caption).foregroundColor(.secondary).italic()
                } else {
                    ForEach(appState.railroad.lines.lines) { line in
                        Button(action: { appState.selectedLineId = line.id }) {
                            HStack(spacing: 8) {
                                Circle().fill(line.uiColor).frame(width: 8, height: 8)
                                Text(line.name).font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .trains:
            VStack(alignment: .leading, spacing: 15) {
                Text("Elenco Treni").font(.headline)
                ForEach(appState.railroad.lines.trains) { train in
                    Button(action: { appState.selectTrain(train.id) }) {
                        Label(train.name, systemImage: "train.side.front.car")
                    }
                    .buttonStyle(.plain)
                }
            }
        default:
            Text("Seleziona un elemento sulla mappa per dettagli.")
                .foregroundColor(.secondary)
                .italic()
                .padding()
        }
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
                            let line = appState.railroad.lines.lines.first { $0.id == constraint.lineId }
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
