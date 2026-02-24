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
        case .editor: return "pencil"
        }
    }
}

struct FloatingSideMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MENU")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(appState.theme.medium)
                    .tracking(2)
                Spacer()
                
                Button(action: { appState.showPanel(.none) }) {
                     Image(systemName: "xmark")
                         .font(.system(size: 14, weight: .bold))
                         .foregroundColor(appState.theme.medium)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    
                    // GROUP 1: NETWORK & INFRASTRUCTURE
                    Group {
                        MenuRow(title: "Mappa", icon: "map.fill", isSelected: appState.currentMode == .design && appState.sidebarSelection == .stations) {
                            appState.sidebarSelection = .stations
                            appState.currentMode = .design
                            appState.showPanel(.none)
                        }
                        
                        MenuRow(title: "Rete", icon: "building.2.fill", isSelected: appState.sidebarSelection == .stations && appState.activePanel == .inspector) {
                            appState.sidebarSelection = .stations
                            appState.currentMode = .design
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                        
                        MenuRow(title: "Linee", icon: "arrow.triangle.branch", isSelected: appState.sidebarSelection == .lines) {
                             appState.sidebarSelection = .lines
                             appState.currentMode = .design
                             appState.lineInspectorMode = .infrastructure
                             appState.clearSelection()
                             appState.showPanel(.inspector)
                        }
                        
                        MenuRow(title: "Materiale Rotabile", icon: "tram.fill", isSelected: appState.sidebarSelection == .vehicles) {
                            appState.sidebarSelection = .vehicles
                            appState.currentMode = .design
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                    }
                    
                    Divider().padding(.vertical, 8).padding(.horizontal, 20)
                    
                    // GROUP 2: OPERATIONS
                    Group {
                        MenuRow(title: "Orari", icon: "calendar.badge.clock", isSelected: appState.currentMode == .schedule && appState.sidebarSelection == .trains) {
                            appState.currentMode = .schedule
                            appState.sidebarSelection = .trains
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                    }
                    
                    Divider().padding(.vertical, 8).padding(.horizontal, 20)
                    
                    // GROUP 3: SYSTEM
                    Group {
                        MenuRow(title: "Impostazioni", icon: "gearshape.fill", isSelected: appState.sidebarSelection == .settings) {
                            appState.sidebarSelection = .settings
                            appState.showPanel(.inspector)
                        }
                        
                        MenuRow(title: "Import/Export", icon: "square.and.arrow.up", isSelected: appState.sidebarSelection == .io) {
                            appState.sidebarSelection = .io
                            appState.showPanel(.inspector)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(width: Layout.sideMenuWidth)
        .background(appState.theme.surface)
        .cornerRadius(0)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
        .edgesIgnoringSafeArea(.vertical)
    }
}

struct MenuRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 24)
                    .foregroundColor(isSelected ? appState.theme.accent : appState.theme.medium)
                
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? appState.theme.dark : appState.theme.medium)
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(appState.theme.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? appState.theme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}


struct ContextualInspector: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @State private var editingLine: RailwayLine? = nil
    @State private var editingVehicle: RailwayVehicle? = nil
    @State private var isCreatingVehicle: Bool = false
    
    @State private var itemToDelete: AnyIdentifiable? = nil
    @State private var showingDeleteAlert = false
    @State private var isListEditMode: EditMode = .inactive
    @State private var ioTab: Int = 0 

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
                    if appState.isCreatingLine {
                        Text("Crea Nuova Linea").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if appState.isCreatingTrack {
                        Text("Nuovo Binario").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if appState.isScheduleGeneratorVisible {
                        Text("Genera Orari").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if appState.isVehicleManagementVisible {
                        Text("Gestione Flotta").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let line = appState.selectedLine {
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
                
                // Back button (chevron) - hierarchical navigation
                if appState.isSomethingSelected || appState.isScheduleGeneratorVisible || appState.isVehicleManagementVisible || appState.isCreatingTrack || appState.isCreatingLine {
                    Button(action: {
                        if appState.isCreatingLine {
                            appState.isCreatingLine = false
                            appState.lineDraftStations.removeAll()
                            appState.stationPickingCallback = nil
                        } else if appState.isCreatingTrack {
                            appState.isCreatingTrack = false
                        } else if appState.isScheduleGeneratorVisible {
                            appState.isScheduleGeneratorVisible = false
                        } else if appState.isVehicleManagementVisible {
                            appState.isVehicleManagementVisible = false
                        } else if !appState.selectedTrainIds.isEmpty {
                            appState.selectedTrainIds = []
                        } else if appState.selectedNodeId != nil {
                            appState.selectedNodeId = nil
                        } else if appState.selectedEdgeId != nil {
                            appState.selectedEdgeId = nil
                        } else if appState.selectedLineId != nil && (appState.sidebarSelection == .lines || appState.sidebarSelection == .trains) {
                            appState.selectedLineId = nil
                        }
                        // Note: No longer closes the panel when at root
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title3)
                            .foregroundColor(appState.theme.medium)
                    }
                }
                
                // Close button (X) - always closes the inspector
                Button(action: { 
                    appState.showPanel(.none) 
                }) {
                    Image(systemName: "xmark.circle.fill")
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
            
            // Tab selector for "Stazioni" and "Binari"
            if appState.selectedLine == nil && appState.selectedNode == nil && appState.selectedEdgeId == nil && (appState.sidebarSelection == .stations || appState.sidebarSelection == .tracks) {
                HStack(spacing: 0) {
                    Button(action: { appState.sidebarSelection = .stations }) {
                        Text("Rete")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(appState.sidebarSelection == .stations ? appState.theme.accent.opacity(0.12) : Color.clear)
                    }
                    .foregroundColor(appState.sidebarSelection == .stations ? appState.theme.accent : appState.theme.dark)
                    .cornerRadius(10, corners: [.topLeft, .bottomLeft])
                    
                    Button(action: { appState.sidebarSelection = .tracks }) {
                        Text("Binari")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(appState.sidebarSelection == .tracks ? appState.theme.accent.opacity(0.12) : Color.clear)
                    }
                    .foregroundColor(appState.sidebarSelection == .tracks ? appState.theme.accent : appState.theme.dark)
                    .cornerRadius(10, corners: [.topRight, .bottomRight])
                }
                .padding(.horizontal)
                .background(appState.theme.light.opacity(0.4))
                .cornerRadius(10)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            
            if appState.isCreatingLine {
                LineCreationInspectorView()
            } else if appState.isCreatingTrack {
                TrackCreationView(
                    onBack: {
                        appState.isCreatingTrack = false
                        appState.selectedNodeId = nil
                    },
                    onCreate: {
                        appState.isCreatingTrack = false
                    }
                )
            } else if let trainId = appState.selectedTrainIds.first,
               let train = linesManager.trains.first(where: { $0.id == trainId }) {
                ScrollView {
                    TrainDetailView(train: train)
                        .padding(16)
                }
            } else if let line = appState.selectedLine {
                VStack(spacing: 0) {
                    // DEBUG TEST
                    Text("🟢 FLOATING UI - CAMPI QUI 🟢")
                        .font(.title.bold())
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.orange)
                    
                    LineQuickStats(line: line)
                        .padding(16)
                    
                    Divider()
                        .background(appState.theme.line.opacity(0.1))
                        .padding(.horizontal, 16)
                    
                    ZStack {
                        // Base views (Stats & Diagram)
                        VStack(spacing: 0) {
                            switch appState.lineInspectorMode {
                            case .infrastructure:
                                LineInfrastructureView(line: line)
                            case .schedule:
                                LineScheduleSummaryView(line: line)
                                    .padding(16)
                            case .vehicles:
                                LineVehiclesView(lineId: line.id)
                            }
                            Spacer(minLength: 0)
                        }
                        .opacity((appState.isScheduleGeneratorVisible && appState.lineInspectorMode == .schedule) || (appState.isVehicleManagementVisible && appState.lineInspectorMode == .vehicles) ? 0 : 1)
                        
                        // Advanced Overlays
                        if appState.isScheduleGeneratorVisible && appState.lineInspectorMode == .schedule {
                            let _ = print("🔍 [FloatingUIComponents] About to show ScheduleCreationView")
                            let _ = print("   Line ID: \(line.id)")
                            let _ = print("   Line name: \(line.name)")
                            let _ = print("   Line.stops.count: \(line.stops.count)")
                            let _ = print("   Line.stops: \(line.stops)")
                            let _ = print("   Line.stations.count: \(line.stations.count)")
                            let _ = print("   Line.stations: \(line.stations)")
                            
                            ScheduleCreationView(line: line)
                                .id("schedule-\(line.id)-\(line.stops.count)")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(appState.theme.background)
                                .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                        }
                        
                        if appState.isVehicleManagementVisible && appState.lineInspectorMode == .vehicles {
                            LineFleetManagementContent(line: line, manager: linesManager)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(appState.theme.background)
                                .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let node = appState.selectedNode {
                InspectorWrapperView(title: node.name) {
                    StationInlineEditor(
                        node: Binding(
                            get: { appState.selectedNode ?? node },
                            set: { newNode in
                                if let idx = appState.railroad.network.nodes.firstIndex(where: { $0.id == node.id }) {
                                    appState.railroad.network.nodes[idx] = newNode
                                }
                            }
                        )
                    )
                }
            } else if let edgeId = appState.selectedEdgeId,
                      let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
                let fromName = appState.railroad.network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
                let toName = appState.railroad.network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
                InspectorWrapperView(title: "\(fromName) ↔ \(toName)") {
                    TrackInlineEditor(
                        edge: Binding(
                            get: { appState.railroad.network.edges.first(where: { $0.id == edge.id }) ?? edge },
                            set: { newEdge in
                                if let idx = appState.railroad.network.edges.firstIndex(where: { $0.id == edge.id }) {
                                    appState.railroad.network.edges[idx] = newEdge
                                }
                            }
                        )
                    )
                }
            } else if let vehicle = appState.selectedVehicle {
                InspectorWrapperView(title: vehicle.name) {
                    VehicleInspectorView(vehicle: vehicle)
                }
            } else {
                // For lists with native List component, don't wrap in ScrollView
                if appState.sidebarSelection == .lines || appState.sidebarSelection == .stations || appState.sidebarSelection == .tracks || appState.sidebarSelection == .vehicles {
                    NavigationStack {
                        globalSidebarList
                    }
                } else {
                    ScrollView {
                        globalSidebarList
                            .padding(16)
                    }
                }
            }
        }
        .frame(width: Layout.inspectorWidth)
        .frame(maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .background(appState.theme.background)
        .cornerRadius(Layout.panelCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.panelCornerRadius)
                .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(Layout.shadowOpacity), radius: Layout.shadowRadius, x: 0, y: Layout.shadowY)
        .padding(.trailing, Layout.standardPadding)
        .colorScheme(.light)
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
        .sheet(item: $editingLine) { line in
            NavigationStack {
                LineEditView(lineId: line.id)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { editingLine = nil } } }
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(item: $editingVehicle) { vehicle in
            NavigationStack {
                VehicleEditSheet(manager: linesManager, vehicle: vehicle)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fatto") { editingVehicle = nil } } }
            }
        }
        // TrackEditView is now inline, sheet removed
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
            case .io:
                ioPanel
            default:
                EmptyView()
            }
        }
    }
    
    private func elementList(for type: RailElementType) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // HEADER DINAMICO
            HStack {
                Text(type == .station ? "Stazioni" : type == .track ? "Binari" : "Rotte")
                    .font(.headline)
                    .foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    // Logica creazione specifica
                    switch type {
                    case .station: break // appState.isCreatingStation = true
                    case .track: appState.isCreatingTrack = true
                    case .route: break // appState.isCreatingRoute = true
                    }
                }) {
                    Label("Nuovo", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            
            // LISTA ELEMENTI
            VStack(spacing: 8) {
                switch type {
                case .station:
                    let sortedNodes = appState.railroad.network.nodes.sorted(by: { $0.name < $1.name })
                    ForEach(sortedNodes) { node in
                        rowView(title: node.name, icon: "🚉", id: node.id, type: .station)
                    }
                    
                case .track:
                    let sortedEdges = appState.railroad.network.edges // Aggiungi logica di sorting se vuoi
                    ForEach(sortedEdges) { edge in
                        let from = appState.railroad.network.nodes.first(where: { $0.id == edge.from })?.name ?? "N/A"
                        let to = appState.railroad.network.nodes.first(where: { $0.id == edge.to })?.name ?? "N/A"
                        rowView(title: "\(from) ↔ \(to)", icon: "🛤", id: edge.id.uuidString, type: .track)
                    }
                    
                case .route:
                    // Se hai una lista di rotte/linee nel tuo JSON
                    EmptyView()
                    // ForEach(appState.railroad.network.routes ?? []) { route in
                    //     rowView(title: route.name, icon: "🗺️", id: route.id, type: .route)
                    // }
                }
            }
        }
    }

    // COMPONENTE RIGA (per mantenere lo stile identico ovunque)
    private func rowView(title: String, icon: String, id: String, type: RailElementType) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                // Gestione selezione
                if type == .station { appState.selectedNodeId = id }
                else if type == .track { appState.selectedEdgeId = id }
                // else { appState.selectedRouteId = id }
            }) {
                HStack(spacing: 12) {
                    Text(icon).font(.system(size: 16)).frame(width: 24)
                    Text(title).font(.system(size: 13, weight: .medium))
                        .foregroundColor(appState.theme.dark)
                    Spacer()
                }
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(isItemSelected(id, type: type) ? appState.theme.accent.opacity(0.1) : appState.theme.light.opacity(0.3))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                // Logica delete
                let itemType: AnyIdentifiable.ItemType = {
                    switch type {
                    case .station: return .station
                    case .track: return .edge
                    case .route: return .line
                    }
                }()
                itemToDelete = AnyIdentifiable(id: id, type: itemType)
                showingDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(appState.theme.medium)
                    .padding(10)
                    .background(appState.theme.light.opacity(0.4))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    // Helper per lo stato di selezione
    private func isItemSelected(_ id: String, type: RailElementType) -> Bool {
        switch type {
        case .station: return appState.selectedNodeId == id
        case .track: return appState.selectedEdgeId == id
        case .route: return false // appState.selectedRouteId == id
        }
    }
    
    private func nodeBackgroundColor(for nodeId: String) -> Color {
        if appState.selectedNodeId == nodeId {
            return appState.theme.accent.opacity(0.1)
        } else {
            return appState.theme.light.opacity(0.3)
        }
    }
    
    private var stationsList: some View {
        let sortedNodes = appState.railroad.network.sortedNodes
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Stazioni").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    // Future: appState.isCreatingStation = true
                }) {
                    Label("Nuova", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            List {
                ForEach(sortedNodes) { node in
                    StationRowContent(node: node)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isListEditMode == .inactive {
                                appState.selectedNodeId = node.id
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            withAnimation {
                                isListEditMode = (isListEditMode == .active) ? .inactive : .active
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let node = sortedNodes[index]
                        performDelete(AnyIdentifiable(id: node.id, type: .station))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $isListEditMode)
        }
    }

    private var tracksList: some View {
        let sortedEdges = appState.railroad.network.sortedEdges
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Binari").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    appState.isCreatingTrack = true
                }) {
                    Label("Nuovo", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            List {
                ForEach(sortedEdges) { edge in
                    TrackRowContent(edge: edge, network: appState.railroad.network)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isListEditMode == .inactive {
                                appState.selectedEdgeId = edge.id.uuidString
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            withAnimation {
                                isListEditMode = (isListEditMode == .active) ? .inactive : .active
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let edge = sortedEdges[index]
                        performDelete(AnyIdentifiable(id: edge.id.uuidString, type: .edge))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $isListEditMode)
        }
    }

    private var linesList: some View {
        let sortedLines = linesManager.lines.sorted { l1, l2 in
            let p1 = l1.numberPrefix ?? 0
            let p2 = l2.numberPrefix ?? 0
            if p1 != p2 { return p1 < p2 }
            return (l1.codePrefix ?? "") < (l2.codePrefix ?? "")
        }
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Linee").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    print("🔵 Button Nuova Linea clicked")
                    // Activate graphical line creation mode
                    appState.selectedLineId = nil
                    appState.selectedNodeId = nil
                    appState.selectedEdgeId = nil
                    appState.selectedTrainIds = []
                    appState.creationLineId = nil
                    appState.lineDraftStations.removeAll()
                    appState.isCreatingLine = true
                    print("🔵 isCreatingLine set to: \(appState.isCreatingLine)")
                    appState.showPanel(.inspector)
                    print("🔵 activePanel set to: \(appState.activePanel)")
                }) {
                    Label("Nuova", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            List {
                ForEach(sortedLines) { line in
                    LineRowContent(line: line)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isListEditMode == .inactive {
                                appState.selectedLineId = line.id
                                appState.mapVisualizationMode = .scheduler  // Switch to lines visualization mode
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            withAnimation {
                                isListEditMode = (isListEditMode == .active) ? .inactive : .active
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let line = sortedLines[index]
                        performDelete(AnyIdentifiable(id: line.id, type: .line))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $isListEditMode)
        }
    }

    private var trainsByLineList: some View {
        TrainsByLineListView()
    }

    private var vehiclesList: some View {
        RollingStockView(manager: linesManager)
    }

//  Added per requirement:
    private var ioPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tab Selector
            HStack(spacing: 0) {
                Button(action: { ioTab = 0 }) {
                    Text("Esportazione")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ioTab == 0 ? appState.theme.accent.opacity(0.1) : Color.clear)
                        .foregroundColor(ioTab == 0 ? appState.theme.accent : appState.theme.medium)
                }
                .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                
                Button(action: { ioTab = 1 }) {
                    Text("Importazione")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ioTab == 1 ? appState.theme.accent.opacity(0.1) : Color.clear)
                        .foregroundColor(ioTab == 1 ? appState.theme.accent : appState.theme.medium)
                }
                .cornerRadius(8, corners: [.topRight, .bottomRight])
            }
            .background(appState.theme.light.opacity(0.3))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if ioTab == 0 {
                exportSection
            } else {
                automationsSection
            }

            Spacer()
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Esporta Dati").font(.headline).foregroundColor(appState.theme.dark)
            
            Button(action: exportNodesAndEdges) {
                Label("Rete (Stazioni+Binari) JSON", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(appState.theme.accent)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
    }

    private var automationsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. SOSTE STANDARD
                VStack(alignment: .leading, spacing: 12) {
                    Text("Soste Standard").font(.headline).foregroundColor(appState.theme.dark)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RuleRow(icon: "🚉", label: "Interscambio", value: "5 min")
                        RuleRow(icon: "■", label: "Quadrato Pieno / Stella", value: "3 min")
                        RuleRow(icon: "□", label: "Quadrato Vuoto", value: "2 min")
                        RuleRow(icon: "●", label: "Cerchio (Tutti)", value: "1 min")
                    }
                    .padding(12)
                    .background(appState.theme.light.opacity(0.2))
                    .cornerRadius(12)
                    
                    Button(action: {
                        linesManager.applyStandardDwellsToAllTrains()
                    }) {
                        Label("Applica Soste Standard", systemImage: "timer")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(appState.theme.accent)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // 2. PRIORITA' BINARI
                VStack(alignment: .leading, spacing: 12) {
                    Text("Priorità Binari").font(.headline).foregroundColor(appState.theme.dark)
                    Text("Assegna i binari in base alla direzione e alle preferenze di linea impostate nelle stazioni.")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                    
                    Button(action: {
                        linesManager.autoAssignTracksToAllTrains()
                    }) {
                        Label("Ottimizza Binari", systemImage: "arrow.triangle.swap")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(appState.theme.dark)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private struct RuleRow: View {
        let icon: String
        let label: String
        let value: String
        var body: some View {
            HStack {
                Text(icon).frame(width: 20)
                Text(label).font(.caption)
                Spacer()
                Text(value).font(.caption.bold())
            }
        }
    }

    private func exportNodesAndEdges() {
        let nodes = appState.railroad.network.nodes
        let edges = appState.railroad.network.edges
        guard let data = NetworkIOExporter.shared.exportStationsAndTracksJSON(nodes: nodes, edges: edges) else { return }
        let fileName = "network_stations_tracks.json"

        #if canImport(UIKit)
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try data.write(to: tmpURL, options: .atomic)
            let activityVC = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.keyWindow?.rootViewController {
                root.present(activityVC, animated: true)
            } else if let root = UIApplication.shared.windows.first?.rootViewController {
                root.present(activityVC, animated: true)
            }
        } catch {
            print("Export error: \(error)")
        }
        #else
        // Fallback: write to Desktop
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").appendingPathComponent(fileName)
        do {
            try data.write(to: desktop, options: .atomic)
            print("✅ Esportato su Desktop: \(desktop.path)")
        } catch {
            print("Export error: \(error)")
        }
        #endif
    }
}

struct LineRow: View {
    let line: RailwayLine
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        Button(action: { 
            appState.selectedLineId = line.id
            appState.mapVisualizationMode = .scheduler  // Switch to lines visualization mode
        }) {
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

// LineRowContent - Plain view version without button wrapper for List with swipe actions
struct LineRowContent: View {
    let line: RailwayLine
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
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
    @EnvironmentObject var linesManager: LinesManager
    @State private var longPressMode: AppState.LineInspectorMode? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Mode Selector
            HStack(spacing: 4) {
                ForEach(AppState.LineInspectorMode.allCases) { mode in
                    Button(action: {
                        // Don't execute tap action if long press just completed on this mode
                        if longPressMode != mode {
                            withAnimation(.spring(response: 0.3)) { 
                                appState.lineInspectorMode = mode 
                                appState.isLineEditing = (mode == .infrastructure)
                                appState.isScheduleGeneratorVisible = false
                                appState.isVehicleManagementVisible = false
                            }
                        }
                        longPressMode = nil
                    }) {
                        ZStack {
                            if appState.lineInspectorMode == mode {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(appState.theme.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(appState.lineInspectorMode == mode ? .white : appState.theme.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .onEnded { _ in
                                longPressMode = mode
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.4)) {
                                    appState.lineInspectorMode = mode
                                    if mode == .infrastructure {
                                        appState.isLineEditing = true
                                        appState.isScheduleGeneratorVisible = false
                                        appState.isVehicleManagementVisible = false
                                    } else if mode == .schedule {
                                        appState.creationLineId = line.id
                                        appState.isScheduleGeneratorVisible = true
                                        appState.isVehicleManagementVisible = false
                                    } else if mode == .vehicles {
                                        appState.isVehicleManagementVisible = true
                                        appState.isScheduleGeneratorVisible = false
                                    }
                                }
                            }
                    )
                }
            }
            .padding(4)
            .background(appState.theme.light.opacity(0.3))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                CompactInfoRow(label: "Fermate", value: "\(line.stops.count)")
                
                Divider()
                    .padding(.vertical, 8)
                
                // LINE PROPERTIES EDITOR
                Text("PROPRIETÀ LINEA")
                    .font(.caption.bold())
                    .foregroundColor(appState.theme.medium)
                    .padding(.bottom, 4)
                
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nome")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("Nome linea", text: Binding(
                        get: { linesManager.lines.first(where: { $0.id == line.id })?.name ?? line.name },
                        set: { newName in
                            if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                                linesManager.lines[idx].name = newName
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                // Prefix and Code
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prefisso")
                            .font(.caption2.bold())
                            .foregroundColor(appState.theme.medium)
                        TextField("RE", text: Binding(
                            get: { linesManager.lines.first(where: { $0.id == line.id })?.codePrefix ?? "" },
                            set: { newPrefix in
                                if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                                    linesManager.lines[idx].codePrefix = newPrefix.isEmpty ? nil : newPrefix
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Codice")
                            .font(.caption2.bold())
                            .foregroundColor(appState.theme.medium)
                        TextField("5", value: Binding(
                            get: { linesManager.lines.first(where: { $0.id == line.id })?.numberPrefix ?? 0 },
                            set: { newCode in
                                if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                                    linesManager.lines[idx].numberPrefix = newCode == 0 ? nil : newCode
                                }
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    }
                }
                
                // Color
                HStack {
                    Text("Colore")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { 
                            let currentLine = linesManager.lines.first(where: { $0.id == line.id }) ?? line
                            return Color(hex: currentLine.color ?? "") ?? .blue
                        },
                        set: { newColor in
                            if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }),
                               let hex = newColor.toHex() {
                                linesManager.lines[idx].color = hex
                            }
                        }
                    ))
                    .labelsHidden()
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press on the entire line inspector opens train creation when in Schedule mode
            if appState.lineInspectorMode == .schedule {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.4)) {
                    appState.creationLineId = line.id
                    appState.isScheduleGeneratorVisible = true
                    appState.isVehicleManagementVisible = false
                }
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
            Text("Mezzi in servizio")
                .font(.headline)
                .foregroundColor(appState.theme.dark)
                .padding(.horizontal)
            
            let assignedTrains = linesManager.trains.filter { $0.lineId == lineId }
            let groupedTrains = Dictionary(grouping: assignedTrains) { train -> String in
                if let vehicleId = train.vehicleId,
                   let vehicle = linesManager.vehicles.first(where: { $0.id == vehicleId }) {
                    return cleanModelName(vehicle.name)
                }
                return "Non Assegnati"
            }
            
            if assignedTrains.isEmpty {
                VStack(spacing: 8) {
                    Text("Nessun treno programmato.")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                    Text("Premi a lungo su 'Orario' per generare corse.")
                        .font(.system(size: 9))
                        .foregroundColor(appState.theme.medium.opacity(0.7))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(appState.theme.light.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
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
                                                HStack {
                                                    Text("Corsa \(train.number ?? 0)")
                                                    if let dep = train.departureTime {
                                                        Text("• \(dep, style: .time)")
                                                    }
                                                }
                                                .font(.system(size: 10))
                                                .foregroundColor(appState.theme.medium)
                                            }
                                            Spacer()
                                            
                                            if train.vehicleId == nil {
                                                Text("NON ASS.")
                                                    .font(.system(size: 8, weight: .black))
                                                    .padding(4)
                                                    .background(Color.red.opacity(0.1))
                                                    .foregroundColor(.red)
                                                    .cornerRadius(4)
                                            }
                                            
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
                    .padding(.horizontal)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AGGIUNTO: Tasto per entrare in modalità generazione/modifica orario
                Button(action: {
                    withAnimation {
                        appState.creationLineId = line.id
                    }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("GESTISCI ORARIO")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(appState.theme.accent)
                    .cornerRadius(12)
                    .shadow(color: appState.theme.accent.opacity(0.3), radius: 5, y: 3)
                }
                .buttonStyle(.plain)
                
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
                         LazyVStack(spacing: 8) {
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

struct MetricView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            Text(value).font(.system(.subheadline, design: .rounded).bold())
        }
    }
}

struct StationInlineEditor: View {
    @Binding var node: Node
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    @State private var localPlatforms: Int = 2
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var isEditingCoordinates: Bool = false
    
    private var availableHubs: [RailwayNode] {
        appState.railroad.network.nodes.filter { $0.id != node.id }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(appState.theme.accent)
                    .frame(width: 40, height: 40)
                    .background(appState.theme.accent.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.headline)
                        .foregroundColor(appState.theme.dark)
                    Text(node.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
                Spacer()
            }
            .padding()
            .background(appState.theme.surface)
            .cornerRadius(12)
            
            // Quick Stats (always visible)
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Binari", value: "\(node.platforms ?? 1)")
                CompactInfoRow(label: "Capacità", value: "\(node.capacity ?? 10) treni")
                if let hub = node.parentHubId {
                    CompactInfoRow(label: "Hub", value: appState.railroad.network.nodes.first(where: { $0.id == hub })?.name ?? hub)
                }
                if let lat = node.latitude, let lon = node.longitude {
                    CompactInfoRow(label: "Coordinate", value: String(format: "%.4f, %.4f", lat, lon))
                }
            }
            .padding()
            .background(appState.theme.light.opacity(0.3))
            .cornerRadius(10)
            
            // Edit mode toggle hint
            if !appState.isInspectorEditingMode {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(appState.theme.accent)
                    Text("Tieni premuto per 1 secondo per modificare")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(appState.theme.accent.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Editable fields (only when edit mode is active)
            Group {
                // Station Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOME STAZIONE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    TextField("Nome", text: $node.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Type
                VStack(alignment: .leading, spacing: 6) {
                    Text("TIPO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Picker("Tipo", selection: $node.type) {
                        Text("Stazione").tag(RailwayNode.NodeType.station)
                        Text("Interscambio").tag(RailwayNode.NodeType.interchange)
                        Text("Deposito").tag(RailwayNode.NodeType.depot)
                        Text("Bivio").tag(RailwayNode.NodeType.junction)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Visual Symbol
                VStack(alignment: .leading, spacing: 6) {
                    Text("SIMBOLO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Picker("Simbolo", selection: $node.visualType) {
                        Text("Default").tag(RailwayNode.StationVisualType?.none)
                        ForEach(RailwayNode.StationVisualType.allCases) { type in
                            Text(type.rawValue).tag(RailwayNode.StationVisualType?.some(type))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Custom Color
                VStack(alignment: .leading, spacing: 6) {
                    Text("COLORE PERSONALIZZATO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    
                    HStack(spacing: 12) {
                        // Color preview
                        if let colorHex = node.customColor, let color = Color(hex: colorHex) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(appState.theme.line, lineWidth: 1)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(appState.theme.light)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(appState.theme.line, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Hex color (es: #FF5733)", text: Binding(
                                get: { node.customColor ?? "" },
                                set: { newValue in
                                    node.customColor = newValue.isEmpty ? nil : newValue
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            
                            // Quick color presets
                            HStack(spacing: 6) {
                                ForEach(["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#5856D6", "#AF52DE"], id: \.self) { colorHex in
                                    if let color = Color(hex: colorHex) {
                                        Button(action: {
                                            node.customColor = colorHex
                                        }) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 28, height: 28)
                                                .overlay(
                                                    Circle()
                                                        .stroke(node.customColor == colorHex ? appState.theme.accent : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    
                    if node.customColor != nil {
                        Button(action: {
                            node.customColor = nil
                        }) {
                            Text("Rimuovi colore personalizzato")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Platforms
                VStack(alignment: .leading, spacing: 6) {
                    Text("BINARI")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Stepper(value: $localPlatforms, in: 1...20) {
                        HStack {
                            Text("Numero di binari")
                                .foregroundColor(appState.theme.dark)
                            Spacer()
                            Text("\(localPlatforms)")
                                .fontWeight(.bold)
                                .foregroundColor(appState.theme.accent)
                        }
                    }
                    .onChange(of: localPlatforms) { _, newValue in
                        node.platforms = newValue
                    }
                }
                
                // Taktfahrplan Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("ORARIO TIPO (TAKTMORE)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    
                    Text("Convergenza oraria - garantisce corrispondenze tra linee")
                        .font(.caption2)
                        .foregroundColor(appState.theme.medium)
                    
                    Picker("Minuto Takt", selection: $node.taktMinutes) {
                        Text("Off").tag(Int?.none)
                        Text(":00").tag(Int?.some(0))
                        Text(":15").tag(Int?.some(15))
                        Text(":30").tag(Int?.some(30))
                        Text(":45").tag(Int?.some(45))
                    }
                    .pickerStyle(.segmented)
                }
                .padding(10)
                .background(appState.theme.accent.opacity(0.05))
                .cornerRadius(10)
                
                // Hub
                VStack(alignment: .leading, spacing: 6) {
                    Text("HUB")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Picker("Hub", selection: $node.parentHubId) {
                        Text("Nessun Hub").tag(String?.none)
                        ForEach(availableHubs) { hub in
                            Text(hub.name).tag(String?.some(hub.id))
                        }
                    }
                }
                
                // Hub Offset (only if hub is selected)
                if node.parentHubId != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("POSIZIONE NELL'HUB")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                        Picker("Posizione", selection: $node.hubOffsetDirection) {
                            Text("Standard").tag(RailwayNode.HubOffsetDirection?.none)
                            ForEach(RailwayNode.HubOffsetDirection.allCases) { dir in
                                Text(dir.rawValue).tag(RailwayNode.HubOffsetDirection?.some(dir))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Coordinates
                VStack(alignment: .leading, spacing: 6) {
                    Text("COORDINATE GPS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    
                    HStack {
                        Text("Lat").font(.caption).foregroundColor(appState.theme.medium).frame(width: 30, alignment: .leading)
                        TextField("0.0", text: $latitudeText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                            .onSubmit {
                                if let value = Double(latitudeText) {
                                    node.latitude = value
                                }
                            }
                    }
                    
                    HStack {
                        Text("Lon").font(.caption).foregroundColor(appState.theme.medium).frame(width: 30, alignment: .leading)
                        TextField("0.0", text: $longitudeText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                            .onSubmit {
                                if let value = Double(longitudeText) {
                                    node.longitude = value
                                }
                            }
                    }
                    
                    Text("Puoi anche trascinare la stazione sulla mappa (long press)")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
            }
            .disabled(!appState.isInspectorEditingMode)
            .opacity(appState.isInspectorEditingMode ? 1 : 0.5)
        }
        .onAppear {
            localPlatforms = node.platforms ?? 2
            if let lat = node.latitude {
                latitudeText = String(lat)
            }
            if let lon = node.longitude {
                longitudeText = String(lon)
            }
        }
        .onChange(of: node.id) { _, _ in
            // Refresh when station changes
            if let lat = node.latitude {
                latitudeText = String(lat)
            }
            if let lon = node.longitude {
                longitudeText = String(lon)
            }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            appState.isInspectorEditingMode.toggle()
        }
    }
}

struct TrackInlineEditor: View {
    @Binding var edge: RailwayEdge
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    
    private var fromStation: RailwayNode? {
        appState.railroad.network.nodes.first(where: { $0.id == edge.from })
    }
    
    private var toStation: RailwayNode? {
        appState.railroad.network.nodes.first(where: { $0.id == edge.to })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Quick stats sempre visibili
            VStack(alignment: .leading, spacing: 12) {
                // Stazioni
                HStack(spacing: 16) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 24))
                        .foregroundColor(appState.theme.accent)
                        .frame(width: 40, height: 40)
                        .background(appState.theme.accent.opacity(0.1))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fromStation?.name ?? "Stop \(edge.from)")
                            .font(.subheadline)
                            .foregroundColor(appState.theme.dark)
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundColor(appState.theme.medium)
                            .padding(.leading, 4)
                        Text(toStation?.name ?? "Stop \(edge.to)")
                            .font(.subheadline)
                            .foregroundColor(appState.theme.dark)
                    }
                    Spacer()
                }
                .padding()
                .background(appState.theme.surface)
                .cornerRadius(12)
                
                // Tipo Binario
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIPO BINARIO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                        .padding(.leading, 4)
                    
                    Menu {
                        Button(action: { updateTrackType(.single) }) {
                            Label("Binario Singolo", systemImage: "1.circle")
                        }
                        Button(action: { updateTrackType(.double) }) {
                            Label("Doppio Binario", systemImage: "2.circle")
                        }
                        Button(action: { updateTrackType(.highSpeed) }) {
                            Label("Alta Velocità", systemImage: "bolt.fill")
                        }
                        Button(action: { updateTrackType(.regional) }) {
                            Label("Linea Regionale", systemImage: "tram")
                        }
                    } label: {
                        HStack {
                            trackIcon(for: edge.trackType)
                            Text(trackLabel(for: edge.trackType))
                                .foregroundColor(appState.theme.dark)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(appState.theme.medium)
                        }
                        .padding()
                        .background(appState.theme.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .disabled(!appState.isInspectorEditingMode)
                }
                
                // Parametri Fisici
                VStack(alignment: .leading, spacing: 8) {
                    Text("PARAMETRI FISICI")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 12) {
                        // Distanza
                        HStack {
                            Text("Distanza").foregroundColor(appState.theme.dark)
                            Spacer()
                            TextField("0", value: $edge.distance, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .disabled(!appState.isInspectorEditingMode)
                            Text("km").foregroundColor(appState.theme.medium).font(.caption)
                        }
                        Divider()
                        // Velocità Max
                        HStack {
                            Text("Vel. Max").foregroundColor(appState.theme.dark)
                            Spacer()
                            TextField("0", value: $edge.maxSpeed, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .disabled(!appState.isInspectorEditingMode)
                            Text("km/h").foregroundColor(appState.theme.medium).font(.caption)
                        }
                        Divider()
                        // Capacità
                        HStack {
                            Text("Capacità").foregroundColor(appState.theme.dark)
                            Spacer()
                            TextField("0", value: $edge.capacity, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .disabled(!appState.isInspectorEditingMode)
                            Text("t/h").foregroundColor(appState.theme.medium).font(.caption)
                        }
                    }
                    .padding()
                    .background(appState.theme.surface)
                    .cornerRadius(12)
                }
                
                // Geometry Points (Punti Intermedi Personalizzati)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("GEOMETRIA PERSONALIZZATA")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                            .padding(.leading, 4)
                        
                        Spacer()
                        
                        if appState.isInspectorEditingMode {
                            Button(action: addGeometryPoint) {
                                Label("Aggiungi", systemImage: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(appState.theme.accent)
                            }
                        }
                    }
                    
                    if let points = edge.geometryPoints, !points.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(appState.theme.accent)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Punto \(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundColor(appState.theme.dark)
                                        Text("Lat: \(point.latitude, specifier: "%.6f"), Lon: \(point.longitude, specifier: "%.6f")")
                                            .font(.system(size: 10))
                                            .foregroundColor(appState.theme.medium)
                                    }
                                    
                                    Spacer()
                                    
                                    if appState.isInspectorEditingMode {
                                        Button(action: { removeGeometryPoint(at: index) }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(appState.theme.surface.opacity(0.5))
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        Text("Nessun punto intermedio. Il percorso viene calcolato automaticamente.")
                            .font(.caption)
                            .foregroundColor(appState.theme.medium)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(appState.theme.surface.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(appState.theme.backgroundSecondary)
                .cornerRadius(12)
                
                // Danger Zone (solo in modalità edit)
                if appState.isInspectorEditingMode {
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Elimina Binario")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                    .padding(.top, 10)
                }
            }
            
            // Edit mode indicator
            if appState.isInspectorEditingMode {
                HStack {
                    Spacer()
                    Text("Modalità Modifica Attiva")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Spacer()
                    Text("Long press per modificare")
                        .font(.caption2)
                        .foregroundColor(appState.theme.medium)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(appState.theme.light.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.0) {
            appState.isInspectorEditingMode.toggle()
        }
        .alert("Conferma eliminazione", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                appState.selectedEdgeId = nil
            }
        } message: {
            Text("Sei sicuro di voler rimuovere questo binario? La connessione tra le stazioni verrà interrotta.")
        }
    }
    
    private func updateTrackType(_ type: RailwayEdge.TrackType) {
        edge.trackType = type
        updateCapacity(for: type)
    }
    
    private func updateCapacity(for type: RailwayEdge.TrackType) {
        switch type {
        case .single: edge.capacity = 6
        case .double: edge.capacity = 24
        case .highSpeed: edge.capacity = 15
        case .regional: edge.capacity = 6
        }
        
        switch type {
        case .single: edge.maxSpeed = Int(appState.singleTrackMaxSpeed)
        case .double: edge.maxSpeed = Int(appState.doubleTrackMaxSpeed)
        case .highSpeed: edge.maxSpeed = Int(appState.highSpeedTrackMaxSpeed)
        case .regional: edge.maxSpeed = Int(appState.regionalTrackMaxSpeed)
        }
    }
    
    private func trackLabel(for type: RailwayEdge.TrackType) -> String {
        switch type {
        case .single: return "Binario Singolo"
        case .double: return "Doppio Binario"
        case .highSpeed: return "Alta Velocità"
        case .regional: return "Linea Regionale"
        }
    }
    
    private func trackIcon(for type: RailwayEdge.TrackType) -> Image {
        switch type {
        case .single: return Image(systemName: "1.circle")
        case .double: return Image(systemName: "2.circle")
        case .highSpeed: return Image(systemName: "bolt.fill")
        case .regional: return Image(systemName: "tram")
        }
    }
    
    private func addGeometryPoint() {
        // Calculate a midpoint between from and to stations as default
        guard let fromNode = fromStation, let toNode = toStation,
              let fromLat = fromNode.latitude, let fromLon = fromNode.longitude,
              let toLat = toNode.latitude, let toLon = toNode.longitude else { return }
        
        let midLat = (fromLat + toLat) / 2.0
        let midLon = (fromLon + toLon) / 2.0
        
        let newPoint = Edge.GeometryPoint(latitude: midLat, longitude: midLon)
        
        if edge.geometryPoints == nil {
            edge.geometryPoints = []
        }
        edge.geometryPoints?.append(newPoint)
    }
    
    private func removeGeometryPoint(at index: Int) {
        edge.geometryPoints?.remove(at: index)
        if edge.geometryPoints?.isEmpty == true {
            edge.geometryPoints = nil
        }
    }
}

// MARK: - Station Row Content
struct StationRowContent: View {
    let node: Node
    @EnvironmentObject var appState: AppState
    
    private var nodeColor: Color {
        if let customColor = node.customColor, let color = Color(hex: customColor) {
            return color
        }
        switch node.type {
        case .station: return .blue
        case .interchange: return .orange
        case .depot: return .gray
        case .junction: return .green
        }
    }
    
    @ViewBuilder
    private func stationSymbol(size: CGFloat = 28) -> some View {
        // Interchange stations use double red circle
        if node.type == .interchange {
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: size, height: size)
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: size * 0.6, height: size * 0.6)
            }
        } else {
            let color = nodeColor
            
            switch node.visualType ?? .filledCircle {
            case .filledCircle:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            case .emptyCircle:
                Circle()
                    .stroke(color, lineWidth: 3)
                    .frame(width: size, height: size)
            case .filledSquare:
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: size, height: size)
            case .emptySquare:
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 3)
                    .frame(width: size, height: size)
            case .filledStar:
                Image(systemName: "star.fill")
                    .foregroundColor(color)
                    .font(.system(size: size))
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(nodeColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                stationSymbol(size: 28)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                let typeStr = node.type.localizedName
                if let platforms = node.platforms {
                    Text("\(typeStr) • \(platforms) " + "platforms".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text(typeStr)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.selectedNodeId == node.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedNodeId == node.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Inspector Wrapper with Back Button

struct InspectorWrapperView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 12) {
                Button(action: {
                    appState.selectedNodeId = nil
                    appState.selectedEdgeId = nil
                    appState.selectedVehicleId = nil
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(appState.theme.accent)
                        .frame(width: 32, height: 32)
                        .background(appState.theme.accent.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(appState.theme.dark)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(appState.theme.background)
            
            Divider()
            
            ScrollView {
                content()
                    .padding(16)
            }
        }
    }
}

// MARK: - Track Row Content

struct TrackRowContent: View {
    let edge: Edge
    let network: NetworkModel
    @EnvironmentObject var appState: AppState
    
    private var trackColor: Color {
        edge.trackType.color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge icon with track symbol
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(trackColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                NetworkSymbols.trackSymbol(for: edge.trackType, width: 30, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                let fromName = network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
                let toName = network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
                
                Text("\(fromName) ↔ \(toName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                Text(String(format: "%.1f km • %d km/h", edge.distance, edge.maxSpeed))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.selectedEdgeId == edge.id.uuidString ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedEdgeId == edge.id.uuidString ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
    }
}

struct FerroviaRowContent: View {
    let ferrovia: Ferrovia
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge icon with ferrovia color
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ferrovia.uiColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                NetworkSymbols.ferroviaSymbol(color: ferrovia.color, size: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ferrovia.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                Text("\(ferrovia.stationIds.count) stazioni")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.selectedFerroviaId == ferrovia.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedFerroviaId == ferrovia.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
    }
}

struct LineInfrastructureView: View {
    let line: RailwayLine
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Line properties editor (always visible in infrastructure mode)
                LinePropertyEditor(line: line)
                
                // Track Diagram
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
                    externalSelectedEdgeID: $appState.selectedEdgeId,
                    isSidebarEditMode: $appState.isLineEditing
                )
            }
            .padding(.vertical, 16)
        }
    }
}

struct LinePropertyEditor: View {
    let line: RailwayLine
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        let _ = print("🔍 [LinePropertyEditor] Rendering for line: \(line.name)")
        return VStack(alignment: .leading, spacing: 12) {
            Text("PROPRIETÀ LINEA")
                .font(.caption.bold())
                .foregroundColor(appState.theme.medium)
            
            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Nome")
                    .font(.caption2.bold())
                    .foregroundColor(appState.theme.medium)
                TextField("Nome linea", text: lineNameBinding)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Prefix and Code
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prefisso")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("RE", text: linePrefixBinding)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codice")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("5", value: lineCodeBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }
            
            // Color
            HStack {
                Text("Colore")
                    .font(.caption2.bold())
                    .foregroundColor(appState.theme.medium)
                Spacer()
                ColorPicker("", selection: lineColorBinding)
                    .labelsHidden()
            }
            
            Divider()
                .padding(.top, 4)
        }
        .padding(16)
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private var lineNameBinding: Binding<String> {
        Binding(
            get: { 
                linesManager.lines.first(where: { $0.id == line.id })?.name ?? line.name
            },
            set: { newName in
                if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                    linesManager.lines[idx].name = newName
                    // Force UI update
                    appState.selectedLineId = line.id
                }
            }
        )
    }
    
    private var linePrefixBinding: Binding<String> {
        Binding(
            get: { 
                linesManager.lines.first(where: { $0.id == line.id })?.codePrefix ?? line.codePrefix ?? ""
            },
            set: { newPrefix in
                if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                    linesManager.lines[idx].codePrefix = newPrefix.isEmpty ? nil : newPrefix
                    // Force UI update
                    appState.selectedLineId = line.id
                }
            }
        )
    }
    
    private var lineCodeBinding: Binding<Int> {
        Binding(
            get: { 
                linesManager.lines.first(where: { $0.id == line.id })?.numberPrefix ?? line.numberPrefix ?? 0
            },
            set: { newCode in
                if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }) {
                    linesManager.lines[idx].numberPrefix = newCode == 0 ? nil : newCode
                    // Force UI update
                    appState.selectedLineId = line.id
                }
            }
        )
    }
    
    private var lineColorBinding: Binding<Color> {
        Binding(
            get: { 
                let currentLine = linesManager.lines.first(where: { $0.id == line.id }) ?? line
                return Color(hex: currentLine.color ?? "") ?? .blue
            },
            set: { newColor in
                if let idx = linesManager.lines.firstIndex(where: { $0.id == line.id }),
                   let hex = newColor.toHex() {
                    linesManager.lines[idx].color = hex
                    // Force UI update
                    appState.selectedLineId = line.id
                }
            }
        )
    }
}

