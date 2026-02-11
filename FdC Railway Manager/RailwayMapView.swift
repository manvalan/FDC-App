import SwiftUI
import Combine
import MapKit
import UIKit

struct RailwayMapView: View {
    enum MapVisualizationMode {
        case network // Shows physical infrastructure (Black/Gray tracks)
        case lines   // Shows commercial lines (Colored paths)
    }

    @EnvironmentObject var appState: AppState
    @State private var position: MapCameraPosition = .automatic
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String?
    @Binding var showGrid: Bool
    @Binding var isMoveModeEnabled: Bool
    @Binding var highlightedConflictLocation: String?
    var mode: MapVisualizationMode
    
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
        }
        
        struct TrainDraw: Sendable {
            let pos: CGPoint
            let name: String
            let color: Color
        }
        
        struct EdgeDraw: Sendable {
            let path: Path
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
                    
                    for j in 0..<(points.count - 1) {
                        let sp1 = points[j]; let sp2 = points[j+1]
                        let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
                        let offsetBase: CGFloat = 8.0 // Larger for snapshot
                        
                        for (i, line) in segLines.enumerated() {
                            let offset = CGFloat(i) * offsetBase - (CGFloat(segLines.count - 1) * offsetBase / 2.0)
                            let lp1 = CGPoint(x: sp1.x - sin(angle) * offset, y: sp1.y + cos(angle) * offset)
                            let lp2 = CGPoint(x: sp2.x - sin(angle) * offset, y: sp2.y + cos(angle) * offset)
                            let path = Path { p in p.move(to: lp1); p.addLine(to: lp2) }
                            drawings.append(LineDraw(path: path, color: Color(hex: line.color ?? "#000000") ?? .black, name: line.name))
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
            
            // 1. Edges (Deduplicated for visual clarity)
            var deduplicatedEdges: [Edge] = []
            var seenKeys = Set<String>()
            
            for edge in edges {
                let key = edge.canonicalKey
                if !seenKeys.contains(key) {
                    let effectiveEdge = edge
                    deduplicatedEdges.append(effectiveEdge)
                    seenKeys.insert(key)
                }
            }

            let edgesDraw = deduplicatedEdges.compactMap { edge -> EdgeDraw? in
                guard let n1 = nodes.first(where: { $0.id == edge.from }),
                      let n2 = nodes.first(where: { $0.id == edge.to }) else { return nil }
                
                let p1 = finalPosition(for: n1)
                let p2 = finalPosition(for: n2)
                let points = generateSchematicPoints(from: p1, to: p2)
                
                let path = Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                
                let baseColor: Color = (mode == .network) ? .gray : .gray.opacity(0.3)
                return EdgeDraw(path: path, color: (edge.trackType == .highSpeed ? .red.opacity(0.8) : .black.opacity(0.8)), type: edge.trackType, baseColor: baseColor)
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
                return NodeDraw(pos: finalPosition(for: node), name: node.name, isHub: node.type == .interchange)
            }
            
            let linesDraw = (mode == .lines) ? generateLineDraws() : []
            let trainsDraw = (mode == .lines) ? generateTrainDraws() : []
            
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
        
        var body: some View {
            Canvas { context, size in
                // 1. Draw Edges
                for edge in data.edges {
                    if edge.type == .highSpeed {
                        // High-Speed Style Consistency
                        context.stroke(edge.path, with: .color(.red), style: StrokeStyle(lineWidth: appState.trackWidthHighSpeed, lineCap: .square))
                        context.stroke(edge.path, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: appState.trackWidthHighSpeed * 0.4, lineCap: .round, dash: [3, 3]))
                    } else if edge.type == .double {
                        context.stroke(edge.path, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: appState.trackWidthDouble, lineCap: .round))
                        context.stroke(edge.path, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: appState.trackWidthDouble - 1.5, lineCap: .round))
                        context.stroke(edge.path, with: .color(.black.opacity(0.9)), style: StrokeStyle(lineWidth: appState.trackWidthDouble * 0.23, lineCap: .round))
                    } else if edge.type == .regional {
                        context.stroke(edge.path, with: .color(.blue.opacity(0.6)), style: StrokeStyle(lineWidth: appState.trackWidthRegional, lineCap: .round))
                    } else {
                        context.stroke(edge.path, with: .color(.gray.opacity(0.8)), style: StrokeStyle(lineWidth: data.globalLineWidth * 0.6, lineCap: .round))
                    }
                }
                
                // 1.5 Draw Commercial Lines
                for l in data.lines {
                    context.stroke(l.path, with: .color(l.color), style: StrokeStyle(lineWidth: appState.globalLineWidth, lineCap: .round))
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
                         context.stroke(Path(ellipseIn: CGRect(x: node.pos.x - 12, y: node.pos.y - 12, width: 24, height: 24)), with: .color(.black), lineWidth: 2)
                         
                         let label = Text(node.name).font(.system(size: data.globalFontSize, weight: .black)).foregroundColor(.black)
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
    @State private var scrollTargetPos: CGPoint? = nil

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
        ZStack(alignment: .bottomTrailing) {
            scrollViewLayer(size: size, bounds: bounds, renderData: renderData)
            
            lineCreationOverlay
            MapControlsView(
                isEditToolbarVisible: $isEditToolbarVisible,
                editMode: $editMode,
                isMoveModeEnabled: $isMoveModeEnabled,
                zoomLevel: $zoomLevel,
                onExport: onExport,
                onPrint: onPrint
            )
            trackCreationOverlay
            stationPickingIndicator
            moveModeOverlay
        }
    }
    
    @ViewBuilder
    private func scrollViewLayer(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ScrollViewReader { proxy in
                ZStack(alignment: .topLeading) {
                    mapBasement(size: size, bounds: bounds)
                    scrollingAnchors(size: size, bounds: bounds)
                    mapMainLayers(size: size, bounds: bounds, renderData: renderData)
                }
                .frame(width: size.width, height: size.height)
                .gesture(zoomGesture)
                .onChange(of: selectedNode) { node in centerOnNode(node, proxy: proxy) }
                .onChange(of: selectedLine) { line in centerOnLine(line, proxy: proxy) }
                .onChange(of: selectedEdgeId) { edgeId in centerOnEdge(edgeId, proxy: proxy) }
                .onChange(of: appState.selectedTrainIds) { ids in centerOnTrain(Array(ids), size: size, bounds: bounds, proxy: proxy) }
            }
        }
        .simultaneousGesture(zoomGesture)
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
        Group {
            ForEach(network.nodes) { node in
                Color.clear
                    .frame(width: 1, height: 1)
                    .position(MapGeometryEngine.finalPosition(for: node, in: size, bounds: bounds, network: network))
                    .id("node-\(node.id)")
            }
            Color.clear
                .frame(width: 1, height: 1)
                .position(scrollTargetPos ?? .zero)
                .id("SCROLL_TARGET")
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
            
            if !appState.simulator.schedules.isEmpty {
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
            if mode == .lines && isEditToolbarVisible {
                showLineCreation = true
            }
        }
    }

    private func centerOnNode(_ node: Node?, proxy: ScrollViewProxy) {
        if let node = node { withAnimation { proxy.scrollTo("node-\(node.id)", anchor: UnitPoint.center) } }
    }

    private func centerOnLine(_ line: RailwayLine?, proxy: ScrollViewProxy) {
        if let line = line, let firstId = line.stops.first?.stationId {
            withAnimation { proxy.scrollTo("node-\(firstId)", anchor: UnitPoint.center) }
        }
    }

    private func centerOnEdge(_ edgeId: String?, proxy: ScrollViewProxy) {
        if let edgeId = edgeId, let edge = network.edges.first(where: { $0.id.uuidString == edgeId }) {
            withAnimation { proxy.scrollTo("node-\(edge.from)", anchor: UnitPoint.center) }
        }
    }

    private func centerOnTrain(_ ids: [UUID], size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy) {
        if let trainId = ids.first, let schedule = appState.simulator.schedules.first(where: { $0.trainId == trainId }) {
            let now = appState.liveSim.currentSimTime
            if let pos = MapGeometryEngine.currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds, network: network) {
                scrollTargetPos = pos
                withAnimation { proxy.scrollTo("SCROLL_TARGET", anchor: UnitPoint.center) }
            }
        }
    }

    @ViewBuilder
    private var lineCreationOverlay: some View {
        if showLineCreation {
            VStack {
                Spacer()
                LineCreationView()
                    .environmentObject(appState.railroad.network)
                    .environmentObject(appState.railroad.lines)
                    .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(200)
        }
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
                    .background((newTrackFrom != nil && newTrackTo != nil) ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
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
            // New Logic: Populate Box
            if newTrackFrom == nil {
                newTrackFrom = node
            } else if newTrackFrom?.id == node.id {
                // Deselect if tapping same
                newTrackFrom = nil
            } else {
                newTrackTo = node
                // Auto-calc distance
                if let n1 = newTrackFrom {
                    let lat1 = n1.latitude ?? 0; let lon1 = n1.longitude ?? 0
                    let lat2 = node.latitude ?? 0; let lon2 = node.longitude ?? 0
                    let dLat = lat1 - lat2
                    let dLon = lon1 - lon2
                    let distKm = sqrt(dLat*dLat + dLon*dLon) * 111.0
                    newTrackDistance = max(1.0, round(distKm * 10) / 10.0)
                }
            }
        } else {
            // Priority selection logic
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        
        // Auto-exit mode
        editMode = .explore
    }
    
    private func handleCanvasTap(at location: CGPoint, in size: CGSize) {
        let bounds = self.mapBounds
        
        // 1. Check Stations (using MapGeometry)
        for node in network.nodes {
            let p = MapGeometryEngine.finalPosition(for: node, in: size, bounds: bounds, network: network)
            if hypot(p.x - location.x, p.y - location.y) < MapConstants.hitTestRadius {
                handleStationTap(node)
                return
            }
        }
        
        // 2. Check Track Segments (Edges) - Visual hit testing
        var newSelectedEdgeId: String? = nil
        for edge in network.edges {
            guard let p1 = network.nodes.first(where: { $0.id == edge.from }).map({ MapGeometryEngine.finalPosition(for: $0, in: size, bounds: bounds, network: network) }),
                  let p2 = network.nodes.first(where: { $0.id == edge.to }).map({ MapGeometryEngine.finalPosition(for: $0, in: size, bounds: bounds, network: network) }) else { continue }
            
            let points = MapGeometryEngine.generateSchematicPoints(from: p1, to: p2)
            for i in 0..<(points.count - 1) {
                if distanceToSegment(p: location, v: points[i], w: points[i+1]) < 10 {
                    newSelectedEdgeId = edge.id.uuidString
                    break
                }
            }
            if newSelectedEdgeId != nil { break }
        }
        
        // 3. Check Commercial Lines
        var newSelectedLine: RailwayLine? = nil
        if mode == .lines {
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
                        if distanceToSegment(p: location, v: points[j], w: points[j+1]) < 8 {
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
    @Binding var node: Node
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
            .onLongPressGesture(minimumDuration: MapConstants.longPressDuration) {
                withAnimation(.spring(response: MapConstants.springResponse, dampingFraction: MapConstants.springDamping)) {
                    isMoveModeEnabled.toggle()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            .onTapGesture { onTap() }
            .gesture(dragGesture)
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

    private var dragGesture: some Gesture {
        isMoveModeEnabled ?
        DragGesture(minimumDistance: MapConstants.dragMinimumDistance)
            .onChanged { val in
                if dragOffset == .zero { onDragStarted?() }
                let deltaX = val.translation.width - dragOffset.width
                let deltaY = val.translation.height - dragOffset.height
                dragOffset = val.translation
                
                let drawWidth = max(canvasSize.width - MapConstants.canvasPadding * 2, 1)
                let drawHeight = max(canvasSize.height - MapConstants.canvasPadding * 2, 1)
                let dLon = (deltaX / drawWidth) * bounds.xRange
                let dLat = -(deltaY / drawHeight) * bounds.yRange
                
                node.latitude = (node.latitude ?? 0) + dLat
                node.longitude = (node.longitude ?? 0) + dLon
            }
            .onEnded { _ in
                dragOffset = .zero
                if snapToGrid { snapNodeToGrid() }
            }
        : nil
    }
    
    // Helper to snap ACTUAL lat/lon based on coordinate units
    private func snapNodeToGrid() {
        let unit = gridUnit
        node.latitude = round((node.latitude ?? 0) / unit) * unit
        node.longitude = round((node.longitude ?? 0) / unit) * unit
    }
    
    @ViewBuilder
    func symbolView(type: Node.StationVisualType, color: Color) -> some View {
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
            
            // Top: Edit Tools (Only visible after long press)
            if isEditToolbarVisible {
                VStack(spacing: 8) {
                    Button(action: { editMode = .addStation }) {
                        InteractionIcon(systemName: "building.2.fill", isActive: editMode == .addStation, activeColor: .green)
                    }
                    .help("Aggiungi Stazione")
                    
                    Button(action: { editMode = .addTrack }) {
                        InteractionIcon(systemName: "point.topleft.down.curvedto.point.bottomright.up", isActive: editMode == .addTrack, activeColor: .orange)
                    }
                    .help("Crea Binari")
                    
                    Button(action: { withAnimation { isMoveModeEnabled.toggle() } }) {
                        InteractionIcon(systemName: isMoveModeEnabled ? "hand.draw.fill" : "hand.draw", isActive: isMoveModeEnabled, activeColor: .blue)
                    }
                    .help("Sposta Stazioni")
                    
                    Divider().background(Color.white.opacity(0.3)).frame(width: 30)
                    
                    // Undo/Redo Integrated
                    Button(action: { network.undo() }) {
                        InteractionIcon(systemName: "arrow.uturn.backward.circle", isActive: false, color: network.canUndo ? .primary : .secondary)
                    }
                    .disabled(!network.canUndo)
                    .help("undo".localized)
                    
                    Button(action: { network.redo() }) {
                        InteractionIcon(systemName: "arrow.uturn.forward.circle", isActive: false, color: network.canRedo ? .primary : .secondary)
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
                    InteractionIcon(systemName: "photo", isActive: false, color: .primary)
                }
                .help("Esporta JPG")
                
                Button(action: { onExport(.pdf) }) {
                    InteractionIcon(systemName: "doc.text", isActive: false, color: .primary)
                }
                .help("Esporta PDF")
                
                Button(action: { onPrint() }) {
                    InteractionIcon(systemName: "printer", isActive: false, color: .primary)
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
                    InteractionIcon(systemName: "plus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = max(zoomLevel - 0.5, 1.0) } }) {
                    InteractionIcon(systemName: "minus", isActive: false, color: .primary)
                }
                Button(action: { withAnimation { zoomLevel = 1.0 } }) {
                    InteractionIcon(systemName: "arrow.down.left.and.arrow.up.right", isActive: false, color: .purple)
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
                let key = edge.canonicalKey
                guard let points = renderData.edgeGeometries[key] else { continue }
                
                let path = Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                
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
                
                if mode == .network && appState.selectedEdgeId == edge.id.uuidString {
                    context.stroke(path, with: .color(Color.accentColor.opacity(0.4)), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                    context.stroke(path, with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                
                if totalZoom > 3.0 && !edge.segments.isEmpty {
                    drawDetailedEdge(context: context, edge: edge, points: points, lineWidth: lineWidth)
                }
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
            if mode == .lines {
                for (key, precomputedLines) in renderData.commercialLines {
                    guard let points = renderData.edgeGeometries[key.from < key.to ? "\(key.from)-\(key.to)" : "\(key.to)-\(key.from)"] else { continue }
                    
                    for j in 0..<(points.count - 1) {
                        let sp1 = points[j]; let sp2 = points[j+1]
                        let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
                        
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
        .frame(width: renderData.size.width, height: renderData.size.height)
    }
    
    // MARK: - Detailed Drawing Helpers
    
    private func drawDetailedEdge(context: GraphicsContext, edge: Edge, points: [CGPoint], lineWidth: CGFloat) {
        let totalLength = points.dropFirst().enumerated().reduce(0.0) { sum, pair in
            sum + hypot(pair.element.x - points[pair.offset].x, pair.element.y - points[pair.offset].y)
        }
        
        var currentDist: CGFloat = 0
        var segmentIdx = 0
        let segments = edge.segments
        
        for i in 0..<(points.count - 1) {
            let p1 = points[i]; let p2 = points[i+1]
            let segDist = hypot(p2.x - p1.x, p2.y - p1.y)
            let angle = atan2(p2.y - p1.y, p2.x - p1.x)
            
            while segmentIdx < segments.count {
                let segmentEndDist = totalLength * CGFloat(segments[0...segmentIdx].reduce(0.0) { $0 + $1.length } / edge.distance)
                
                if segmentEndDist >= currentDist && segmentEndDist <= currentDist + segDist {
                    let ratio = (segmentEndDist - currentDist) / segDist
                    let endPoint = CGPoint(
                        x: p1.x + (p2.x - p1.x) * ratio,
                        y: p1.y + (p2.y - p1.y) * ratio
                    )
                    
                    let crossLen: CGFloat = lineWidth + 6
                    var crossPath = Path()
                    crossPath.move(to: CGPoint(x: -crossLen/2, y: 0))
                    crossPath.addLine(to: CGPoint(x: crossLen/2, y: 0))
                    
                    var crossContext = context
                    crossContext.translateBy(x: endPoint.x, y: endPoint.y)
                    crossContext.rotate(by: .radians(Double(angle + .pi/2)))
                    crossContext.stroke(crossPath, with: .color(.black.opacity(0.4)), lineWidth: 2)
                    
                    if let signal = segments[segmentIdx].signal {
                        let signalOffset: CGFloat = lineWidth + 8
                        let signalPoint = CGPoint(
                            x: endPoint.x + cos(angle + .pi/2) * signalOffset,
                            y: endPoint.y + sin(angle + .pi/2) * signalOffset
                        )
                        
                        let signalAspectColor: Color = {
                            switch signal.aspect {
                            case .stop: return .red
                            case .proceed: return .green
                            case .caution: return .yellow
                            }
                        }()
                        
                        let signalCircle = Path(ellipseIn: CGRect(x: signalPoint.x - 4, y: signalPoint.y - 4, width: 8, height: 8))
                        context.fill(signalCircle, with: .color(signalAspectColor))
                        context.stroke(signalCircle, with: .color(.black), lineWidth: 1)
                        
                        if totalZoom > 4.5 {
                            let label = Text(signal.name).font(.system(size: 8)).bold()
                            context.draw(label, at: CGPoint(x: signalPoint.x, y: signalPoint.y - 12))
                        }
                    }
                }
                
                if segmentEndDist > currentDist + segDist { break }
                segmentIdx += 1
            }
            currentDist += segDist
        }
    }
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
                    if let pos = MapGeometry.currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds, network: network) {
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
        ForEach(network.nodes.indices, id: \.self) { index in
            StationNodeView(
                node: Binding(
                    get: { network.nodes[index] },
                    set: { network.nodes[index] = $0 }
                ),
                canvasSize: canvasSize,
                isSelected: selectedNode?.id == network.nodes[index].id,
                snapToGrid: showGrid,
                gridUnit: coordinateGridStep,
                bounds: bounds,
                onTap: { onTap(network.nodes[index]) },
                isMoveModeEnabled: $isMoveModeEnabled,
                onDragStarted: { network.createCheckpoint() }
            )
            .position(MapGeometryEngine.finalPosition(for: network.nodes[index], in: canvasSize, bounds: bounds, network: network))
            .id("node-\(network.nodes[index].id)")
        }
    }
}


