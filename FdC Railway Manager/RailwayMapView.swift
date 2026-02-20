import SwiftUI
import Combine
import MapKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Helper Functions per curve morbide

/// Genera un percorso con linee rette semplici
fileprivate func createSmoothPath(points: [CGPoint]) -> Path {
    guard points.count > 1 else { return Path() }
    
    return Path { path in
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
    }
}

// MARK: - Main View

struct RailwayMapView: View {
    enum MapVisualizationMode: String, CaseIterable {
        case schematic   // Visualizzazione schematica tradizionale
        case infrastructure  // Infrastruttura dettagliata con segmenti e segnali
        case scheduler   // Modalità Train Director/Scheduler
        
        var displayName: String {
            switch self {
            case .schematic: return "Schematica"
            case .infrastructure: return "Infrastruttura"
            case .scheduler: return "Train Director"
            }
        }
        
        var icon: String {
            switch self {
            case .schematic: return "map"
            case .infrastructure: return "road.lanes"
            case .scheduler: return "clock.arrow.circlepath"
            }
        }
        
        var description: String {
            switch self {
            case .schematic: return "Vista schematica della rete"
            case .infrastructure: return "Dettagli tecnici: segmenti e segnali"
            case .scheduler: return "Gestione orari e conflitti"
            }
        }
        
        // Legacy compatibility
        static var network: MapVisualizationMode { .schematic }
        static var lines: MapVisualizationMode { .scheduler }
        
        var isInfrastructureMode: Bool {
            self == .infrastructure
        }
        
        var isSchedulerMode: Bool {
            self == .scheduler
        }
    }

    @EnvironmentObject var appState: AppState
    @State private var position: MapCameraPosition = .automatic
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String?
    @Binding var showGrid: Bool
    @Binding var isMoveModeEnabled: Bool
    @Binding var highlightedConflictLocation: String?
    @Binding var mode: MapVisualizationMode
    
