import SwiftUI
import Combine
import MapKit
import UniformTypeIdentifiers

struct RailwayMapView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String?
    @Binding var showGrid: Bool
    @Binding var highlightedConflictLocation: String?
    @Binding var mode: MapVisualizationMode
    
    @StateObject private var internalEditorVM: EditorModeViewModel
    @State private var showModeSelector = false
    
    init(selectedNode: Binding<Node?>, selectedLine: Binding<RailwayLine?>, selectedEdgeId: Binding<String?>,
         showGrid: Binding<Bool>, highlightedConflictLocation: Binding<String?>, mode: Binding<MapVisualizationMode>,
         appState: AppState) {
        self._selectedNode = selectedNode
        self._selectedLine = selectedLine
        self._selectedEdgeId = selectedEdgeId
        self._showGrid = showGrid
        self._highlightedConflictLocation = highlightedConflictLocation
        self._mode = mode
        self._internalEditorVM = StateObject(wrappedValue: EditorModeViewModel(appState: appState))
    }
    
    var editorViewModel: EditorModeViewModel { internalEditorVM }
    
    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }
    
    @State private var isExporting = false

    var body: some View {
        ZStack {
            // LAYER 0: MAPPA + UI OVERLAYS (Innestati per hit-test perfetto)
            SchematicRailwayView(
                selectedNode: $selectedNode,
                selectedLine: $selectedLine,
                selectedEdgeId: $selectedEdgeId,
                showGrid: $showGrid,
                highlightedConflictLocation: $highlightedConflictLocation,
                mode: mode,
                zoomLevel: $appState.mapZoomLevel,
                onExport: { exportMap(as: $0) }, 
                onPrint: { printMap() },
                appState: appState,
                editorViewModel: internalEditorVM
            )
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) { 
                sidebarToggleButton.padding(24) 
            }
            .overlay(alignment: .top) {
                if appState.currentMode == .design && appState.mapEditMode != .explore {
                    instructionsBanner
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomLeading) {
                toolboxOverlay.padding(24).padding(.bottom, 60)
            }
            .overlay(alignment: .bottomTrailing) {
                mapControlsOverlay.padding(24).padding(.bottom, 60)
            }
            .overlay(alignment: .bottom) {
                profileOrModeBarOverlay
            }
            
            // LAYER 2: MODALI (BLOCCANTI)
            if isExporting {
                exportingModal
            }
        }
        .navigationTitle("network_schema".localized)
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var sidebarToggleButton: some View {
        Button(action: { appState.showPanel(.sidebar) }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 5)
        }
    }
    
    @ViewBuilder
    private var toolboxOverlay: some View {
        if appState.currentMode == .design {
            Group {
                EditorToolboxView(viewModel: internalEditorVM)
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var mapControlsOverlay: some View {
        MapControlsView(
            isEditToolbarVisible: Binding.constant(false),
            editMode: Binding.constant(appState.mapEditMode),
            onExport: { exportMap(as: $0) },
            onPrint: { printMap() }
        )
    }
    
    @ViewBuilder
    private var profileOrModeBarOverlay: some View {
        modeSelectorBar.padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var exportingModal: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 15) {
                    ProgressView().scaleEffect(1.5).tint(.white)
                    Text("exporting_map...").foregroundColor(.white).font(.headline)
                }
            }
            .transition(.opacity)
    }
    
    // MARK: - Mode Selector
    
    @ViewBuilder
    private var modeSelectorBar: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            if showModeSelector {
                VStack(spacing: 16) {
                    Text("Modalità Visualizzazione")
                        .font(.headline)
                        .padding(.top, 12)
                    
                    HStack(spacing: 12) {
                        ForEach(MapVisualizationMode.allCases, id: \.self) { vizMode in
                            modeButton(for: vizMode)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .foregroundColor(.accentColor)
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showModeSelector.toggle()
            }
        }
    }
    
    @ViewBuilder
    private var instructionsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.mapEditMode == .addStation ? "hand.tap.fill" : "point.topleft.down.curvedto.point.bottomright.up")
                .font(.title2)
            
            Text(appState.mapEditMode == .addStation ? 
                 "Premi a lungo sulla mappa per posizionare la stazione" : 
                 "Seleziona due stazioni sulla mappa per collegarle")
                .fontWeight(.bold)
            
            Button {
                withAnimation {
                    appState.mapEditMode = .explore
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 10)
    }

    @ViewBuilder
    private func modeButton(for vizMode: MapVisualizationMode) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(mode == vizMode ? Color.accentColor : Color.secondary.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: vizMode.icon)
                    .font(.system(size: 20))
                    .foregroundColor(mode == vizMode ? .white : .primary)
            }
            
            Text(vizMode.displayName)
                .font(.caption2)
                .fontWeight(mode == vizMode ? .bold : .regular)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                mode = vizMode
                showModeSelector = false
            }
        }
    }

    @MainActor
    private func exportMap(as format: AppExportFormat) {
        isExporting = true
        
        let nodes = network.nodes
        let edges = network.edges
        let m = mode
        let gSize = appState.globalFontSize
        let gWidth = appState.globalLineWidth
        
        let lns = lines.lines
        let schs = appState.simulator.schedules
        
        Task {
            // Prepare data on main thread (required due to actor isolation of models)
            let snapshotData = MapSnapshotData.prepare(nodes: nodes, edges: edges, lines: lns, schedules: schs, mode: m, globalFontSize: gSize, globalLineWidth: gWidth)
            
            // Render on main thread
            await MainActor.run {
                let snapshot = RailwayMapSnapshot(data: snapshotData)
                    .environmentObject(appState)
                let renderer = ImageRenderer(content: snapshot)
                renderer.scale = 2.0
                
                if format == .jpeg {
                    if let image = renderer.uiImage {
                        shareItem(image)
                    }
                } else {
                    let pdfUrl = FileManager.default.temporaryDirectory.appendingPathComponent("MappaFerroviaria.pdf")
                    renderer.render { size, context in
                        var box = CGRect(origin: .zero, size: size)
                        guard let consumer = CGDataConsumer(url: pdfUrl as CFURL),
                              let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
                        pdfContext.beginPDFPage(nil)
                        context(pdfContext)
                        pdfContext.endPDFPage()
                        pdfContext.closePDF()
                    }
                    shareItem(pdfUrl)
                }
                isExporting = false
            }
        }
    }
    
    private func shareItem(_ item: Any) {
        let av = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            av.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            root.present(av, animated: true, completion: nil)
        }
    }
    
    private func printMap() {
        isExporting = true
        let nodes = network.nodes
        let edges = network.edges
        let m = mode
        let gSize = appState.globalFontSize
        let gWidth = appState.globalLineWidth
        
        let lns = lines.lines
        let schs = appState.simulator.schedules
        
        Task {
            let snapshotData = MapSnapshotData.prepare(nodes: nodes, edges: edges, lines: lns, schedules: schs, mode: m, globalFontSize: gSize, globalLineWidth: gWidth)
            
            await MainActor.run {
                let snapshot = RailwayMapSnapshot(data: snapshotData)
                    .environmentObject(appState)
                let renderer = ImageRenderer(content: snapshot)
                if let image = renderer.uiImage {
                     let printInfo = UIPrintInfo(dictionary: nil)
                     printInfo.outputType = .general
                     printInfo.jobName = "network_map".localized
                     
                     let controller = UIPrintInteractionController.shared
                     controller.printInfo = printInfo
                     controller.printingItem = image
                     controller.present(animated: true, completionHandler: nil)
                }
                isExporting = false
            }
        }
    }

    // Pre-calculated data structure for non-blocking rendering
    struct MapSnapshotData: Sendable {
        struct LineDraw: Sendable {
            let path: Path
            let color: Color
            let name: String
            let bundleSize: Int
        }
        
        struct TrainDraw: Sendable {
            let pos: CGPoint
            let name: String
            let color: Color
        }
        
        struct EdgeDraw: Sendable {
            let path: Path
            let points: [CGPoint]
            let color: Color
            let type: RailwayEdge.TrackType
            let baseColor: Color
        }
        
        struct GroupDraw: Sendable {
            let positions: [CGPoint]
            let label: String
            let center: CGPoint
            let bottomY: CGFloat
            let isSingle: Bool
        }
        
        struct NodeDraw: Sendable {
            let pos: CGPoint
            let name: String
            let isHub: Bool
            let nodeType: RailwayNode.NodeType
            let visualType: RailwayNode.StationVisualType
            let color: Color
            let parentHubId: String?
        }
        
        let bounds: MapBounds
        let edges: [EdgeDraw]
        let groups: [GroupDraw]
        let nodes: [NodeDraw]
        let lines: [LineDraw]
        let trains: [TrainDraw]
        let mode: MapVisualizationMode
        let globalFontSize: Double
        let globalLineWidth: Double
        
        static func prepare(
            nodes: [RailwayNode], 
            edges: [RailwayEdge], 
            lines: [TrainRoute], 
            schedules: [TrainSchedule],
            mode: MapVisualizationMode, 
            globalFontSize: Double, 
            globalLineWidth: Double
        ) -> MapSnapshotData {
            let snapshotSize = CGSize(width: 2048, height: 1536)
            let bounds = MapGeometryEngine.calculateBounds(nodes: nodes)
            
            // 1. Edges with parallel track support
            let edgesDraw = generateEdgeDraws(nodes: nodes, edges: edges, bounds: bounds, snapshotSize: snapshotSize, mode: mode)
            
            // 2. Hub Clusters
            let visualGroups = generateHubClusters(nodes: nodes, bounds: bounds, snapshotSize: snapshotSize)
            
            // 3. Nodes
            let nodesDraw = generateNodeDraws(nodes: nodes, bounds: bounds, snapshotSize: snapshotSize)
            
            // 4. Commercial Lines & Trains (Scheduler Mode)
            let linesDraw = mode.isSchedulerMode ? generateLineDraws(nodes: nodes, lines: lines, bounds: bounds, snapshotSize: snapshotSize) : []
            let trainsDraw = mode.isSchedulerMode ? generateTrainDraws(schedules: schedules, nodes: nodes, bounds: bounds, snapshotSize: snapshotSize) : []
            
            return MapSnapshotData(
                bounds: bounds, 
                edges: edgesDraw, 
                groups: visualGroups, 
                nodes: nodesDraw, 
                lines: linesDraw, 
                trains: trainsDraw, 
                mode: mode, 
                globalFontSize: globalFontSize, 
                globalLineWidth: globalLineWidth
            )
        }

        // MARK: - Extraction Helpers

        private static func generateNodeDraws(nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize) -> [NodeDraw] {
            return nodes.map { node -> NodeDraw in
                let visualType = node.visualType ?? node.defaultVisualType
                let color = Color(hex: node.customColor ?? node.defaultColor) ?? .black
                let pos = finalPosition(for: node, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                return NodeDraw(
                    pos: pos, 
                    name: node.name, 
                    isHub: node.type == .interchange, 
                    nodeType: node.type, 
                    visualType: visualType, 
                    color: color, 
                    parentHubId: node.parentHubId
                )
            }
        }

        private static func finalPosition(for node: RailwayNode, bounds: MapBounds, snapshotSize: CGSize, nodes: [RailwayNode]) -> CGPoint {
            let lon = node.longitude ?? 0
            let lat = node.latitude ?? 0
            let baseX = (lon - bounds.minLon) / bounds.xRange * (snapshotSize.width - 100) + 50
            let baseY = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (snapshotSize.height - 100) + 50
            let pPos = CGPoint(x: baseX, y: baseY)
            
            if let parentId = node.parentHubId,
               let parent = nodes.first(where: { $0.id == parentId }) {
                let parentP = finalPositionStatic(for: parent, bounds: bounds, snapshotSize: snapshotSize)
                let direction = node.hubOffsetDirection ?? .bottomRight
                let offset = HubTopology.canvasOffset(for: direction)
                return CGPoint(x: parentP.x + offset.x, y: parentP.y + offset.y)
            }
            return pPos
        }

        private static func generateEdgeDraws(nodes: [RailwayNode], edges: [RailwayEdge], bounds: MapBounds, snapshotSize: CGSize, mode: MapVisualizationMode) -> [EdgeDraw] {
            var edgesDraw: [EdgeDraw] = []
            var edgesByPair: [String: [RailwayEdge]] = [:]
            for edge in edges {
                edgesByPair[edge.canonicalKey, default: []].append(edge)
            }
            
            for (_, edgeGroup) in edgesByPair {
                guard let firstEdge = edgeGroup.first,
                      let n1 = nodes.first(where: { $0.id == firstEdge.from }),
                      let n2 = nodes.first(where: { $0.id == firstEdge.to }) else { continue }
                
                let p1 = finalPosition(for: n1, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                let p2 = finalPosition(for: n2, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                let basePoints = generateSchematicPoints(from: p1, to: p2)
                
                let trackCount = edgeGroup.count
                let offsetDistance: CGFloat = 6.0
                
                for (index, edge) in edgeGroup.enumerated() {
                    let offset = (trackCount == 1) ? 0 : (CGFloat(index) - CGFloat(trackCount - 1) / 2.0) * offsetDistance
                    let offsetPoints = applyPerpendicularOffset(to: basePoints, offset: offset)
                    let path = createSmoothPath(points: offsetPoints)
                    let baseColor: Color = mode.isSchedulerMode ? .gray.opacity(0.3) : .gray
                    edgesDraw.append(EdgeDraw(path: path, points: offsetPoints, color: (edge.trackType == .highSpeed ? .red.opacity(0.8) : .black.opacity(0.8)), type: edge.trackType, baseColor: baseColor))
                }
            }
            return edgesDraw
        }

        private static func applyPerpendicularOffset(to points: [CGPoint], offset: CGFloat) -> [CGPoint] {
            if offset == 0 { return points }
            return points.indices.map { i in
                let p = points[i]
                var perp: CGPoint = .zero
                if i == 0 && points.count > 1 {
                    perp = perpendicular(from: p, to: points[i+1])
                } else if i == points.count - 1 && points.count > 1 {
                    perp = perpendicular(from: points[i-1], to: p)
                } else if points.count > 2 {
                    let p1 = perpendicular(from: points[i-1], to: p)
                    let p2 = perpendicular(from: p, to: points[i+1])
                    perp = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                    let len = hypot(perp.x, perp.y)
                    if len > 0 { perp.x /= len; perp.y /= len }
                }
                return CGPoint(x: p.x + perp.x * offset, y: p.y + perp.y * offset)
            }
        }

        private static func perpendicular(from p1: CGPoint, to p2: CGPoint) -> CGPoint {
            let dx = p2.x - p1.x; let dy = p2.y - p1.y
            let len = hypot(dx, dy)
            return len > 0 ? CGPoint(x: -dy/len, y: dx/len) : .zero
        }

        private static func generateHubClusters(nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize) -> [GroupDraw] {
            var visualGroups: [GroupDraw] = []
            let hubTopology = HubTopology(nodes: nodes)

            for parent in nodes where hubTopology.avSatellite(for: parent.id) != nil {
                guard let satellite = hubTopology.avSatellite(for: parent.id) else { continue }
                let parentPos = finalPosition(for: parent, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                let satellitePos = finalPosition(for: satellite, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                let maxY = max(parentPos.y, satellitePos.y)
                let centerX = (parentPos.x + satellitePos.x) / 2
                visualGroups.append(GroupDraw(
                    positions: [parentPos, satellitePos],
                    label: parent.name,
                    center: CGPoint(x: centerX, y: maxY + 35),
                    bottomY: maxY,
                    isSingle: false
                ))
            }

            let orphanInterchanges = nodes.filter { node in
                node.type == .interchange && hubTopology.hubVisualRole(for: node) == .none
            }
            for node in orphanInterchanges {
                let p = finalPosition(for: node, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                visualGroups.append(GroupDraw(positions: [p], label: node.name, center: CGPoint(x: p.x, y: p.y + 35), bottomY: p.y, isSingle: true))
            }
            return visualGroups
        }

        private static func generateLineDraws(nodes: [RailwayNode], lines: [TrainRoute], bounds: MapBounds, snapshotSize: CGSize) -> [LineDraw] {
            var drawings: [LineDraw] = []
            var segmentLineMap: [SegmentKey: [TrainRoute]] = [:]
            for line in lines where line.stationIds.count > 1 {
                for i in 0..<(line.stationIds.count - 1) {
                    segmentLineMap[SegmentKey(line.stationIds[i], line.stationIds[i+1]), default: []].append(line)
                }
            }
            for (key, segLines) in segmentLineMap {
                guard let n1 = nodes.first(where: { $0.id == key.from }), let n2 = nodes.first(where: { $0.id == key.to }) else { continue }
                let p1 = finalPosition(for: n1, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                let p2 = finalPosition(for: n2, bounds: bounds, snapshotSize: snapshotSize, nodes: nodes)
                let points = generateSchematicPoints(from: p1, to: p2)
                let bundleSize = segLines.count
                for j in 0..<(points.count - 1) {
                    let sp1 = points[j]; let sp2 = points[j+1]
                    let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
                    let offsetBase: CGFloat = 8.0
                    for (i, line) in segLines.enumerated() {
                        let offset = CGFloat(i) * offsetBase - (CGFloat(segLines.count - 1) * offsetBase / 2.0)
                        let lp1 = CGPoint(x: sp1.x - sin(angle) * offset, y: sp1.y + cos(angle) * offset)
                        let lp2 = CGPoint(x: sp2.x - sin(angle) * offset, y: sp2.y + cos(angle) * offset)
                        let path = Path { p in p.move(to: lp1); p.addLine(to: lp2) }
                        drawings.append(LineDraw(path: path, color: Color(hex: line.color ?? "#000000") ?? .black, name: line.name, bundleSize: bundleSize))
                    }
                }
            }
            return drawings
        }

        private static func generateTrainDraws(schedules: [TrainSchedule], nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize) -> [TrainDraw] {
            var drawings: [TrainDraw] = []
            let now = Date().normalized()
            for sch in schedules {
                if let pos = calculateTrainPosition(schedule: sch, now: now, nodes: nodes, bounds: bounds, snapshotSize: snapshotSize) {
                    drawings.append(TrainDraw(pos: pos, name: sch.trainName, color: .red))
                }
            }
            return drawings
        }

        // Static helpers (Sendable)
        static func calculateTrainPosition(schedule: TrainSchedule, now: Date, nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize) -> CGPoint? {
            guard schedule.stops.count >= 2 else { return nil }
            for i in 0..<(schedule.stops.count - 1) {
                let s1 = schedule.stops[i]; let s2 = schedule.stops[i+1]
                guard let d1 = s1.departureTime, let a2 = s2.arrivalTime else { continue }
                if now >= d1 && now <= a2 {
                    let progress = a2.timeIntervalSince(d1) > 0 ? now.timeIntervalSince(d1) / a2.timeIntervalSince(d1) : 0.0
                    guard let n1 = nodes.first(where: { $0.id == s1.stationId }),
                          let n2 = nodes.first(where: { $0.id == s2.stationId }) else { return nil }
                    let p1 = finalPositionStatic(for: n1, bounds: bounds, snapshotSize: snapshotSize)
                    let p2 = finalPositionStatic(for: n2, bounds: bounds, snapshotSize: snapshotSize)
                    let points = generateSchematicPoints(from: p1, to: p2)
                    var totalLen: CGFloat = 0; var segmentLens: [CGFloat] = []
                    for j in 0..<(points.count - 1) {
                        let d = hypot(points[j+1].x - points[j].x, points[j+1].y - points[j].y)
                        totalLen += d; segmentLens.append(d)
                    }
                    if totalLen == 0 { return p1 }
                    let targetDist = totalLen * CGFloat(progress)
                    var currentDist: CGFloat = 0
                    for (j, segLen) in segmentLens.enumerated() {
                        if currentDist + segLen >= targetDist {
                            let segProgress = (targetDist - currentDist) / segLen
                            let sp1 = points[j]; let sp2 = points[j+1]
                            return CGPoint(x: sp1.x + (sp2.x - sp1.x) * segProgress, y: sp1.y + (sp2.y - sp1.y) * segProgress)
                        }
                        currentDist += segLen
                    }
                    return points.last
                }
            }
            return nil
        }

        static func finalPositionStatic(for node: RailwayNode, bounds: MapBounds, snapshotSize: CGSize) -> CGPoint {
            let lon = node.longitude ?? 0; let lat = node.latitude ?? 0
            return CGPoint(
                x: (lon - bounds.minLon) / bounds.xRange * (snapshotSize.width - 100) + 50,
                y: (1.0 - (lat - bounds.minLat) / bounds.yRange) * (snapshotSize.height - 100) + 50
            )
        }

        static func generateSchematicPoints(from p1: CGPoint, to p2: CGPoint) -> [CGPoint] {
            let dx = p2.x - p1.x; let dy = p2.y - p1.y
            if abs(dx) > abs(dy) {
                let midX = p1.x + (dx - abs(dy) * (dx > 0 ? 1 : -1))
                return [p1, CGPoint(x: midX, y: p1.y), p2]
            } else {
                let midY = p1.y + (dy - abs(dx) * (dy > 0 ? 1 : -1))
                return [p1, CGPoint(x: p1.x, y: midY), p2]
            }
        }
        
        static func createSmoothPath(points: [CGPoint]) -> Path {
            var path = Path()
            guard !points.isEmpty else { return path }
            path.move(to: points[0])
            for i in 1..<points.count { path.addLine(to: points[i]) }
            return path
        }
    }

    // Dedicated Snapshot View using direct Canvas drawing 
    struct RailwayMapSnapshot: View {
        @EnvironmentObject var appState: AppState
        let data: MapSnapshotData
        private let renderer = RailwayRenderer()
        
        var body: some View {
            Canvas { context, size in
                let renderingContext = RenderingContext(
                    bounds: RenderingContext.MapBounds(
                        minLat: data.bounds.minLat,
                        maxLat: data.bounds.maxLat,
                        minLon: data.bounds.minLon,
                        maxLon: data.bounds.maxLon,
                        xRange: data.bounds.xRange,
                        yRange: data.bounds.yRange
                    ),
                    canvasSize: size,
                    zoomLevel: 1.0,
                    mode: data.mode == .infrastructure ? .infrastructure : .scheduler
                )

                // 1. Draw Edges
                for edge in data.edges {
                    let style = EdgeStyle.forTrackType(edge.type)
                    renderer.drawEdge(
                        points: edge.points,
                        trackType: edge.type,
                        in: context,
                        renderingContext: renderingContext,
                        style: style,
                        isSelected: false
                    )
                }
                
                // 2. Draw Commercial Lines
                for l in data.lines {
                    context.stroke(l.path, with: .color(l.color), style: StrokeStyle(lineWidth: data.globalLineWidth, lineCap: .round))
                }
                
                // 3. Hubs & Groups
                for group in data.groups {
                    renderer.drawHubGroup(
                        positions: group.positions,
                        label: group.label,
                        center: group.center,
                        fontSize: data.globalFontSize,
                        zoomLevel: 1.0,
                        in: context
                    )
                }
                
                // 4. Nodes
                for node in data.nodes {
                    let style = NodeStyle(
                        fillColor: node.color,
                        strokeColor: .black.opacity(0.2),
                        strokeWidth: 0.5,
                        size: 8,
                        showLabel: true,
                        isHighlighted: false,
                        isSelected: false
                    )
                    // We need a dummy RailwayNode to satisfy the renderer or just draw it manually.
                    // Let's create a minimal RailwayNode.
                    let dummyNode = RailwayNode(id: UUID().uuidString, name: node.name, type: node.nodeType)
                    renderer.drawNode(dummyNode, at: node.pos, in: context, zoomLevel: 1.0, style: style)
                }
                
                // 5. Trains
                for train in data.trains {
                    context.fill(Path(ellipseIn: CGRect(x: train.pos.x - 5, y: train.pos.y - 5, width: 10, height: 10)), with: .color(train.color))
                    let text = Text(train.name).font(.system(size: 8, weight: .bold))
                    let resolved = context.resolve(text)
                    context.draw(resolved, at: CGPoint(x: train.pos.x, y: train.pos.y - 15))
                }
            }
            .frame(width: 2048, height: 1536)
            .background(Color.white)
        }
    }
}
