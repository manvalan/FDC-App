import SwiftUI

// MARK: - Overlay Components for ContentView
// Extracted to reduce cognitive load and improve testability

struct ModeBarOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            Color.black.opacity(0.001)
                .onTapGesture { appState.showPanel(.none) }
                .zIndex(ZIndex.modeDismiss)
            
            VStack {
                FloatingModeBar()
                    .padding(.top, Layout.leftEdgeWidth)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(ZIndex.modeBar)
        }
    }
}

struct SidebarOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            FloatingSideMenu()
                .transition(.move(edge: .leading))
            Spacer()
        }
        .background(Color.black.opacity(0.2).onTapGesture { appState.showPanel(.none) })
        .zIndex(ZIndex.sidebar)
    }
}

struct WidePanelOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            WidePanelView()
                .frame(width: Layout.widePanelWidth)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            Spacer()
                .frame(width: Layout.inspectorWidth)
        }
        .edgesIgnoringSafeArea(.all)
        .zIndex(ZIndex.widePanel)
    }
}

struct InspectorOverlay: View {
    var body: some View {
        HStack {
            Spacer()
            ModernInspectorPanel()
        }
        .zIndex(ZIndex.inspector)
    }
}

struct ModernInspectorPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @State private var isListEditMode: EditMode = .inactive
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                    } else if let lineId = appState.creationLineId, let line = appState.railroad.lines.lines.first(where: { $0.id == lineId }) {
                        Text("Genera Orari: \(line.name)").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let node = appState.selectedNode {
                        Text(node.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                    } else if let line = appState.selectedLine {
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
                if appState.isShowingSettings || appState.optimizedTimesPreviewData != nil || appState.schedulePreviewTrains != nil || appState.creationLineId != nil || appState.selectedNodeId != nil || appState.selectedEdgeId != nil || appState.selectedLineId != nil || !appState.selectedTrainIds.isEmpty || appState.isCreatingLine {
                    Button(action: {
                        if appState.isShowingSettings {
                            appState.isShowingSettings = false
                        } else if appState.optimizedTimesPreviewData != nil {
                            appState.optimizedTimesPreviewData = nil
                        } else if appState.schedulePreviewTrains != nil {
                            appState.schedulePreviewTrains = nil
                            appState.schedulePreviewLine = nil
                        } else if appState.creationLineId != nil {
                            appState.creationLineId = nil
                        } else if appState.isCreatingLine {
                            appState.isCreatingLine = false
                            appState.lineDraftStations.removeAll()
                            appState.stationPickingCallback = nil
                        } else {
                            appState.clearSelection()
                        }
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title3)
                            .foregroundColor(appState.theme.medium)
                    }
                }
                
                // Close button
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
            
            // Tab selector for "Rete" and "Binari"
            if appState.selectedLine == nil && appState.selectedNode == nil && appState.selectedEdgeId == nil && (appState.sidebarSelection == .stations || appState.sidebarSelection == .tracks) {
                HStack(spacing: 0) {
                    Button(action: { appState.sidebarSelection = .stations }) {
                        Text("Stazioni")
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
            
            // Content
            if appState.sidebarSelection == .stations || appState.sidebarSelection == .tracks || appState.sidebarSelection == .lines || appState.sidebarSelection == .vehicles {
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
                                line: previewData.line,
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
                    } else if let trains = appState.schedulePreviewTrains, let line = appState.schedulePreviewLine {
                        ScrollView {
                            SchedulePreviewInspectorView(
                                trains: trains,
                                line: line,
                                mode: appState.schedulePreviewMode
                            )
                            .id("schedule-preview")
                            .padding(16)
                        }
                    } else if appState.isCreatingLine {
                        ScrollView {
                            LineCreationInspectorView()
                                .id("line-creation")
                                .padding(16)
                        }
                    } else if let lineId = appState.creationLineId, let line = appState.railroad.lines.lines.first(where: { $0.id == lineId }) {
                        ScheduleCreationView(line: line)
                            .id("create-schedule-\(lineId)")
                    } else if let node = appState.selectedNode {
                        ScrollView {
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
                    } else if let edgeId = appState.selectedEdgeId,
                              let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
                        ScrollView {
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
                                line: previewData.line,
                                mode: previewData.mode,
                                currentOutboundTime: previewData.currentOutboundTime,
                                currentReturnTime: previewData.currentReturnTime,
                                proposedOutboundTime: previewData.proposedOutboundTime,
                                proposedReturnTime: previewData.proposedReturnTime,
                                proposedInterval: previewData.proposedInterval,
                                proposedReturnInterval: previewData.proposedReturnInterval
                            )
                            .id("optimized-times-preview")
                        } else if let trains = appState.schedulePreviewTrains, let line = appState.schedulePreviewLine {
                            SchedulePreviewInspectorView(
                                trains: trains,
                                line: line,
                                mode: appState.schedulePreviewMode
                            )
                            .id("schedule-preview")
                        } else if appState.isCreatingLine {
                            LineCreationInspectorView()
                                .id("line-creation")
                        } else if let lineId = appState.creationLineId, let line = appState.railroad.lines.lines.first(where: { $0.id == lineId }) {
                            ScheduleCreationView(line: line)
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
                        } else if let line = appState.selectedLine {
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
                                  let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
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
                        } else if !appState.selectedTrainIds.isEmpty, let trainId = appState.selectedTrainIds.first, let train = linesManager.trains.first(where: { $0.id == trainId }) {
                            TrainDetailView(train: train)
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
    
    @ViewBuilder
    private var globalSidebarContent: some View {
        switch appState.sidebarSelection {
        case .stations:
            stationsList
        case .tracks:
            tracksList
        case .lines:
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
                        appState.railroad.network.removeNode(node.id)
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
                        if appState.selectedEdgeId == edge.id.uuidString { 
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
    
    private var relazioniList: some View {
        let sortedLines = linesManager.lines.sorted { l1, l2 in
            let p1 = l1.numberPrefix ?? 0
            let p2 = l2.numberPrefix ?? 0
            if p1 != p2 { return p1 < p2 }
            return (l1.codePrefix ?? "") < (l2.codePrefix ?? "")
        }
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Relazioni").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    // Activate graphical line creation mode
                    appState.selectedLineId = nil
                    appState.selectedNodeId = nil
                    appState.selectedEdgeId = nil
                    appState.selectedTrainIds = []
                    appState.creationLineId = nil
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
                                appState.selectedLineId = line.id
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
                        linesManager.lines.removeAll { $0.id == line.id }
                        linesManager.trains.removeAll { $0.lineId == line.id }
                        if appState.selectedLineId == line.id { 
                            appState.selectedLineId = nil 
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
        TrainsByLineListView()
    }
    
    private var vehiclesList: some View {
        RollingStockView(manager: linesManager)
    }
}

struct SimulationControlsOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Spacer()
            LiveSimulationShelf()
                .padding(.bottom, Layout.standardPadding)
        }
        .zIndex(ZIndex.simulation)
    }
}

// MARK: - Edge Gesture Detectors
struct EdgeGestureDetectors: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            topEdgeGesture
            
            HStack(spacing: 0) {
                leftEdgeGesture
                Spacer()
                rightEdgeGesture
            }
            .frame(maxHeight: .infinity)
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private var topEdgeGesture: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.fdcGreyMedium.opacity(0.3))
                .frame(width: Layout.dragHandleWidth, height: Layout.dragHandleHeight)
                .padding(.top, Layout.smallPadding)
            
            Color.clear
                .frame(height: Layout.topEdgeHeight)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if value.translation.height > Layout.pullDownThreshold {
                        appState.showPanel(.modeBar)
                    }
                }
        )
    }
    
    private var leftEdgeGesture: some View {
        Color.clear
            .frame(width: Layout.leftEdgeWidth)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: Layout.minimumDragDistance)
                    .onEnded { value in
                        if value.translation.width > Layout.swipeThreshold {
                            appState.showPanel(.sidebar)
                        }
                    }
            )
    }
    
    private var rightEdgeGesture: some View {
        Color.clear
            .frame(width: Layout.rightEdgeWidth)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: Layout.minimumDragDistance)
                    .onEnded { value in
                        if value.translation.width < -Layout.swipeThreshold {
                            appState.showPanel(.inspector)
                        }
                    }
            )
    }
}