    @State private var showModeSelector = false
    
    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }
    
    @State private var isExporting = false

    struct MapBounds: Sendable {
        let minLat, maxLat, minLon, maxLon, xRange, yRange: Double
    }

    var body: some View {
        ZStack {
            SchematicRailwayView(
                selectedNode: $selectedNode,
                selectedLine: $selectedLine,
                selectedEdgeId: $selectedEdgeId,
                showGrid: $showGrid,
                isMoveModeEnabled: $isMoveModeEnabled,
                highlightedConflictLocation: $highlightedConflictLocation,
                mode: mode,
                onExport: { exportMap(as: $0) },
                onPrint: { printMap() }
            )
            
            // Internal Simulation Controls removed - now handled by Floating shelf in ContentView
            
            // Mode Selector - Swipe from top
            VStack {
                modeSelectorBar
                Spacer()
            }
            
            if isExporting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("generating_map".localized)
                        .font(.headline)
                    Text("generation_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(30)
                .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)))
                .shadow(radius: 10)
            }
        }
        .navigationTitle("network_schema".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { exportMap(as: .jpeg) }) {
                        Label("export_jpeg".localized, systemImage: "photo")
                    }
                    Button(action: { exportMap(as: .pdf) }) {
                        Label("export_pdf".localized, systemImage: "doc.text")
                    }
                    Divider()
                    Button(action: { printMap() }) {
                        Label("print".localized, systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
    
    // MARK: - Mode Selector
    
    @ViewBuilder
    private var modeSelectorBar: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            // Mode selector content
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
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                // Compact indicator showing current mode
                HStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .foregroundColor(.accentColor)
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    if gesture.translation.height > 50 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showModeSelector = true
                        }
                    } else if gesture.translation.height < -50 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showModeSelector = false
                        }
                    }
                }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showModeSelector.toggle()
            }
        }
    }
    
    @ViewBuilder
    private func modeButton(for vizMode: MapVisualizationMode) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(mode == vizMode ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: vizMode.icon)
                    .font(.system(size: 24))
                    .foregroundColor(mode == vizMode ? .white : .primary)
            }
            
            VStack(spacing: 2) {
                Text(vizMode.displayName)
                    .font(.caption)
                    .fontWeight(mode == vizMode ? .bold : .regular)
                
                Text(vizMode.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 100)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                mode = vizMode
                showModeSelector = false
            }
        }
    }

    // Export Logic
    enum ExportFormat { case jpeg, pdf }
    
    @MainActor
    private func exportMap(as format: ExportFormat) {
        isExporting = true
        
        let nodes = network.nodes
        let edges = network.edges
        let m = mode
        let gSize = appState.globalFontSize
        let gWidth = appState.globalLineWidth
        
        let lns = lines.lines
        let schs = appState.simulator.schedules
        
        Task {
            // 1. Prepare data in background
            let snapshotData = await Task.detached(priority: .userInitiated) {
                return MapSnapshotData.prepare(nodes: nodes, edges: edges, lines: lns, schedules: schs, mode: m, globalFontSize: gSize, globalLineWidth: gWidth)
            }.value
            
            // 2. Render on main thread
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
            let snapshotData = await Task.detached(priority: .userInitiated) {
                return MapSnapshotData.prepare(nodes: nodes, edges: edges, lines: lns, schedules: schs, mode: m, globalFontSize: gSize, globalLineWidth: gWidth)
            }.value
            
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
            let type: Edge.TrackType
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
            let visualType: Node.StationVisualType
            let color: Color
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
            nodes: [Node], 
            edges: [Edge], 
            lines: [RailwayLine], 
            schedules: [TrainSchedule],
            mode: MapVisualizationMode, 
            globalFontSize: Double, 
            globalLineWidth: Double
        ) -> MapSnapshotData {
            let snapshotSize = CGSize(width: 2048, height: 1536)
            let bounds = calculateBounds(for: nodes)
            
            func finalPosition(for node: Node) -> CGPoint {
                let lon = node.longitude ?? 0
                let lat = node.latitude ?? 0
                let baseX = (lon - bounds.minLon) / bounds.xRange * (snapshotSize.width - 100) + 50
                let baseY = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (snapshotSize.height - 100) + 50
                let pPos = CGPoint(x: baseX, y: baseY)
                
                if let parentId = node.parentHubId,
                   let parent = nodes.first(where: { $0.id == parentId }) {
                    let parentLon = parent.longitude ?? 0
                    let parentLat = parent.latitude ?? 0
                    let px = (parentLon - bounds.minLon) / bounds.xRange * (snapshotSize.width - 100) + 50
                    let py = (1.0 - (parentLat - bounds.minLat) / bounds.yRange) * (snapshotSize.height - 100) + 50
                    let parentP = CGPoint(x: px, y: py)
                    
                    let offset: CGFloat = 25.0
                    let direction = node.hubOffsetDirection ?? .bottomRight
                    switch direction {
                    case .topLeft: return CGPoint(x: parentP.x - offset, y: parentP.y - offset)
                    case .topRight: return CGPoint(x: parentP.x + offset, y: parentP.y - offset)
                    case .bottomLeft: return CGPoint(x: parentP.x - offset, y: parentP.y + offset)
                    case .bottomRight: return CGPoint(x: parentP.x + offset, y: parentP.y + offset)
                    }
                }
                return pPos
            }
            
            func generateLineDraws() -> [LineDraw] {
                var drawings: [LineDraw] = []
                struct SegmentKey: Hashable {
                    let from: String; let to: String
                    init(_ a: String, _ b: String) { if a < b { from = a; to = b } else { from = b; to = a } }
                }
                var segmentLineMap: [SegmentKey: [RailwayLine]] = [:]
                for line in lines {
                    let count = line.stations.count
                    if count > 1 {
                        for i in 0..<(count - 1) {
                            let key = SegmentKey(line.stations[i], line.stations[i+1])
                            segmentLineMap[key, default: []].append(line)
                        }
                    }
                }
                
                for (key, segLines) in segmentLineMap {
                    guard let n1 = nodes.first(where: { $0.id == key.from }),
                          let n2 = nodes.first(where: { $0.id == key.to }) else { continue }
                    let p1 = finalPosition(for: n1); let p2 = finalPosition(for: n2)
                    let points = generateSchematicPoints(from: p1, to: p2)
                    let bundleSize = segLines.count
                    
                    for j in 0..<(points.count - 1) {
                        let sp1 = points[j]; let sp2 = points[j+1]
                        let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
                        let offsetBase: CGFloat = 8.0 // Larger for snapshot
                        
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
            
            func generateTrainDraws() -> [TrainDraw] {
                var drawings: [TrainDraw] = []
                let now = Date().normalized()
                for sch in schedules {
                    if let pos = calculateTrainPosition(schedule: sch, now: now, nodes: nodes, bounds: bounds, snapshotSize: snapshotSize) {
                        drawings.append(TrainDraw(pos: pos, name: sch.trainName, color: .red))
                    }
                }
                return drawings
            }
            
            // 1. Edges with parallel track support
            // Group edges by station pairs
            var edgesByPair: [String: [Edge]] = [:]
            for edge in edges {
                let key = edge.canonicalKey
                edgesByPair[key, default: []].append(edge)
            }
            
            var edgesDraw: [EdgeDraw] = []
            for (_, edgeGroup) in edgesByPair {
                guard let firstEdge = edgeGroup.first else { continue }
                guard let n1 = nodes.first(where: { $0.id == firstEdge.from }),
                      let n2 = nodes.first(where: { $0.id == firstEdge.to }) else { continue }
                
                let p1 = finalPosition(for: n1)
                let p2 = finalPosition(for: n2)
                let basePoints = generateSchematicPoints(from: p1, to: p2)
                
                let trackCount = edgeGroup.count
                let offsetDistance: CGFloat = 6.0 // Slightly larger for snapshot visibility
                
                for (index, edge) in edgeGroup.enumerated() {
                    var offsetPoints: [CGPoint] = []
                    
                    if trackCount == 1 {
                        // Single track - no offset
                        offsetPoints = basePoints
                    } else {
                        // Multiple parallel tracks - apply perpendicular offset
                        let offset = (CGFloat(index) - CGFloat(trackCount - 1) / 2.0) * offsetDistance
                        
                        for i in 0..<basePoints.count {
                            let p = basePoints[i]
                            var perpX: CGFloat = 0
                            var perpY: CGFloat = 0
                            
                            if i == 0 && basePoints.count > 1 {
                                let next = basePoints[i + 1]
                                let dx = next.x - p.x
                                let dy = next.y - p.y
                                let len = sqrt(dx * dx + dy * dy)
                                if len > 0 {
                                    perpX = -dy / len
                                    perpY = dx / len
                                }
                            } else if i == basePoints.count - 1 && basePoints.count > 1 {
                                let prev = basePoints[i - 1]
                                let dx = p.x - prev.x
                                let dy = p.y - prev.y
                                let len = sqrt(dx * dx + dy * dy)
                                if len > 0 {
                                    perpX = -dy / len
                                    perpY = dx / len
                                }
                            } else if basePoints.count > 2 {
                                let prev = basePoints[i - 1]
                                let next = basePoints[i + 1]
                                let dx1 = p.x - prev.x
                                let dy1 = p.y - prev.y
                                let len1 = sqrt(dx1 * dx1 + dy1 * dy1)
                                let dx2 = next.x - p.x
                                let dy2 = next.y - p.y
                                let len2 = sqrt(dx2 * dx2 + dy2 * dy2)
                                
                                if len1 > 0 && len2 > 0 {
                                    let perp1X = -dy1 / len1
                                    let perp1Y = dx1 / len1
                                    let perp2X = -dy2 / len2
                                    let perp2Y = dx2 / len2
                                    perpX = (perp1X + perp2X) / 2
                                    perpY = (perp1Y + perp2Y) / 2
                                    let perpLen = sqrt(perpX * perpX + perpY * perpY)
                                    if perpLen > 0 {
                                        perpX /= perpLen
                                        perpY /= perpLen
                                    }
                                }
                            }
                            
                            offsetPoints.append(CGPoint(
                                x: p.x + perpX * offset,
                                y: p.y + perpY * offset
                            ))
                        }
                    }
                    
                    // Usa la nuova funzione per creare curve morbide
                    let path = createSmoothPath(points: offsetPoints)
                    
                    let baseColor: Color = mode.isSchedulerMode ? .gray.opacity(0.3) : .gray
                    edgesDraw.append(EdgeDraw(path: path, points: offsetPoints, color: (edge.trackType == .highSpeed ? .red.opacity(0.8) : .black.opacity(0.8)), type: edge.trackType, baseColor: baseColor))
                }
            }
            
            // 2. Hub Clusters (Explicit logic matching live view)
            var visualGroups: [GroupDraw] = []
            
            let hubNodes = nodes.filter { node in
                node.parentHubId != nil || nodes.contains(where: { $0.parentHubId == node.id })
            }
            
            var hubGroupsLookup: [String: [Node]] = [:]
            for node in hubNodes {
                let hubId = node.parentHubId ?? node.id
                hubGroupsLookup[hubId, default: []].append(node)
            }
            
            for (hubId, gNodes) in hubGroupsLookup {
                if gNodes.count > 1 {
                    let positions = gNodes.map { finalPosition(for: $0) }
                    let maxY = positions.map { $0.y }.max() ?? positions[0].y
                    let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                    
                    let rootNode = gNodes.first(where: { $0.id == hubId }) ?? gNodes.first
                    visualGroups.append(GroupDraw(
                        positions: positions,
                        label: rootNode?.name ?? "",
                        center: CGPoint(x: centerX, y: maxY + 35),
                        bottomY: maxY,
                        isSingle: false
                    ))
                }
            }
            
            // Handle orphan interchanges (single-node hubs)
            let orphanInterchanges = nodes.filter { node in
                node.type == .interchange && 
                hubGroupsLookup[node.parentHubId ?? node.id]?.count ?? 0 <= 1
            }
            for node in orphanInterchanges {
                let p = finalPosition(for: node)
                visualGroups.append(GroupDraw(
                    positions: [p],
                    label: node.name,
                    center: CGPoint(x: p.x, y: p.y + 35),
                    bottomY: p.y,
                    isSingle: true
                ))
            }
            
            let nodesDraw = nodes.map { node -> NodeDraw in
                let visualType = node.visualType ?? node.defaultVisualType
                let color = Color(hex: node.customColor ?? node.defaultColor) ?? .black
                return NodeDraw(pos: finalPosition(for: node), name: node.name, isHub: node.type == .interchange, visualType: visualType, color: color)
            }
            
            let linesDraw = mode.isSchedulerMode ? generateLineDraws() : []
            let trainsDraw = mode.isSchedulerMode ? generateTrainDraws() : []
            
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
        
        // Static helpers (Sendable)
        static func calculateTrainPosition(schedule: TrainSchedule, now: Date, nodes: [Node], bounds: MapBounds, snapshotSize: CGSize) -> CGPoint? {
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

        static func finalPositionStatic(for node: Node, bounds: MapBounds, snapshotSize: CGSize) -> CGPoint {
            let lon = node.longitude ?? 0; let lat = node.latitude ?? 0
            return CGPoint(
                x: (lon - bounds.minLon) / bounds.xRange * (snapshotSize.width - 100) + 50,
                y: (1.0 - (lat - bounds.minLat) / bounds.yRange) * (snapshotSize.height - 100) + 50
            )
        }

        static func calculateBounds(for nodes: [Node]) -> MapBounds {
            let lats = nodes.compactMap { $0.latitude }; let lons = nodes.compactMap { $0.longitude }
            let minLat = lats.min() ?? 38.0; let maxLat = lats.max() ?? 48.0
            let minLon = lons.min() ?? 7.0; let maxLon = lons.max() ?? 19.0
            let xr = maxLon - minLon; let yr = maxLat - minLat
            let padX = xr == 0 ? 0.5 : xr * 0.1; let padY = yr == 0 ? 0.5 : yr * 0.1
            return MapBounds(minLat: minLat - padY, maxLat: maxLat + padY, minLon: minLon - padX, maxLon: maxLon + padX, xRange: xr + 2*padX, yRange: yr + 2*padY)
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
    }

    // Dedicated Snapshot View using direct Canvas drawing 
    struct RailwayMapSnapshot: View {
        @EnvironmentObject var appState: AppState
        let data: MapSnapshotData
        
        private func offsetPoints(_ points: [CGPoint], by offset: CGFloat) -> [CGPoint] {
            guard points.count > 1 else { return points }
            var result: [CGPoint] = []
            result.reserveCapacity(points.count)
            for i in 0..<points.count {
                let p = points[i]
                var perpX: CGFloat = 0
                var perpY: CGFloat = 0
                
                if i == 0 {
                    let next = points[i + 1]
                    let dx = next.x - p.x
                    let dy = next.y - p.y
                    let len = sqrt(dx * dx + dy * dy)
                    if len > 0 {
                        perpX = -dy / len
                        perpY = dx / len
                    }
                } else if i == points.count - 1 {
                    let prev = points[i - 1]
                    let dx = p.x - prev.x
                    let dy = p.y - prev.y
                    let len = sqrt(dx * dx + dy * dy)
                    if len > 0 {
                        perpX = -dy / len
                        perpY = dx / len
                    }
                } else {
                    let prev = points[i - 1]
                    let next = points[i + 1]
                    let dx1 = p.x - prev.x
                    let dy1 = p.y - prev.y
                    let len1 = sqrt(dx1 * dx1 + dy1 * dy1)
                    let dx2 = next.x - p.x
                    let dy2 = next.y - p.y
                    let len2 = sqrt(dx2 * dx2 + dy2 * dy2)
                    if len1 > 0 && len2 > 0 {
                        let perp1X = -dy1 / len1
                        let perp1Y = dx1 / len1
                        let perp2X = -dy2 / len2
                        let perp2Y = dx2 / len2
                        perpX = (perp1X + perp2X) / 2
                        perpY = (perp1Y + perp2Y) / 2
                        let perpLen = sqrt(perpX * perpX + perpY * perpY)
                        if perpLen > 0 {
                            perpX /= perpLen
                            perpY /= perpLen
                        }
                    }
                }
                
                result.append(CGPoint(x: p.x + perpX * offset, y: p.y + perpY * offset))
            }
            return result
        }
        
        private func symbolSystemName(for type: Node.StationVisualType) -> String {
            switch type {
            case .filledSquare: return "square.fill"
            case .emptySquare: return "square"
            case .filledCircle: return "circle.fill"
            case .emptyCircle: return "circle"
            case .filledStar: return "star.fill"
            }
        }
        
        var body: some View {
            Canvas { context, size in
                // 1. Draw Edges
                for edge in data.edges {
                    if edge.type == .highSpeed {
                        // High-Speed Style Consistency
                        context.stroke(edge.path, with: .color(.red), style: StrokeStyle(lineWidth: appState.trackWidthHighSpeed, lineCap: .square))
                        context.stroke(edge.path, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: appState.trackWidthHighSpeed * 0.4, lineCap: .round, dash: [3, 3]))
                    } else if edge.type == .double {
                        let separation = max(3.0, appState.trackWidthDouble * 0.6)
                        let lineWidth = max(1.5, appState.trackWidthDouble * 0.35)
                        let leftPath = createSmoothPath(points: offsetPoints(edge.points, by: separation / 2))
                        let rightPath = createSmoothPath(points: offsetPoints(edge.points, by: -separation / 2))
                        context.stroke(leftPath, with: .color(.black.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        context.stroke(rightPath, with: .color(.black.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    } else if edge.type == .regional {
                        context.stroke(edge.path, with: .color(.blue.opacity(0.6)), style: StrokeStyle(lineWidth: appState.trackWidthRegional, lineCap: .round))
                    } else {
                        context.stroke(edge.path, with: .color(.gray.opacity(0.8)), style: StrokeStyle(lineWidth: data.globalLineWidth * 0.6, lineCap: .round))
                    }
                }
                
                // 1.5 Draw Commercial Lines with Bundle Effect
                // Group lines by bundleSize to draw gradient bundles
                var bundleGroups: [[MapSnapshotData.LineDraw]] = []
                var currentBundle: [MapSnapshotData.LineDraw] = []
                var lastBundleSize = 0
                
                for l in data.lines.sorted(by: { $0.bundleSize > $1.bundleSize }) {
                    if l.bundleSize != lastBundleSize && !currentBundle.isEmpty {
                        bundleGroups.append(currentBundle)
                        currentBundle = []
                    }
                    currentBundle.append(l)
                    lastBundleSize = l.bundleSize
                }
                if !currentBundle.isEmpty {
                    bundleGroups.append(currentBundle)
                }
                
                for bundle in bundleGroups {
                    guard let first = bundle.first else { continue }
                    
                    if first.bundleSize > 3 {
                        // INNOVATIVE: For >3 lines bundles, draw single gradient line with diamonds
                        // Since all lines in the bundle share the same path, just draw once with gradient
                        let colors = bundle.map { $0.color }
                        // Extract path endpoints for gradient
                        context.stroke(first.path, with: .color(.black.opacity(0.1)), 
                                     style: StrokeStyle(lineWidth: appState.globalLineWidth * 2.2, lineCap: .round))
                        context.stroke(first.path, with: .color(colors.first ?? .gray), 
                                     style: StrokeStyle(lineWidth: appState.globalLineWidth * 1.8, lineCap: .round))
                        // Note: Canvas doesn't support gradient strokes easily, using first color as fallback
                    } else {
                        // Normal rendering for 1-3 lines
                        for l in bundle {
                            context.stroke(l.path, with: .color(l.color), 
                                         style: StrokeStyle(lineWidth: appState.globalLineWidth, lineCap: .round))
                        }
                    }
                }
                
                // 2. Hubs & Groups (Explicit logic matching live View)
                for group in data.groups {
                    if !group.isSingle {
                        for i in 0..<group.positions.count {
                            for j in (i+1)..<group.positions.count {
                                let path = Path { p in p.move(to: group.positions[i]); p.addLine(to: group.positions[j]) }
                                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            }
                        }
                    }
                    
                    let text = Text(group.label)
                        .font(.system(size: data.globalFontSize, weight: .bold))
                        .foregroundColor(.red)
                    let resolved = context.resolve(text)
                    let sz = resolved.measure(in: CGSize(width: 400, height: 100))
                    
                    let bg = Path(roundedRect: CGRect(x: group.center.x - sz.width/2 - 4, y: group.center.y - sz.height/2 - 2, width: sz.width + 8, height: sz.height + 4), cornerRadius: 4)
                    context.fill(bg, with: .color(.white.opacity(0.8)))
                    context.draw(resolved, at: group.center)
                }
                
                // 3. Independent Nodes
                for node in data.nodes {
                    if node.isHub {
                         context.fill(Path(ellipseIn: CGRect(x: node.pos.x - 7, y: node.pos.y - 7, width: 14, height: 14)), with: .color(.white))
                         context.stroke(Path(ellipseIn: CGRect(x: node.pos.x - 9.5, y: node.pos.y - 9.5, width: 19, height: 19)), with: .color(.red), lineWidth: 5)
                    } else {
                         context.fill(Path(ellipseIn: CGRect(x: node.pos.x - 10, y: node.pos.y - 10, width: 20, height: 20)), with: .color(.white))
                        let symbol = Text(Image(systemName: symbolSystemName(for: node.visualType)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(node.color)
                        context.draw(symbol, at: node.pos)
                        
                        let label = Text(node.name)
                            .font(.system(size: data.globalFontSize, weight: .black))
                            .foregroundColor(.black)
                        context.draw(label, at: CGPoint(x: node.pos.x, y: node.pos.y + 28))
                    }
                }
                
                // 4. Draw Trains
                for t in data.trains {
                    let rect = CGRect(x: t.pos.x - 10, y: t.pos.y - 10, width: 20, height: 20)
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(t.color))
                    context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white), lineWidth: 2)
                    let label = Text(t.name).font(.system(size: data.globalFontSize - 2, weight: .bold)).foregroundColor(.black)
                    context.draw(label, at: CGPoint(x: t.pos.x, y: t.pos.y - 20))
                }
            }
            .frame(width: 2048, height: 1536)
            .background(Color.white)
        }
    }
}

struct SchematicRailwayView: View {
    @EnvironmentObject var appState: AppState
    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }
    
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String?
    @Binding var showGrid: Bool
    @Binding var isMoveModeEnabled: Bool
    @Binding var highlightedConflictLocation: String?
    var mode: RailwayMapView.MapVisualizationMode
    
    // Export actions
    var onExport: (RailwayMapView.ExportFormat) -> Void
    var onPrint: () -> Void
    
    @State private var zoomLevel: CGFloat = 2.0
    @State private var editMode: EditMode = .explore
    @State private var isEditToolbarVisible: Bool = false

    // Grid State: managed by parent binding now
    // Track Creation State
    @State private var newTrackFrom: Node? = nil
    @State private var newTrackTo: Node? = nil
    @State private var newTrackType: Edge.TrackType = .regional
    @State private var newTrackDistance: Double = 10.0
    
    private let gridSize: CGFloat = 50.0
    
    // New state for line filtering
    @State private var hiddenLineIds: Set<String> = []
    
    // Track Selection: managed by parent binding
    // Removed local state
    
    enum EditMode: String, CaseIterable, Identifiable {
        case explore = "explore"
        case addTrack = "create_tracks"
        case addStation = "add_station"
        case createLine = "create_line" // Mode for creating lines
        var id: String { rawValue }
        
        var localizedName: String {
            self.rawValue.localized
        }
    }
    
    // Pinch to Zoom state
    @State private var magnification: CGFloat = 1.0
    @State private var showLineCreation: Bool = false
    
    private var totalZoom: CGFloat {
        zoomLevel * magnification
    }
    
    private var coordinateGridStep: Double {
        let zoom = totalZoom
        if zoom < 1.5 { return 10.0 }
        if zoom < 3.0 { return 5.0 }
        return 1.0
    }
    
    struct MapBounds {
        let minLat, maxLat, minLon, maxLon: Double
        let xRange, yRange: Double
    }
    
    private var mapBounds: MapBounds {
        let nodes = network.nodes
        let lats = nodes.compactMap { $0.latitude }
        let lons = nodes.compactMap { $0.longitude }
        
        // Better defaults for Italy area if empty
        let minLat = lats.min() ?? 38.0
        let maxLat = lats.max() ?? 48.0
        let minLon = lons.min() ?? 7.0
        let maxLon = lons.max() ?? 19.0
        
        let xr = maxLon - minLon
        let yr = maxLat - minLat
        
        // Add 10% padding to prevent nodes from sticking to edges
        let padX = xr == 0 ? 0.5 : xr * 0.1
        let padY = yr == 0 ? 0.5 : yr * 0.1
        
        let finalMaxLat = maxLat + padY
        let finalMinLat = minLat - padY
        let finalMaxLon = maxLon + padX
        let finalMinLon = minLon - padX
        
        return MapBounds(minLat: finalMinLat, maxLat: finalMaxLat, minLon: finalMinLon, maxLon: finalMaxLon,
                         xRange: (finalMaxLon - finalMinLon), yRange: (finalMaxLat - finalMinLat))
    }
    
    var body: some View {
        GeometryReader { geo in
            let size = canvasSize(for: geo.size)
            let bounds = self.mapBounds
            let renderData = MapGeometryEngine.generateRenderData(
                network: network,
                lines: lines,
                size: size,
                bounds: bounds,
                selectedLine: selectedLine,
                selectedEdgeId: selectedEdgeId,
                hiddenLineIds: hiddenLineIds
            )
            
            mainViewContainer(size: size, bounds: bounds, renderData: renderData)
        }
        .simultaneousGesture(zoomGesture)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Zoom to Fit
                Button(action: { withAnimation { zoomLevel = 1.0 } }) {
                    Label("reset_zoom".localized, systemImage: "arrow.down.left.and.arrow.up.right")
                }
                
                Menu {
                    Text("lines_visibility".localized)
                    Divider()
                    ForEach(lines.lines) { line in
                        Button(action: {
                            if hiddenLineIds.contains(line.id) {
                                hiddenLineIds.remove(line.id)
                            } else {
                                hiddenLineIds.insert(line.id)
                            }
                        }) {
                            HStack {
                                Text(line.name)
                                if !hiddenLineIds.contains(line.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("show_all_button".localized) {
                        hiddenLineIds.removeAll()
                    }
                } label: {
                    Label("filter_lines".localized, systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
    
    private func canvasSize(for geoSize: CGSize) -> CGSize {
        CGSize(
            width: max(geoSize.width * totalZoom, geoSize.width),
            height: max(geoSize.height * totalZoom, geoSize.height)
        )
    }
    
    @ViewBuilder
    private func mainViewContainer(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ZStack {
            // 1. Map Content (Base)
            scrollViewLayer(size: size, bounds: bounds, renderData: renderData)
            
            // 2. Overlays (Middle)
            lineCreationOverlay
            
            trackCreationOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(editMode == .addTrack) // Only block interaction when active
            
            stationPickingIndicator
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            moveModeOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // 3. Controls (Top - Highest Z-Index)
            MapControlsView(
                isEditToolbarVisible: $isEditToolbarVisible,
                editMode: $editMode,
                isMoveModeEnabled: $isMoveModeEnabled,
                zoomLevel: $zoomLevel,
                onExport: onExport,
                onPrint: onPrint
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
    
    @ViewBuilder
    private func scrollViewLayer(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    mapBasement(size: size, bounds: bounds)
                    scrollingAnchors(size: size, bounds: bounds)
                    mapMainLayers(size: size, bounds: bounds, renderData: renderData)
                }
                .frame(width: size.width, height: size.height)
                .id("content")
            }
            .onChange(of: appState.selectedNodeId) { _, newNodeId in
                if let node = network.nodes.first(where: { $0.id == newNodeId }) {
                    centerOnNode(node, size: size, bounds: bounds, proxy: proxy)
                }
            }
            .onChange(of: appState.selectedLineId) { _, newLineId in
                if let line = lines.lines.first(where: { $0.id == newLineId }) {
                    centerOnLine(line, size: size, bounds: bounds, proxy: proxy)
                }
            }
            .onChange(of: appState.selectedEdgeId) { _, newEdgeId in
                centerOnEdge(newEdgeId, size: size, bounds: bounds, proxy: proxy)
            }
            .onChange(of: appState.selectedTrainIds) { _, newIds in centerOnTrain(Array(newIds), size: size, bounds: bounds, proxy: proxy) }
            .onChange(of: appState.isCreatingLine) { _, isCreating in
                setupLineCreationCallback(isCreating: isCreating)
            }
            .onChange(of: appState.isCreatingTrack) { _, isCreating in
                if isCreating {
                    editMode = .addTrack
                    newTrackFrom = nil
                    newTrackTo = nil
                    // Also ensure sidebar/inspector doesn't block map if we need to tap
                } else {
                    if editMode == .addTrack {
                        editMode = .explore
                        newTrackFrom = nil
                        newTrackTo = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func mapBasement(size: CGSize, bounds: MapBounds) -> some View {
        ZStack {
            Color.white
            if showGrid {
                CoordinateGridShape(bounds: bounds, unit: coordinateGridStep, size: size)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            }
        }
        .frame(width: size.width, height: size.height)
        .onTapGesture { location in handleCanvasTap(at: location, in: size) }
        .onLongPressGesture(minimumDuration: 0.6) { handleCanvasLongPress() }
    }
    
    @ViewBuilder
    private func scrollingAnchors(size: CGSize, bounds: MapBounds) -> some View {
        ForEach(network.nodes) { node in
            Color.clear
                .frame(width: 1, height: 1)
                .position(MapGeometryEngine.finalPosition(for: node, in: size, bounds: bounds, network: network))
                .id("node-\(node.id)")
        }
    }
    
    @ViewBuilder
    private func mapMainLayers(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ZStack {
            InfrastructureCanvas(
                mode: mode,
                renderData: renderData,
                totalZoom: totalZoom
            )
            .allowsHitTesting(false)
            
            if !appState.simulator.schedules.isEmpty && mode.isSchedulerMode {
                TrainOverlayCanvas(bounds: bounds, canvasSize: size, totalZoom: totalZoom)
                    .allowsHitTesting(false)
            }
            
            StationMarkersView(
                selectedNode: $selectedNode,
                selectedLine: $selectedLine,
                selectedEdgeId: $selectedEdgeId,
                canvasSize: size,
                bounds: bounds,
                showGrid: showGrid,
                coordinateGridStep: coordinateGridStep,
                isMoveModeEnabled: $isMoveModeEnabled,
                onTap: { handleStationTap($0) }
            )
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification = $0 }
            .onEnded { value in
                zoomLevel *= value
                magnification = 1.0
            }
    }

    private func handleCanvasLongPress() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isEditToolbarVisible.toggle()
            if !isEditToolbarVisible {
                editMode = .explore
                isMoveModeEnabled = false
            }
            if mode.isSchedulerMode && isEditToolbarVisible {
                // Instead of overlay, switch to Inspector Panel for creation
                appState.showPanel(.inspector)
                // We need a way to tell the Inspector to show "Line Creation"
                // Assuming AppState has a selected object paradigm. 
                // We'll set a flag or select a dummy object.
                // For now, let's assume we toggle the EditMode to .createLine
                editMode = .createLine
                appState.selectedLineId = nil // Ensure no line is selected
                appState.selectedTrainIds = []
            }
        }
    }

    // Universal method to center any position in the viewport
    private func centerOnPosition(_ position: CGPoint, canvasSize: CGSize, proxy: ScrollViewProxy) {
        // Calculate relative position (0.0 - 1.0) within the canvas
        let unitX = position.x / canvasSize.width
        let unitY = position.y / canvasSize.height
        
        print("📍 Element position: \(position)")
        print("📐 Canvas size: \(canvasSize)")
        print("🎯 UnitPoint: (x: \(unitX), y: \(unitY))")
        
        withAnimation(.easeInOut(duration: 0.4)) {
            proxy.scrollTo("content", anchor: UnitPoint(x: unitX, y: unitY))
        }
    }
    
    private func centerOnNode(_ node: Node?, size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy) {
        guard let node = node else { return }
        let position = MapGeometryEngine.finalPosition(for: node, in: size, bounds: bounds, network: network)
        print("🎯 Centering on node: \(node.name) with ID: \(node.id)")
        centerOnPosition(position, canvasSize: size, proxy: proxy)
    }

    private func centerOnLine(_ line: RailwayLine?, size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy) {
        guard let line = line, 
              let firstId = line.stops.first?.stationId,
              let firstNode = network.nodes.first(where: { $0.id == firstId }) else { return }
        centerOnNode(firstNode, size: size, bounds: bounds, proxy: proxy)
    }

    private func centerOnEdge(_ edgeId: String?, size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy) {
        guard let edgeId = edgeId, 
              let edge = network.edges.first(where: { $0.id.uuidString == edgeId }),
              let fromNode = network.nodes.first(where: { $0.id == edge.from }) else { return }
        centerOnNode(fromNode, size: size, bounds: bounds, proxy: proxy)
    }

    private func centerOnTrain(_ ids: [UUID], size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy) {
        guard let trainId = ids.first, 
              let schedule = appState.simulator.schedules.first(where: { $0.trainId == trainId }) else { return }
        let now = appState.liveSim.currentSimTime
        if let pos = MapGeometryEngine.currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds, network: network) {
            centerOnPosition(pos, canvasSize: size, proxy: proxy)
        }
    }
    
    private func setupLineCreationCallback(isCreating: Bool) {
        if isCreating {
            print("🟢 Setting up line creation callback")
            // Capture references we need
            let appState = self.appState
            let network = self.network
            // Setup callback for line creation mode
            appState.stationPickingCallback = { stationId in
                print("🎯 Station tapped: \(stationId)")
                
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                
                // Re-show inspector if hidden (so user can see the updated list)
                if !appState.isInspectorVisible {
                    print("📱 Re-showing inspector")
                    appState.showPanel(.inspector)
                }
                
                withAnimation(.spring()) {
                    if let lastId = appState.lineDraftStations.last {
                        print("📍 Last station: \(lastId)")
                        if lastId == stationId { 
                            print("⚠️ Same station, skipping")
                            return 
                        }
                        
                        // SMART PATHFINDING
                        let neighbors = network.getConnectedNodeIds(for: lastId)
                        if neighbors.contains(stationId) {
                            print("✅ Direct connection found")
                            appState.lineDraftStations.append(stationId)
                        } else {
                            print("🔍 Finding shortest path...")
                            // Find shortest path
                            if let (path, _) = network.findShortestPath(from: lastId, to: stationId) {
                                print("✅ Path found with \(path.count) stations")
                                for nodeId in path.dropFirst() {
                                    if !appState.lineDraftStations.contains(nodeId) || nodeId == stationId {
                                        appState.lineDraftStations.append(nodeId)
                                    }
                                }
                            } else {
                                print("❌ No path found")
                            }
                        }
                    } else {
                        print("✅ First station")
                        appState.lineDraftStations.append(stationId)
                    }
                    print("📋 Draft stations count: \(appState.lineDraftStations.count)")
                }
            }
        } else {
            print("🔴 Cleaning up line creation callback")
            // Cleanup callback when exiting line creation mode
            appState.stationPickingCallback = nil
        }
    }

    @ViewBuilder
    private var lineCreationOverlay: some View {
        EmptyView() // Moved to Inspector
    }

    @ViewBuilder
    private var trackCreationOverlay: some View {
        if editMode == .addTrack {
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text("new_track".localized)
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("from_label".localized)
                                .font(.caption).foregroundColor(.secondary)
                            Text(newTrackFrom?.name ?? "select_station_placeholder".localized)
                                .fontWeight(.bold)
                                .foregroundColor(newTrackFrom == nil ? .gray : (.primary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "arrow.right")
                        
                        VStack(alignment: .trailing) {
                            Text("to_label".localized)
                                .font(.caption).foregroundColor(.secondary)
                            Text(newTrackTo?.name ?? "select_station_placeholder".localized)
                                .fontWeight(.bold)
                                .foregroundColor(newTrackTo == nil ? .gray : (.primary))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text("distance_label".localized).font(.caption).foregroundColor(.secondary)
                        TextField("km", value: $newTrackDistance, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("km")
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(Edge.TrackType.allCases) { type in
                            Button(action: { newTrackType = type }) {
                                trackTypeButtonContent(type: type)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    trackCreationActions
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Material.ultraThinMaterial)
                        .background(Color(UIColor.systemGray6).opacity(0.8))
                        .shadow(color: Color.gray.opacity(0.2), radius: 10)
                )
                .padding()
                .frame(maxWidth: 400)
            }
            .transition(.move(edge: .bottom))
        }
    }
    
    @ViewBuilder
    private func trackTypeButtonContent(type: Edge.TrackType) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if type == .double || type == .highSpeed {
                    HStack(spacing: 2) {
                        Capsule().fill(type.color).frame(width: 3, height: 16)
                        Capsule().fill(type.color).frame(width: 3, height: 16)
                    }
                } else {
                    Capsule().fill(type.color).frame(width: 6, height: 16)
                }
            }
            .frame(height: 20)
            
            Text(type.displayName)
                .font(.system(size: 10, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(newTrackType == type ? type.color.opacity(0.15) : Color.gray.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(newTrackType == type ? type.color : Color.clear, lineWidth: 2)
        )
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private var trackCreationActions: some View {
        HStack {
            Button("close".localized) {
                newTrackFrom = nil
                newTrackTo = nil
                editMode = .explore
            }
            .foregroundColor(.secondary)
            .padding(.horizontal)
            
            Button(action: createTrack) {
                Text("create_track_button".localized)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint((newTrackFrom != nil && newTrackTo != nil) ? Color.accentColor : Color.gray)
            .disabled(newTrackFrom == nil || newTrackTo == nil)
        }
    }

    @ViewBuilder
    private var stationPickingIndicator: some View {
        if appState.stationPickingCallback != nil {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "cursorarrow.click.2")
                        .symbolEffect(.pulse)
                        .foregroundColor(.accentColor)
                    Text("Seleziona una stazione sulla mappa")
                        .font(.system(size: 14, weight: .bold))
                    
                    Button(action: {
                        withAnimation { appState.stationPickingCallback = nil }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                .padding(.top, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private var moveModeOverlay: some View {
        if isMoveModeEnabled {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .symbolEffect(.bounce, value: isMoveModeEnabled)
                    Text("station_moving_active".localized)
                        .font(.system(size: 14, weight: .bold))
                    
                    Button(action: {
                        withAnimation { isMoveModeEnabled = false }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                .padding(.top, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    // MARK: - Interaction Handlers
    private func handleStationTap(_ node: Node) {
        if let pickingCallback = appState.stationPickingCallback {
            pickingCallback(node.id)
            return
        }
        
        if editMode == .addTrack {
             // ... (keep existing logic)
             if appState.trackDraftFromId == nil {
                appState.trackDraftFromId = node.id
                newTrackFrom = node
            } else if appState.trackDraftFromId == node.id {
                appState.trackDraftFromId = nil
                newTrackFrom = nil
            } else {
                appState.trackDraftToId = node.id
                newTrackTo = node
                if let fromId = appState.trackDraftFromId,
                   let n1 = network.nodes.first(where: { $0.id == fromId }) {
                    let lat1 = n1.latitude ?? 0; let lon1 = n1.longitude ?? 0
                    let lat2 = node.latitude ?? 0; let lon2 = node.longitude ?? 0
                    let dLat = lat1 - lat2
                    let dLon = lon1 - lon2
                    let distKm = sqrt(dLat*dLat + dLon*dLon) * 111.0
                    newTrackDistance = max(1.0, round(distKm * 10) / 10.0)
                }
            }
        } else {
            // Priority selection logic with Animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // If we want multi-selection, we need AppState support. 
                // For now, standard behavior:
                selectedNode = node
                selectedLine = nil
                selectedEdgeId = nil
            }
        }
    }
    
    private func createTrack() {
        guard let n1 = newTrackFrom, let n2 = newTrackTo else { return }
        
        // Get speed from AppState based on track type
        let speed: Int
        switch newTrackType {
        case .single:
            speed = Int(appState.singleTrackMaxSpeed)
        case .double:
            speed = Int(appState.doubleTrackMaxSpeed)
        case .regional:
            speed = Int(appState.regionalTrackMaxSpeed)
        case .highSpeed:
            speed = Int(appState.highSpeedTrackMaxSpeed)
        }
        
        
        let newEdge = Edge(from: n1.id, to: n2.id, distance: newTrackDistance, trackType: newTrackType, maxSpeed: speed, capacity: 10)
        network.addEdge(newEdge)
        
        // Note: Pathfinding treats all edges as bidirectional, so no need to create return edge
        
        // Auto-select the NEW edge
        withAnimation {
            selectedEdgeId = newEdge.id.uuidString
            selectedNode = nil
            selectedLine = nil
        }
        
        // Reset selection contents for logic
        newTrackFrom = nil
        newTrackTo = nil
        appState.trackDraftFromId = nil
        appState.trackDraftToId = nil
        
        // Auto-exit mode
        editMode = .explore
        appState.isCreatingTrack = false
    }
    
    private func handleCanvasTap(at location: CGPoint, in size: CGSize) {
        let bounds = self.mapBounds
        
        // 0. Check Trains (Moving objects on top)
        let now = appState.liveSim.currentSimTime
        // Filter out finished trains if needed, but schedules usually contains active ones
        for schedule in appState.simulator.schedules {
            if let pos = MapGeometryEngine.currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds, network: network) {
                // Hit test radius: 20 points
                if hypot(pos.x - location.x, pos.y - location.y) < 20 {
                     // Found train
                     withAnimation {
                         appState.selectedTrainIds = [schedule.trainId]
                         appState.selectedNodeId = nil
                         appState.selectedLineId = nil
                         appState.selectedEdgeId = nil
                         appState.showPanel(.inspector)
                     }
                     return
                }
            }
        }
        
        // 1. Check Stations (using MapGeometry)
        for node in network.nodes {
            let p = MapGeometryEngine.finalPosition(for: node, in: size, bounds: bounds, network: network)
            if hypot(p.x - location.x, p.y - location.y) < MapConstants.hitTestRadius {
                handleStationTap(node)
                return
            }
        }
        
        // 2. Check Track Segments (Edges) - Visual hit testing with parallel track support
        var newSelectedEdgeId: String? = nil
        
        // Group edges by station pairs to apply parallel track offsets
        var edgesByPair: [String: [Edge]] = [:]
        for edge in network.edges {
            let key = edge.canonicalKey
            edgesByPair[key, default: []].append(edge)
        }
        
        for (_, edgeGroup) in edgesByPair {
            guard let firstEdge = edgeGroup.first else { continue }
            guard let n1 = network.nodes.first(where: { $0.id == firstEdge.from }),
                  let n2 = network.nodes.first(where: { $0.id == firstEdge.to }) else { continue }
            
            let p1 = MapGeometryEngine.finalPosition(for: n1, in: size, bounds: bounds, network: network)
            let p2 = MapGeometryEngine.finalPosition(for: n2, in: size, bounds: bounds, network: network)
            let basePoints = MapGeometryEngine.generateSchematicPoints(from: p1, to: p2)
            
            let trackCount = edgeGroup.count
            let offsetDistance: CGFloat = 4.0
            
            for (index, edge) in edgeGroup.enumerated() {
                var offsetPoints: [CGPoint] = []
                
                if trackCount == 1 {
                    offsetPoints = basePoints
                } else {
                    let offset = (CGFloat(index) - CGFloat(trackCount - 1) / 2.0) * offsetDistance
                    
                    for i in 0..<basePoints.count {
                        let p = basePoints[i]
                        var perpX: CGFloat = 0
                        var perpY: CGFloat = 0
                        
                        if i == 0 && basePoints.count > 1 {
                            let next = basePoints[i + 1]
                            let dx = next.x - p.x
                            let dy = next.y - p.y
                            let len = sqrt(dx * dx + dy * dy)
                            if len > 0 {
                                perpX = -dy / len
                                perpY = dx / len
                            }
                        } else if i == basePoints.count - 1 && basePoints.count > 1 {
                            let prev = basePoints[i - 1]
                            let dx = p.x - prev.x
                            let dy = p.y - prev.y
                            let len = sqrt(dx * dx + dy * dy)
                            if len > 0 {
                                perpX = -dy / len
                                perpY = dx / len
                            }
                        } else if basePoints.count > 2 {
                            let prev = basePoints[i - 1]
                            let next = basePoints[i + 1]
                            let dx1 = p.x - prev.x
                            let dy1 = p.y - prev.y
                            let len1 = sqrt(dx1 * dx1 + dy1 * dy1)
                            let dx2 = next.x - p.x
                            let dy2 = next.y - p.y
                            let len2 = sqrt(dx2 * dx2 + dy2 * dy2)
                            
                            if len1 > 0 && len2 > 0 {
                                let perp1X = -dy1 / len1
                                let perp1Y = dx1 / len1
                                let perp2X = -dy2 / len2
                                let perp2Y = dx2 / len2
                                perpX = (perp1X + perp2X) / 2
                                perpY = (perp1Y + perp2Y) / 2
                                let perpLen = sqrt(perpX * perpX + perpY * perpY)
                                if perpLen > 0 {
                                    perpX /= perpLen
                                    perpY /= perpLen
                                }
                            }
                        }
                        
                        offsetPoints.append(CGPoint(
                            x: p.x + perpX * offset,
                            y: p.y + perpY * offset
                        ))
                    }
                }
                
                // Hit test against offset points
                for i in 0..<(offsetPoints.count - 1) {
                    if distanceToSegment(p: location, v: offsetPoints[i], w: offsetPoints[i+1]) < 40 {
                        newSelectedEdgeId = edge.id.uuidString
                        break
                    }
                }
                if newSelectedEdgeId != nil { break }
            }
            if newSelectedEdgeId != nil { break }
        }
        
        // 3. Check Commercial Lines
        var newSelectedLine: RailwayLine? = nil
        if mode.isSchedulerMode {
            for line in lines.lines {
                if hiddenLineIds.contains(line.id) { continue }
                guard line.stations.count >= 2 else { continue }
                for i in 0..<(line.stations.count - 1) {
                    guard let n1 = network.nodes.first(where: { $0.id == line.stations[i] }),
                          let n2 = network.nodes.first(where: { $0.id == line.stations[i+1] }) else { continue }
                    let p1 = MapGeometryEngine.finalPosition(for: n1, in: size, bounds: bounds, network: network)
                    let p2 = MapGeometryEngine.finalPosition(for: n2, in: size, bounds: bounds, network: network)
                    let points = MapGeometryEngine.generateSchematicPoints(from: p1, to: p2)
                    for j in 0..<(points.count - 1) {
                        if distanceToSegment(p: location, v: points[j], w: points[j+1]) < 35 {
                            newSelectedLine = line
                            break
                        }
                    }
                    if newSelectedLine != nil { break }
                }
                if newSelectedLine != nil { break }
            }
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if editMode == .addStation {
                let newNode = createStation(at: location, in: size)
                handleStationTap(newNode)
            } else if let line = newSelectedLine {
                selectedLine = line
                selectedNode = nil
                selectedEdgeId = nil
                print("🎯 [Map] Selected Line: \(line.name)")
            } else if let edgeId = newSelectedEdgeId {
                selectedEdgeId = edgeId
                selectedNode = nil
                selectedLine = nil
                print("🎯 [Map] Selected Track Segment: \(edgeId)")
            } else if editMode == .explore {
                selectedNode = nil
                selectedLine = nil
                selectedEdgeId = nil
                print("🎯 [Map] Selection Cleared")
            }
        }
    }
    
    private func distanceToSegment(p: CGPoint, v: CGPoint, w: CGPoint) -> CGFloat {
        let l2 = (v.x - w.x)*(v.x - w.x) + (v.y - w.y)*(v.y - w.y)
        if l2 == 0 { return hypot(p.x - v.x, p.y - v.y) }
        var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
        t = max(0, min(1, t))
        let proj = CGPoint(x: v.x + t * (w.x - v.x), y: v.y + t * (w.y - v.y))
        return hypot(p.x - proj.x, p.y - proj.y)
    }
    
    @discardableResult
    private func createStation(at location: CGPoint, in size: CGSize) -> Node {
        let lats = network.nodes.compactMap { $0.latitude }
        let lons = network.nodes.compactMap { $0.longitude }
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 100
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 100
        
        let xRange = maxLon - minLon
        let yRange = maxLat - minLat
        let safeXRange = xRange == 0 ? 1.0 : xRange
        let safeYRange = yRange == 0 ? 1.0 : yRange
        
        let drawWidth = size.width - 100
        let safeDrawWidth = drawWidth > 0 ? drawWidth : 1
        let safeDrawHeight = (size.height - 100) > 0 ? (size.height - 100) : 1
        
        let lon = minLon + ((location.x - 50) / safeDrawWidth) * safeXRange
        let lat = minLat + (1.0 - (location.y - 50) / safeDrawHeight) * safeYRange
        
        let name = String(format: "station_default_name".localized, network.nodes.count + 1)
        
        let newNode = Node(id: UUID().uuidString, name: name, type: .station, latitude: lat, longitude: lon, capacity: 10, platforms: 2)
        network.addNode(newNode)
        print("📍 Nuova stazione creata: \(name) a [\(lat), \(lon)]")
        return newNode
    }
}

// MARK: - Station Node View
struct StationNodeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var node: RailwayNode
    private var network: NetworkModel { appState.railroad.network }
    var canvasSize: CGSize
    var isSelected: Bool
    var snapToGrid: Bool
    var gridUnit: Double
    var bounds: SchematicRailwayView.MapBounds
    var onTap: () -> Void
    @Binding var isMoveModeEnabled: Bool
    var onDragStarted: (() -> Void)? = nil
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        stationContent
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .background(Circle().fill(Color.white).opacity(0.001))
            .overlay(selectionOverlay)
            .overlay(alignment: .top) { labelOverlay }
            .onLongPressGesture(minimumDuration: 0.5) { // Use explicit value if MapConstants not visible, or assume MapConstants
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isMoveModeEnabled.toggle()
                }
                #if os(macOS)
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                #elseif canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            }
            .onTapGesture { onTap() }
            .gesture(
                isMoveModeEnabled ?
                    DragGesture(minimumDistance: 1)
                        .onChanged { val in
                            if dragOffset == .zero { onDragStarted?() }
                            dragOffset = val.translation
                        }
                        .onEnded { val in
                            // Commit changes using the final drag offset
                            let drawWidth = max(canvasSize.width - 100, 1) // Using 100 padding as per projection logic
                            let drawHeight = max(canvasSize.height - 100, 1)
                            
                            // Inverse projection delta
                            // We use val.translation which is total drag from start
                            
                            let dLon = (val.translation.width / drawWidth) * bounds.xRange
                            let dLat = -(val.translation.height / drawHeight) * bounds.yRange // Y is inverted because map Y grows down
                            
                            var newNode = node
                            let lat = (newNode.latitude ?? 0) + dLat
                            let lon = (newNode.longitude ?? 0) + dLon
                            
                            if snapToGrid {
                                let unit = gridUnit
                                newNode.latitude = round(lat / unit) * unit
                                newNode.longitude = round(lon / unit) * unit
                            } else {
                                newNode.latitude = lat
                                newNode.longitude = lon
                            }
                            
                            node = newNode // This triggers AppState update
                            dragOffset = .zero
                        }
                : nil
            )
            .offset(dragOffset)
    }

    @ViewBuilder
    private var stationContent: some View {
        if node.type == .interchange {
            ZStack {
                Circle().fill(Color.white).frame(width: 14, height: 14)
                Circle().stroke(Color.red, lineWidth: 5).frame(width: 19, height: 19)
            }
        } else {
            let color = Color(hex: node.customColor ?? node.defaultColor) ?? .black
            let visualType = node.visualType ?? node.defaultVisualType
            ZStack {
                Circle().fill(Color.white).frame(width: 20, height: 20)
                symbolView(type: visualType, color: color).frame(width: 24, height: 24)
            }
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        Group {
            if isSelected {
                Circle().stroke(Color.blue, lineWidth: 2).scaleEffect(1.4)
            }
            if isMoveModeEnabled {
                Circle().stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2])).scaleEffect(1.3)
            }
        }
    }

    @ViewBuilder
    private var labelOverlay: some View {
        let isPartOfMultiNodeHub = network.nodes.contains { 
            ($0.parentHubId == node.id || (node.parentHubId != nil && $0.parentHubId == node.parentHubId && $0.id != node.id))
        }
        if !isPartOfMultiNodeHub {
            Text(node.name)
                .font(.system(size: appState.globalFontSize, weight: .black))
                .fixedSize()
                .foregroundColor(.black)
                .shadow(color: .white, radius: 2)
                .offset(y: 28)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    func symbolView(type: RailwayNode.StationVisualType, color: Color) -> some View {
        switch type {
        case .filledSquare:
            Image(systemName: "square.fill").symbolRenderingMode(.palette).foregroundStyle(color)
        case .emptySquare:
            Image(systemName: "square").symbolRenderingMode(.palette).foregroundStyle(color).fontWeight(.bold)
        case .filledCircle:
            Image(systemName: "circle.fill").symbolRenderingMode(.palette).foregroundStyle(color)
        case .emptyCircle:
            Image(systemName: "circle").symbolRenderingMode(.palette).foregroundStyle(color).fontWeight(.bold)
        case .filledStar:
            Image(systemName: "star.fill").symbolRenderingMode(.palette).foregroundStyle(color)
        }
    }
}

struct CoordinateGridShape: Shape {
    var bounds: SchematicRailwayView.MapBounds
    var unit: Double
    var size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        func projectX(_ lon: Double) -> CGFloat {
            let x = (lon - bounds.minLon) / bounds.xRange * Double(size.width - 100) + 50.0
            return CGFloat(x)
        }
        func projectY(_ lat: Double) -> CGFloat {
            let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * Double(size.height - 100) + 50.0
            return CGFloat(y)
        }

        // Vertical lines (constant Longitude)
        let minL = floor(bounds.minLon / unit) * unit
        let maxL = ceil(bounds.maxLon / unit) * unit
        
        var currentLon = minL
        while currentLon <= maxL {
            let x = projectX(currentLon)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            currentLon += unit
        }
        
        // Horizontal lines (constant Latitude)
        let minA = floor(bounds.minLat / unit) * unit
        let maxA = ceil(bounds.maxLat / unit) * unit
        
        var currentLat = minA
        while currentLat <= maxA {
            let y = projectY(currentLat)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            currentLat += unit
        }
        
        return path
    }
}
 

struct MapControlsView: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    
    @Binding var isEditToolbarVisible: Bool
    @Binding var editMode: SchematicRailwayView.EditMode
    @Binding var isMoveModeEnabled: Bool
    @Binding var zoomLevel: CGFloat
    
    var onExport: (RailwayMapView.ExportFormat) -> Void
    var onPrint: () -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 20) {
            
            // Edit Mode Toggle (Always Visible)
            Button(action: {
                withAnimation {
                    isEditToolbarVisible.toggle()
                    if !isEditToolbarVisible {
                        editMode = .explore
                        isMoveModeEnabled = false
                    }
                }
            }) {
                RailwayInteractionIcon(
                    systemName: isEditToolbarVisible ? "pencil.circle.fill" : "pencil.circle",
                    isActive: isEditToolbarVisible,
                    activeColor: .blue
                )
            }
            .help(isEditToolbarVisible ? "Nascondi Strumenti" : "Mostra Strumenti Modifica")
            .buttonStyle(.plain)
            
            // Top: Edit Tools (Only visible when toggled)
            if isEditToolbarVisible {
                VStack(spacing: 8) {
                    Button(action: {
                        editMode = .addStation
                        // No specific AppState flag for station adding yet, but map handles tap
                    }) {
                        RailwayInteractionIcon(systemName: "building.2.fill", isActive: editMode == .addStation, activeColor: .green)
                    }
                    .help("Aggiungi Stazione")
                    // Use plain style to avoid conflicts
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        editMode = .addTrack
                        appState.isCreatingTrack = true
                        appState.showPanel(.inspector)
                    }) {
                        RailwayInteractionIcon(systemName: "point.topleft.down.curvedto.point.bottomright.up", isActive: editMode == .addTrack, activeColor: .orange)
                    }
                    .help("Crea Binari")
                    .buttonStyle(.plain)
                    
                    Button(action: { withAnimation { isMoveModeEnabled.toggle() } }) {
                        RailwayInteractionIcon(systemName: isMoveModeEnabled ? "hand.draw.fill" : "hand.draw", isActive: isMoveModeEnabled, activeColor: .blue)
                    }
                    .help("Sposta Stazioni")
                    
                    Divider().background(Color.white.opacity(0.3)).frame(width: 30)
                    
                    // Undo/Redo Integrated
                    Button(action: { network.undo() }) {
                        RailwayInteractionIcon(systemName: "arrow.uturn.backward.circle", isActive: false, color: network.canUndo ? .primary : .secondary)
                    }
                    .disabled(!network.canUndo)
                    .help("undo".localized)
                    
                    Button(action: { network.redo() }) {
                        RailwayInteractionIcon(systemName: "arrow.uturn.forward.circle", isActive: false, color: network.canRedo ? .primary : .secondary)
                    }
                    .disabled(!network.canRedo)
                    .help("redo".localized)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(radius: 4)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Middle: Export Tools (New!)
            VStack(spacing: 8) {
                Button(action: { onExport(.jpeg) }) {
                    RailwayInteractionIcon(systemName: "photo", isActive: false, color: .primary)
                }
                .help("Esporta JPG")
                
                Button(action: { onExport(.pdf) }) {
                    RailwayInteractionIcon(systemName: "doc.text", isActive: false, color: .primary)
                }
                .help("Esporta PDF")
                
                Button(action: { onPrint() }) {
                    RailwayInteractionIcon(systemName: "printer", isActive: false, color: .primary)
                }
                .help("print".localized)
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 4)

            // Bottom: Zoom Tools
            VStack(spacing: 8) {
                Button(action: { withAnimation { zoomLevel = min(zoomLevel + 0.5, 5.0) } }) {
                    RailwayInteractionIcon(systemName: "plus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = max(zoomLevel - 0.5, 1.0) } }) {
                    RailwayInteractionIcon(systemName: "minus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = 1.0 } }) {
                    RailwayInteractionIcon(systemName: "arrow.down.left.and.arrow.up.right", isActive: false, color: .purple)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 4)
        }
        .padding()
    }
}

// MARK: - Extracted Map Views (Self-contained for performance)

struct InfrastructureCanvas: View {
    @EnvironmentObject var appState: AppState
    let mode: RailwayMapView.MapVisualizationMode
    let renderData: MapRenderData
    let totalZoom: CGFloat
    
    var body: some View {
        Canvas { context, size in
            // 1. Disegno Archi (Infrastruttura Fisica) - COMMAND
            for edge in appState.railroad.network.edges {
                guard let points = renderData.edgeGeometries[edge.id.uuidString] else { continue }
                
                // Usa la nuova funzione per creare curve morbide
                let path = createSmoothPath(points: points)
                
                let effectiveType = edge.trackType
                var lineWidth: CGFloat = 1.0
                if effectiveType == .highSpeed {
                    lineWidth = appState.trackWidthHighSpeed
                    context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    context.stroke(path, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth * 0.4, lineCap: .round, dash: MapConstants.highSpeedDash))
                } else if effectiveType == .double {
                    lineWidth = appState.trackWidthDouble
                    context.stroke(path, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    context.stroke(path, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: lineWidth - 1.5, lineCap: .round))
                    context.stroke(path, with: .color(.black.opacity(0.9)), style: StrokeStyle(lineWidth: lineWidth * 0.23, lineCap: .round))
                } else if effectiveType == .regional {
                    lineWidth = appState.trackWidthRegional
                    context.stroke(path, with: .color(.blue.opacity(0.6)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                } else {
                    lineWidth = appState.trackWidthSingle
                    context.stroke(path, with: .color(.gray.opacity(0.6)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
                
                if !mode.isSchedulerMode && appState.selectedEdgeId == edge.id.uuidString {
                    context.stroke(path, with: .color(Color.accentColor.opacity(0.4)), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                    context.stroke(path, with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                
                // Detailed segments visualization removed - segments and signals will be shown in dedicated infrastructure tab
            }

            // 2. Visualizzazione Hub - COMMAND
            for (hubId, positions) in renderData.hubGeometries {
                for i in 0..<positions.count {
                    for j in (i+1)..<positions.count {
                        let hPath = Path { p in p.move(to: positions[i]); p.addLine(to: positions[j]) }
                        context.stroke(hPath, with: .color(.red), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                        context.stroke(hPath, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    }
                }
                let maxY = positions.map { $0.y }.max() ?? positions[0].y
                let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                let parentNode = appState.railroad.network.nodes.first(where: { $0.id == hubId }) ?? appState.railroad.network.nodes.first
                MapDrawing.drawNodeLabel(context: context, text: parentNode?.name ?? "", at: CGPoint(x: centerX, y: maxY + 35), color: .red, fontSize: appState.globalFontSize)
            }
            
            // 3. Linee Commerciali - COMMAND
            if mode.isSchedulerMode {
                for (key, precomputedLines) in renderData.commercialLines {
                    // Find the edge(s) connecting these two stations
                    let matchingEdge = appState.railroad.network.edges.first { edge in
                        (edge.from == key.from && edge.to == key.to) || (edge.from == key.to && edge.to == key.from)
                    }
                    guard let edge = matchingEdge,
                          let points = renderData.edgeGeometries[edge.id.uuidString] else { continue }
                    
                    let bundleSize = precomputedLines.count
                    
                    for j in 0..<(points.count - 1) {
                        let sp1 = points[j]; let sp2 = points[j+1]
                        let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
                        
                        if bundleSize > 3 {
                            // INNOVATIVE: For >3 lines, draw single gradient line with diamond indicators
                            let colors = precomputedLines.map { $0.color }
                            let path = Path { p in p.move(to: sp1); p.addLine(to: sp2) }
                            
                            // Draw gradient base
                            let gradient = Gradient(colors: colors)
                            let gradientStart = sp1
                            let gradientEnd = sp2
                            context.stroke(path, with: .linearGradient(gradient, startPoint: gradientStart, endPoint: gradientEnd), 
                                         style: StrokeStyle(lineWidth: appState.globalLineWidth * 1.8, lineCap: .round))
                            
                            // Draw white diamond indicators
                            let midX = (sp1.x + sp2.x) / 2
                            let midY = (sp1.y + sp2.y) / 2
                            let diamondSize: CGFloat = 6
                            let diamondPath = Path { p in
                                p.move(to: CGPoint(x: midX, y: midY - diamondSize))
                                p.addLine(to: CGPoint(x: midX + diamondSize, y: midY))
                                p.addLine(to: CGPoint(x: midX, y: midY + diamondSize))
                                p.addLine(to: CGPoint(x: midX - diamondSize, y: midY))
                                p.closeSubpath()
                            }
                            context.fill(diamondPath, with: .color(.white))
                            context.stroke(diamondPath, with: .color(.gray.opacity(0.5)), lineWidth: 1)
                        } else {
                            // Normal rendering for 1-3 lines
                            for (i, pLine) in precomputedLines.enumerated() {
                                let offset = CGFloat(i) * MapConstants.lineOffsetBase - (CGFloat(precomputedLines.count - 1) * MapConstants.lineOffsetBase / 2.0)
                                let lp1 = CGPoint(x: sp1.x - sin(angle) * offset, y: sp1.y + cos(angle) * offset)
                                let lp2 = CGPoint(x: sp2.x - sin(angle) * offset, y: sp2.y + cos(angle) * offset)
                                
                                let path = Path { p in p.move(to: lp1); p.addLine(to: lp2) }
                                let lineWidth = pLine.isSelected ? appState.globalLineWidth * MapConstants.commercialLineSelectionMultiplier : appState.globalLineWidth
                                context.stroke(path, with: .color(pLine.color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            }
                        }
                    }
                }
            }
        }
        .frame(width: renderData.size.width, height: renderData.size.height)
    }
    
    // MARK: - Detailed Drawing Helpers
    // Note: Track segments and signals visualization removed from map
    // These will be shown in a dedicated infrastructure detail view
}

struct TrainOverlayCanvas: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    
    let bounds: SchematicRailwayView.MapBounds
    let canvasSize: CGSize
    let totalZoom: CGFloat
    
    var body: some View {
        TimelineView(.animation) { timelineContext in
            Canvas { context, size in
                let now = appState.liveSim.currentSimTime
                for schedule in appState.simulator.schedules {
                    if let pos = MapGeometryEngine.currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds, network: network) {
                        let trainDot = Path(ellipseIn: CGRect(x: pos.x - 6, y: pos.y - 6, width: 12, height: 12))
                        context.fill(trainDot, with: .color(.yellow))
                        context.stroke(trainDot, with: .color(.black), lineWidth: 1)
                        if totalZoom > 2.0 {
                            let label = Text(schedule.trainName).font(.caption2).bold()
                            context.draw(label, at: CGPoint(x: pos.x, y: pos.y - 15))
                        }
                    }
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

struct StationMarkersView: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String?
    let canvasSize: CGSize
    let bounds: SchematicRailwayView.MapBounds
    let showGrid: Bool
    let coordinateGridStep: Double
    @Binding var isMoveModeEnabled: Bool
    let onTap: (Node) -> Void
    
    var body: some View {
        ForEach(network.nodes) { node in
            // Safe binding creation to avoid Index out of range
            let nodeBinding = Binding<Node>(
                get: {
                    if let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        return network.nodes[index]
                    }
                    return node
                },
                set: { newNode in
                    if let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        network.nodes[index] = newNode
                    }
                }
            )
            
            StationNodeView(
                node: nodeBinding,
                canvasSize: canvasSize,
                isSelected: selectedNode?.id == node.id || appState.selectedNodeIds.contains(node.id),
                snapToGrid: showGrid,
                gridUnit: coordinateGridStep,
                bounds: bounds,
                onTap: { onTap(node) },
                isMoveModeEnabled: $isMoveModeEnabled,
                onDragStarted: { network.createCheckpoint() }
            )
            .position(MapGeometryEngine.finalPosition(for: node, in: canvasSize, bounds: bounds, network: network))
            .id("node-\(node.id)")
        }
         
    }
}


