import SwiftUI
import Combine

struct ModernInspectorPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @State private var isListEditMode: EditMode = .inactive
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
                .background(appState.theme.line.opacity(0.2))
                .padding(.horizontal, 16)
            
            tabSelectorView
            
            contentView
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
    }
    
    private var headerView: some View {
        HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if appState.isShowingSettings {
                        Text("Impostazioni").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let previewData = appState.optimizedTimesPreviewData {
                        Text("Orari Ottimizzati").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let _ = appState.schedulePreviewTrains {
                        Text("Anteprima Orari").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if appState.isCreatingLine {
                        Text("Crea Nuova Relazione").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let lineId = appState.creationRouteId, let line = appState.railroad.lines.routes.first(where: { $0.id == lineId }) {
                        Text("Genera Orari: \(line.name)").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let node = appState.selectedNode {
                        Text(node.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let line = appState.selectedRoute {
                        Text(line.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if appState.selectedEdgeId != nil {
                        Text("Binario").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if !appState.selectedTrainIds.isEmpty {
                        Text("Treno").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else {
                        Text("Ispettore").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    }
                }
                Spacer()
                
                // Back button
                let showBack = appState.isShowingSettings || appState.optimizedTimesPreviewData != nil || appState.schedulePreviewTrains != nil || appState.creationRouteId != nil || appState.selectedNodeId != nil || appState.selectedEdgeId != nil || appState.selectedRouteId != nil || !appState.selectedTrainIds.isEmpty || appState.isCreatingLine
                if showBack {
                    Button(action: {
                        if appState.isShowingSettings {
                            appState.isShowingSettings = false
                        } else if appState.optimizedTimesPreviewData != nil {
                            appState.optimizedTimesPreviewData = nil
                        } else if appState.schedulePreviewTrains != nil {
                            appState.schedulePreviewTrains = nil
                            appState.schedulePreviewRoute = nil
                        } else if appState.creationRouteId != nil {
                            appState.creationRouteId = nil
                        } else if appState.isCreatingLine {
                            appState.isCreatingLine = false
                            appState.lineDraftStations.removeAll()
                            appState.stationPickingCallback = nil
                        } else {
                            // Clear individual selections but keep inspector open
                            appState.selectedNodeId = nil
                            appState.selectedEdgeId = nil
                            appState.selectedRouteId = nil
                            appState.selectedInfraLineId = nil
                            appState.selectedTrainIds.removeAll()
                            appState.selectedVehicleId = nil
                        }
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title3)
                            .foregroundColor(appState.theme.medium)
                    }
                }
                
                // Close button
                Button(action: {
                    // Reset creationRouteId if we're showing schedule creation
                    if appState.creationRouteId != nil {
                        appState.creationRouteId = nil
                    }
                    
                    // Clear selections when closing the main inspector panel
                    // Note: This overlay only appears in non-editor modes (see ContentView.swift line 43)
                    // so we always clear selections here
                    appState.clearSelection()
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
    }
    
    @ViewBuilder
    private var tabSelectorView: some View {
        let showTabs = appState.selectedRoute == nil && appState.selectedNode == nil && appState.selectedEdgeId == nil && (appState.sidebarSelection == .stations || appState.sidebarSelection == .tracks || appState.sidebarSelection == .infraLines)
        if showTabs {
                HStack(spacing: 0) {
                    Button(action: { appState.sidebarSelection = .stations }) {
                        Text("Stazioni")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(appState.sidebarSelection == .stations ? appState.theme.accent.opacity(0.12) : Color.clear)
                    }
                    .foregroundColor(appState.sidebarSelection == .stations ? appState.theme.accent : appState.theme.dark)
                    .cornerRadius(10, corners: [.topLeft, .bottomLeft])
                    
                    Button(action: { appState.sidebarSelection = .tracks }) {
                        Text("Binari")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(appState.sidebarSelection == .tracks ? appState.theme.accent.opacity(0.12) : Color.clear)
                    }
                    .foregroundColor(appState.sidebarSelection == .tracks ? appState.theme.accent : appState.theme.dark)
                    
                    Button(action: { appState.sidebarSelection = .infraLines }) {
                        Text("Linee")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(appState.sidebarSelection == .infraLines ? appState.theme.accent.opacity(0.12) : Color.clear)
                    }
                    .foregroundColor(appState.sidebarSelection == .infraLines ? appState.theme.accent : appState.theme.dark)
                    .cornerRadius(10, corners: [.topRight, .bottomRight])
                }
                .padding(.horizontal)
                .background(appState.theme.light.opacity(0.4))
                .cornerRadius(10)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        let showContent = appState.sidebarSelection == .stations || appState.sidebarSelection == .tracks || appState.sidebarSelection == .infraLines || appState.sidebarSelection == .routes || appState.sidebarSelection == .vehicles
        if showContent {
                // For list views, don't wrap in ScrollView - they handle their own scrolling
                VStack(spacing: 0) {
                    if appState.isShowingSettings {
                        ScrollView {
                            SettingsInspectorView()
                                .id("settings")
                                .padding(16)
                        }
                    } else if !appState.selectedTrainIds.isEmpty, let trainId = appState.selectedTrainIds.first, let train = linesManager.trains.first(where: { $0.id == trainId }) {
                        ScrollView {
                            TrainDetailView(train: train)
                                .padding(16)
                        }
                    } else if let previewData = appState.optimizedTimesPreviewData {
                        ScrollView {
                            OptimizedTimesPreviewInspectorView(
                                route: previewData.route,
                                mode: previewData.mode,
                                currentOutboundTime: previewData.currentOutboundTime,
                                currentReturnTime: previewData.currentReturnTime,
                                proposedOutboundTime: previewData.proposedOutboundTime,
                                proposedReturnTime: previewData.proposedReturnTime,
                                proposedInterval: previewData.proposedInterval,
                                proposedReturnInterval: previewData.proposedReturnInterval
                            )
                            .id("optimized-times-preview")
                            .padding(16)
                        }
                    } else if let trains = appState.schedulePreviewTrains, let route = appState.schedulePreviewRoute {
                        ScrollView {
                            SchedulePreviewInspectorView(
                                trains: trains,
                                line: route,
                                mode: appState.schedulePreviewMode
                            )
                            .id("schedule-preview")
                            .padding(16)
                        }
                    } else if appState.isCreatingLine {
                        ScrollView {
                            RouteCreationInspectorView()
                                .id("line-creation")
                                .padding(16)
                        }
                    } else if let lineId = appState.creationRouteId, let line = appState.railroad.lines.routes.first(where: { $0.id == lineId }) {
                        ScheduleCreationView(route: line)
                            .id("create-schedule-\(lineId)")
                    } else if let node = appState.selectedNode {
                        ScrollView {
                            StationInspectorView(
                                station: Binding(
                                    get: { appState.railroad.network.nodes.first(where: { $0.id == node.id }) ?? node },
                                    set: { newNode in
                                        if let idx = appState.railroad.network.nodes.firstIndex(where: { $0.id == node.id }) {
                                            appState.railroad.network.nodes[idx] = newNode
                                        }
                                    }
                                ),
                                onDelete: {
                                    appState.railroad.removeNode(node.id)
                                    appState.selectedNodeId = nil
                                }
                            )
                            .padding(16)
                        }
                    } else if let line = appState.selectedLine {
                        ScrollView {
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
                                            get: { appState.selectedRoute ?? line },
                                            set: { newLine in
                                                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                                                    linesManager.routes[idx] = newLine
                                                    linesManager.validateSchedules()
                                                    appState.objectWillChange.send()
                                                }
                                            }
                                        ),
                                        network: appState.railroad.network,
                                        externalSelectedStationID: $appState.selectedNodeId,
                                        externalSelectedEdgeID: $appState.selectedEdgeId,
                                        isSidebarEditMode: $appState.isLineEditing
                                    )
                                case .schedule:
                                    LineScheduleSummaryView(line: line)
                                        .padding(16)
                                case .vehicles:
                                    LineVehiclesView(lineId: line.id)
                                }
                            }
                        }
                    } else if let edgeId = appState.selectedEdgeId,
                              appState.railroad.network.edges.contains(where: { $0.id.uuidString == edgeId }) {
                        ScrollView {
                            TrackInspectorView(
                                edge: appState.railroad.network.edgeBinding(for: edgeId),
                                onDelete: {
                                    if let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
                                        appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                                    }
                                    appState.selectedEdgeId = nil
                                },
                                onBack: nil
                            )
                            .id("edge-\(edgeId)-\(appState.railroad.topologyId)")
                            .padding(16)
                        }
                    } else if let ferroviaId = appState.selectedInfraLineId {
                        ScrollView {
                            FerroviaInspectorView(
                                ferrovia: Binding(
                                    get: { 
                                        appState.railroad.network.lines.first(where: { $0.id == ferroviaId }) ?? 
                                        RailwayLine(name: "", color: "#000000", nodeIds: [], electrification: .dc3kv) // Fallback
                                    },
                                    set: { newLine in
                                        if let idx = appState.railroad.network.lines.firstIndex(where: { $0.id == ferroviaId }) {
                                            appState.railroad.network.lines[idx] = newLine
                                            appState.objectWillChange.send()
                                        }
                                    }
                                ),
                                onDelete: {
                                    if let index = appState.railroad.network.lines.firstIndex(where: { $0.id == ferroviaId }) {
                                        appState.railroad.network.lines.remove(at: index)
                                        appState.selectedInfraLineId = nil
                                        appState.selectedNodeIds.removeAll()
                                        appState.selectedNodeIdsOrder.removeAll()
                                    }
                                },
                                onBack: nil
                            )
                            .padding(16)
                        }
                    } else if let vehicle = appState.selectedVehicle {
                        ScrollView {
                            VehicleInspectorView(vehicle: vehicle)
                                .padding(16)
                        }
                    } else {
                        // Global lists when nothing is selected
                        globalSidebarContent
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if appState.isShowingSettings {
                            SettingsInspectorView()
                                .id("settings")
                        } else if let previewData = appState.optimizedTimesPreviewData {
                            OptimizedTimesPreviewInspectorView(
                                route: previewData.route,
                                mode: previewData.mode,
                                currentOutboundTime: previewData.currentOutboundTime,
                                currentReturnTime: previewData.currentReturnTime,
                                proposedOutboundTime: previewData.proposedOutboundTime,
                                proposedReturnTime: previewData.proposedReturnTime,
                                proposedInterval: previewData.proposedInterval,
                                proposedReturnInterval: previewData.proposedReturnInterval
                            )
                            .id("optimized-times-preview")
                        } else if let trains = appState.schedulePreviewTrains, let route = appState.schedulePreviewRoute {
                            SchedulePreviewInspectorView(
                                trains: trains,
                                line: route,
                                mode: appState.schedulePreviewMode
                            )
                            .id("schedule-preview")
                        } else if appState.isCreatingLine {
                            RouteCreationInspectorView()
                                .id("line-creation")
                        } else if let lineId = appState.creationRouteId, let line = appState.railroad.lines.lines.first(where: { $0.id == lineId }) {
                            ScheduleCreationView(route: line)
                                .id("create-schedule-\(lineId)")
                        } else if let node = appState.selectedNode {
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
                        } else if let line = appState.selectedRoute {
                            VStack(spacing: 0) {
                                LineQuickStats(line: line)
                                
                                Divider()
                                    .background(appState.theme.line.opacity(0.1))
                                    .padding(.vertical, 8)
                                
                                switch appState.lineInspectorMode {
                                case .infrastructure:
                                    LineInfrastructureView(line: line)
                                case .schedule:
                                    LineScheduleSummaryView(line: line)
                                case .vehicles:
                                    LineVehiclesView(lineId: line.id)
                                }
                            }
                        } else if let edgeId = appState.selectedEdgeId,
                                  appState.railroad.network.edges.contains(where: { $0.id.uuidString == edgeId }) {
                            TrackInspectorView(
                                edge: appState.railroad.network.edgeBinding(for: edgeId),
                                onDelete: {
                                    if let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
                                        appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                                    }
                                    appState.selectedEdgeId = nil
                                },
                                onBack: nil
                            )
                            .id("edge-\(edgeId)-\(appState.railroad.topologyId)")
                        } else if !appState.selectedTrainIds.isEmpty, let trainId = appState.selectedTrainIds.first, let train = linesManager.trains.first(where: { $0.id == trainId }) {
                            TrainDetailView(train: train)
                        } else if let ferroviaId = appState.selectedInfraLineId {
                            FerroviaInspectorView(
                                ferrovia: Binding(
                                    get: { 
                                        appState.railroad.network.lines.first(where: { $0.id == ferroviaId }) ?? 
                                        RailwayLine(name: "", color: "#000000", nodeIds: [], electrification: .dc3kv) // Fallback
                                    },
                                    set: { newLine in
                                        if let idx = appState.railroad.network.lines.firstIndex(where: { $0.id == ferroviaId }) {
                                            appState.railroad.network.lines[idx] = newLine
                                        }
                                    }
                                ),
                                onDelete: {
                                    if let index = appState.railroad.network.lines.firstIndex(where: { $0.id == ferroviaId }) {
                                        appState.railroad.network.lines.remove(at: index)
                                        appState.selectedInfraLineId = nil
                                        appState.selectedNodeIds.removeAll()
                                        appState.selectedNodeIdsOrder.removeAll()
                                    }
                                },
                                onBack: nil
                            )
                        } else if let vehicle = appState.selectedVehicle {
                            VehicleInspectorView(vehicle: vehicle)
                        } else {
                            // Global lists when nothing is selected
                            globalSidebarContent
                        }
                    }
                    .padding(16)
                }
            }
    }
    
    @ViewBuilder
    private var globalSidebarContent: some View {
        switch appState.sidebarSelection {
        case .stations:
            stationsList
        case .tracks:
            tracksList
        case .infraLines:
            ferrovieList
        case .lines, .routes:
            relazioniList
        case .trains:
            trainsByLineList
        case .vehicles:
            vehiclesList
        case .io:
            ScrollView {
                IOManagementView()
                    .padding(16)
            }
        default:
            EmptyView()
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
                        appState.railroad.removeNode(node.id)
                        if appState.selectedNodeId == node.id {
                            appState.selectedNodeId = nil
                        }
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
                        appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                        if appState.isEdgeSelected(edge.id.uuidString) {
                            appState.selectedEdgeId = nil
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $isListEditMode)
        }
    }
    
    private var ferrovieList: some View {
        let ferrovie = appState.railroad.network.lines
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ferrovie").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    appState.isMultiSelectMode = true
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
                ForEach(ferrovie) { ferrovia in
                    FerroviaRowContent(ferrovia: ferrovia)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isListEditMode == .inactive {
                                appState.selectedInfraLineId = ferrovia.id
                                appState.selectedNodeIds = Set(ferrovia.nodeIds)
                                appState.selectedNodeIdsOrder = ferrovia.nodeIds
                                appState.selectedNodeId = nil
                                appState.selectedEdgeId = nil
                                appState.selectedRouteId = nil
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
                    let networkLines = appState.railroad.network.lines
                    for index in indexSet {
                        let infraLine = networkLines[index]
                        if appState.selectedInfraLineId == infraLine.id {
                            appState.selectedInfraLineId = nil
                        }
                        appState.railroad.network.lines.removeAll { $0.id == infraLine.id }
                        appState.railroad.network.createCheckpoint()
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $isListEditMode)
        }
    }
    
    private var relazioniList: some View {
        let sortedLines = linesManager.routes.sorted { l1, l2 in
            let p1 = l1.numberPrefix ?? 0
            let p2 = l2.numberPrefix ?? 0
            if p1 != p2 { return p1 < p2 }
            return (l1.serviceCodePrefix ?? "") < (l2.serviceCodePrefix ?? "")
        }
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Relazioni").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    // Activate graphical line creation mode
                    appState.selectedRouteId = nil
                    appState.selectedNodeId = nil
                    appState.selectedEdgeId = nil
                    appState.selectedTrainIds = []
                    appState.creationRouteId = nil
                    appState.lineDraftStations.removeAll()
                    appState.isCreatingLine = true
                    appState.showPanel(.inspector)
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
                                appState.selectedRouteId = line.id
                                appState.mapVisualizationMode = .scheduler
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
                        linesManager.routes.removeAll { $0.id == line.id }
                        linesManager.trains.removeAll { $0.routeId == line.id }
                        if appState.selectedRouteId == line.id { 
                            appState.selectedRouteId = nil 
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $isListEditMode)
        }
    }
    
    private var trainsByLineList: some View {
        TrainsByRouteListView()
    }
    
    private var vehiclesList: some View {
        RollingStockView(manager: linesManager)
    }
}
