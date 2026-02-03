import SwiftUI
import Combine
import MapKit
import UIKit

struct RailwayMapView: View {
    enum MapVisualizationMode {
        case network // Shows physical infrastructure (Black/Gray tracks)
        case lines   // Shows commercial lines (Colored paths)
    }

    @ObservedObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    @State private var position: MapCameraPosition = .automatic
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String? // Added binding
    @Binding var showGrid: Bool // Added binding
    @Binding var isMoveModeEnabled: Bool // Added binding
    @Binding var highlightedConflictLocation: String? // Added binding for conflict highlighting
    var mode: MapVisualizationMode // Added mode
    
    @State private var isExporting = false

    struct MapBounds: Sendable {
        let minLat, maxLat, minLon, maxLon, xRange, yRange: Double
    }

    var body: some View {
        ZStack {
            SchematicRailwayView(
                network: network,
                appState: appState,
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
        
        let lns = network.lines
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
        
        let lns = network.lines
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

    @EnvironmentObject var trainManager: TrainManager
}

// MARK: - Schematic View Component
struct SchematicRailwayView: View {
    @ObservedObject var network: RailwayNetwork
    @ObservedObject var appState: AppState
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
        let lats = network.nodes.compactMap { $0.latitude }
        let lons = network.nodes.compactMap { $0.longitude }
        
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
            ZStack(alignment: .bottomTrailing) {
                
                // ScrollView for native scrolling/panning
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    let canvasSize = CGSize(
                        width: max(geo.size.width * totalZoom, geo.size.width),
                        height: max(geo.size.height * totalZoom, geo.size.height)
                    )
                    let bounds = self.mapBounds
                    
                    ZStack(alignment: .topLeading) {
                        // Background (White + Grid)
                        ZStack {
                            Color.white
                            if showGrid {
                                CoordinateGridShape(
                                    bounds: bounds,
                                    unit: coordinateGridStep,
                                    size: canvasSize
                                )
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            }
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .onTapGesture(count: 1, coordinateSpace: .local) { location in
                            handleCanvasTap(at: location, in: canvasSize)
                        }
                        .onLongPressGesture(minimumDuration: 0.6) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isEditToolbarVisible.toggle()
                                
                                // Reset to explore if closing toolbar
                                if !isEditToolbarVisible {
                                    editMode = .explore
                                    isMoveModeEnabled = false
                                }
                                
                                // In lines mode, long press can still show line creation or just show toolbar
                                if mode == .lines && isEditToolbarVisible {
                                    showLineCreation = true
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        
                        // 1. Draw Map Content
                        Canvas { context, size in
                            let bounds = mapBounds

                            // Helper struct for segment mapping
                            struct SegmentKey: Hashable {
                                let from: String
                                let to: String
                                init(_ a: String, _ b: String) {
                                    if a < b { from = a; to = b }
                                    else { from = b; to = a }
                                }
                            }
                            
                            // Map segments to lines for offsetting
                            var segmentLineMap: [SegmentKey: [RailwayLine]] = [:]
                            for line in network.lines {
                                if hiddenLineIds.contains(line.id) { continue }
                                let count = line.stations.count
                                if count > 1 {
                                    for i in 0..<(count - 1) {
                                        let key = SegmentKey(line.stations[i], line.stations[i+1])
                                        segmentLineMap[key, default: []].append(line)
                                    }
                                }
                            }

                            // Pre-calculate all node positions for performance and collision avoidance
                            var allNodePoints: [String: CGPoint] = [:]
                            for node in network.nodes {
                                allNodePoints[node.id] = finalPosition(for: node, in: size, bounds: bounds)
                            }
                            
                            // Structure for neighbor lookup
                            var nodeNeighbors: [String: Set<String>] = [:]
                            for edge in network.edges {
                                nodeNeighbors[edge.from, default: []].insert(edge.to)
                                nodeNeighbors[edge.to, default: []].insert(edge.from)
                            }
                            
                            // 1. Draw RAW Infrastructure (Edges) - Deduplicated visually
                            var drawnKeys = Set<String>()
                            for edge in network.edges {
                                let key = edge.canonicalKey
                                if drawnKeys.contains(key) { continue }
                                drawnKeys.insert(key)
                                
                                guard let p1 = allNodePoints[edge.from],
                                      let p2 = allNodePoints[edge.to] else { continue }
                                      
                                // Filter out start/end nodes from obstacles
                                let avoid = allNodePoints.values.filter { $0 != p1 && $0 != p2 }
                                
                                // Get neighbor positions for angle checks
                                let neighborIdsStart = nodeNeighbors[edge.from]?.filter { $0 != edge.to } ?? []
                                let neighborIdsEnd = nodeNeighbors[edge.to]?.filter { $0 != edge.from } ?? []
                                let nPosStart = neighborIdsStart.compactMap { allNodePoints[$0] }
                                let nPosEnd = neighborIdsEnd.compactMap { allNodePoints[$0] }
                                
                                // Base Track Path with Obstacle Avoidance and Angle Constraints
                                let points = generateSchematicPoints(
                                    from: p1, 
                                    to: p2, 
                                    avoidPoints: Array(avoid),
                                    neighborsStart: nPosStart,
                                    neighborsEnd: nPosEnd
                                )
                                let path = Path { p in
                                    guard let first = points.first else { return }
                                    p.move(to: first)
                                    for pt in points.dropFirst() {
                                        p.addLine(to: pt)
                                    }
                                }
                                
                                // Styles based on physical properties
                                let effectiveType = edge.trackType
                                var lineWidth: CGFloat = 1.0
                                
                                if effectiveType == .highSpeed {
                                    // High-Speed: Bold red with white dashed spine
                                    lineWidth = appState.trackWidthHighSpeed
                                    context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
                                    context.stroke(path, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth * 0.4, lineCap: .round, dash: [3, 3]))
                                } else if effectiveType == .double {
                                    // Double Track: Dark gray with parallel appearance
                                    lineWidth = appState.trackWidthDouble
                                    context.stroke(path, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                    context.stroke(path, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: lineWidth - 1.5, lineCap: .round))
                                    context.stroke(path, with: .color(.black.opacity(0.9)), style: StrokeStyle(lineWidth: lineWidth * 0.23, lineCap: .round))
                                } else if effectiveType == .regional {
                                    // Regional: Blue-tinted medium track
                                    lineWidth = appState.trackWidthRegional
                                    context.stroke(path, with: .color(.blue.opacity(0.6)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                } else {
                                    // Single: Simple single line (thin gray)
                                    lineWidth = appState.trackWidthSingle
                                    context.stroke(path, with: .color(.gray.opacity(0.6)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                }
                                
                                // If mode is network, we also draw the edges that might have been selected
                                if mode == .network && selectedEdgeId == edge.id.uuidString {
                                    context.stroke(path, with: .color(.blue.opacity(0.5)), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                                }
                            }

                            // 1. Interchange Visualization (Explicit Hubs)
                            // We group nodes by their parentHubId.
                            // A node is part of a hub if:
                            // a) it has a parentHubId
                            // b) its ID is used as a parentHubId by others
                            let hubNodes = network.nodes.filter { node in
                                node.parentHubId != nil || network.nodes.contains(where: { $0.parentHubId == node.id })
                            }
                            
                            // Group nodes by their "Effective Hub ID" (the ID of the parent/root)
                            var hubGroups: [String: [Node]] = [:]
                            for node in hubNodes {
                                let hubId = node.parentHubId ?? node.id
                                hubGroups[hubId, default: []].append(node)
                            }
                            
                            // Sort each group to ensure drawing order (parent first usually better)
                            for key in hubGroups.keys {
                                hubGroups[key]?.sort { ($0.parentHubId == nil) && ($1.parentHubId != nil) }
                            }

                            for (hubId, nodes) in hubGroups {
                                let positions = nodes.map { finalPosition(for: $0, in: size, bounds: bounds) }
                                
                                // Draw Tube-style Connection (Corridor) ONLY for multi-node hubs
                                if nodes.count > 1 {
                                    for i in 0..<nodes.count {
                                        for j in (i+1)..<nodes.count {
                                            let p1 = positions[i]
                                            let p2 = positions[j]
                                            
                                            let hPath = Path { p in p.move(to: p1); p.addLine(to: p2) }
                                            
                                            context.stroke(hPath, with: .color(.red), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                                            context.stroke(hPath, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                        }
                                    }
                                    
                                    // Unified Name for the hub
                                    let maxY = positions.map { $0.y }.max() ?? positions[0].y
                                    let labelY = maxY + 35
                                    let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                                    
                                    // Name source: Use the parent node name if available, otherwise first node
                                    let parentNode = nodes.first(where: { $0.id == hubId }) ?? nodes.first
                                    let nameToDisplay = parentNode?.name ?? ""
                                    
                                    let text = Text(nameToDisplay)
                                        .font(.system(size: appState.globalFontSize, weight: .bold))
                                        .foregroundColor(.red)
                                    
                                    let resolvedText = context.resolve(text)
                                    let textSize = resolvedText.measure(in: CGSize(width: 200, height: 50))
                                    
                                    let textRect = CGRect(
                                        x: centerX - textSize.width/2 - 4,
                                        y: labelY - textSize.height/2 - 2,
                                        width: textSize.width + 8,
                                        height: textSize.height + 4
                                    )
                                    let pill = Path(roundedRect: textRect, cornerRadius: 4)
                                    context.fill(pill, with: .color(.white.opacity(0.8)))
                                    context.draw(resolvedText, at: CGPoint(x: centerX, y: labelY))
                                }
                            }
                            
                            // 1.1 Handle labels for interchange nodes that are NOT in a multi-node hub
                            let orphanInterchanges = network.nodes.filter { node in
                                node.type == .interchange && 
                                hubGroups[node.parentHubId ?? node.id]?.count ?? 0 <= 1
                            }
                            
                            for node in orphanInterchanges {
                                let p = finalPosition(for: node, in: size, bounds: bounds)
                                let labelY = p.y + 35
                                
                                let text = Text(node.name)
                                   .font(.system(size: appState.globalFontSize, weight: .bold))
                                   .foregroundColor(.red)
                                
                                let resolvedText = context.resolve(text)
                                let textSize = resolvedText.measure(in: CGSize(width: 200, height: 50))
                                
                                let textRect = CGRect(
                                    x: p.x - textSize.width/2 - 4,
                                    y: labelY - textSize.height/2 - 2,
                                    width: textSize.width + 8,
                                    height: textSize.height + 4
                                )
                                let pill = Path(roundedRect: textRect, cornerRadius: 4)
                                context.fill(pill, with: .color(.white.opacity(0.8)))
                                context.draw(resolvedText, at: CGPoint(x: p.x, y: labelY))
                            }
                            
                            if mode == .lines {
                                // Draw Commercial Lines following Schematic Path
                                for (key, lines) in segmentLineMap {
                                    guard let n1 = network.nodes.first(where: { $0.id == key.from }),
                                          let n2 = network.nodes.first(where: { $0.id == key.to }) else { continue }
                                    
                                    let p1 = finalPosition(for: n1, in: size, bounds: bounds)
                                    let p2 = finalPosition(for: n2, in: size, bounds: bounds)
                                    
                                    // 1. Generate Schematic Path (0, 45, 90)
                                    let points = generateSchematicPoints(from: p1, to: p2)
                                    
                                    // 2. Iterate segments
                                    for j in 0..<(points.count - 1) {
                                        let sp1 = points[j]
                                        let sp2 = points[j+1]
                                        let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
                                        let offsetBase: CGFloat = 4.0
                                        
                                        for (i, line) in lines.enumerated() {
                                            let offset = CGFloat(i) * offsetBase - (CGFloat(lines.count - 1) * offsetBase / 2.0)
                                            let offX = -sin(angle) * offset
                                            let offY = cos(angle) * offset
                                            
                                            let lp1 = CGPoint(x: sp1.x + offX, y: sp1.y + offY)
                                            let lp2 = CGPoint(x: sp2.x + offX, y: sp2.y + offY)
                                            
                                            let segPath = Path { p in p.move(to: lp1); p.addLine(to: lp2) }
                                            let lineColor = Color(hex: line.color ?? "#000000") ?? .black
                                            let isSelected = (line.id == selectedLine?.id)
                                            let lineWidth: CGFloat = isSelected ? appState.globalLineWidth * 1.5 : appState.globalLineWidth
                                            
                                            if isSelected {
                                                context.stroke(segPath, with: .color(lineColor.opacity(0.3)), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                                            }
                                            context.stroke(segPath, with: .color(lineColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .allowsHitTesting(false)
                        
                        // 2. Draw Active Trains (Animated Overlay)
                        // Only show trains if there are active schedules
                        if !appState.simulator.schedules.isEmpty {
                            TimelineView(.animation) { timelineContext in
                                Canvas { context, size in
                                    let bounds = mapBounds
                                    let now = timelineContext.date.normalized()
                                    
                                    // Only show trains if there are schedules
                                    if !appState.simulator.schedules.isEmpty {
                                        for schedule in appState.simulator.schedules {
                                            if let pos = currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds) {
                                                let trainDot = Path(ellipseIn: CGRect(x: pos.x - 6, y: pos.y - 6, width: 12, height: 12))
                                                context.fill(trainDot, with: .color(.yellow))
                                                context.stroke(trainDot, with: .color(.black), lineWidth: 1)
                                                // Label? Only on high zoom
                                                if totalZoom > 2.0 {
                                                    let label = Text(schedule.trainName).font(.caption2).bold()
                                                    context.draw(label, at: CGPoint(x: pos.x, y: pos.y - 15))
                                                }
                                            }
                                        }
                                    }
                                }
                                .frame(width: canvasSize.width, height: canvasSize.height)
                                .allowsHitTesting(false)
                            }
                        }
                        
                        // 2. Interactive Nodes
                        ForEach($network.nodes) { $node in
                            StationNodeView(
                                node: $node,
                                network: network,
                                canvasSize: canvasSize,
                                isSelected: selectedNode?.id == node.id,
                                snapToGrid: showGrid,
                                gridUnit: coordinateGridStep,
                                bounds: bounds,
                                onTap: { handleStationTap(node) },
                                isMoveModeEnabled: $isMoveModeEnabled,
                                onDragStarted: { network.createCheckpoint() }
                            )
                            .position(finalPosition(for: node, in: canvasSize, bounds: bounds))
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            magnification = value
                        }
                        .onEnded { value in
                            zoomLevel *= magnification
                            magnification = 1.0
                        }
                )
                
                // Consolidated Controls Toolbar (Right Side)
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
                
                // Track Creation Box Overlay
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
                                        .foregroundColor(newTrackFrom == nil ? .gray : .black)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Image(systemName: "arrow.right")
                                
                                VStack(alignment: .trailing) {
                                    Text("to_label".localized)
                                        .font(.caption).foregroundColor(.secondary)
                                    Text(newTrackTo?.name ?? "select_station_placeholder".localized)
                                        .fontWeight(.bold)
                                        .foregroundColor(newTrackTo == nil ? .gray : .black)
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
                                        VStack(spacing: 4) {
                                            // Visual representation icon
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
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                                                        HStack {
                                Button("cancel".localized) {
                                    newTrackFrom = nil
                                    newTrackTo = nil
                                    editMode = .explore // Exit mode
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                
                                Button(action: createTrack) {
                                    Text("create_track_button".localized)
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background((newTrackFrom != nil && newTrackTo != nil) ? Color.blue : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(newTrackFrom == nil || newTrackTo == nil)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.2), radius: 10)
                        )
                        .padding()
                        .frame(maxWidth: 400)
                    }
                    .transition(.move(edge: .bottom))
                }
                
                // Move Mode Status Overlay
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
                        .overlay(
                            Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                        .padding(.top, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(true)
                }
            }
        }
        .sheet(isPresented: $showLineCreation) {
            LineCreationView()
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
                    ForEach(network.sortedLines) { line in
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
    
    // MARK: - Interaction Handlers
    private func handleStationTap(_ node: Node) {
        if editMode == .addTrack {
            // New Logic: Populate Box
            if newTrackFrom == nil {
                newTrackFrom = node
                // Reset distance default? Keep previous? Let's reset to geo-calc if To is selected later.
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
        network.edges.append(newEdge)
        
        // Note: Pathfinding treats all edges as bidirectional, so no need to create return edge
        
        
        // Reset selection
        newTrackFrom = nil
        newTrackTo = nil
        
        // Auto-exit mode
        editMode = .explore
    }
    
    private func handleCanvasTap(at location: CGPoint, in size: CGSize) {
        if editMode == .addStation {
            let newNode = createStation(at: location, in: size)
            // Select the new node immediately to open the Inspector
            selectedNode = newNode
            // Auto-switch back to explore mode
            editMode = .explore 
            return
        }
        
        // Reset selections if tapping empty space (start with a threshold)
        var bestHitDist: CGFloat = 15.0
        var newSelectedNode: Node? = nil
        var newSelectedLine: RailwayLine? = nil
        var newSelectedEdgeId: String? = nil
        
        // 1. Hit Test for Nodes (Stations)
        for node in network.nodes {
            let pNode = finalPosition(for: node, in: size, bounds: self.mapBounds)
            let dist = hypot(location.x - pNode.x, location.y - pNode.y)
            if dist < 30 { // Increased hit radius
                newSelectedNode = node
                break
            }
        }
        
        if newSelectedNode == nil {
            // 2. Hit Test for Lines (Commercial)
            if mode == .lines {
                    for line in network.lines {
                        if hiddenLineIds.contains(line.id) { continue }
                        let count = line.stations.count
                        if count > 1 {
                            for i in 0..<(count - 1) {
                                guard let n1 = network.nodes.first(where: { $0.id == line.stations[i] }),
                                      let n2 = network.nodes.first(where: { $0.id == line.stations[i+1] }) else { continue }
                                let p1 = finalPosition(for: n1, in: size, bounds: self.mapBounds)
                                let p2 = finalPosition(for: n2, in: size, bounds: self.mapBounds)
                                let dist = distanceToSegment(p: location, v: p1, w: p2)
                                
                                if dist < 15 { // Line hit threshold
                                     if dist < bestHitDist {
                                         bestHitDist = dist
                                         newSelectedLine = line
                                     }
                                }
                            }
                        }
                    }
            }
            
            // 3. Hit Test for Edges (Infrastructure)
            if newSelectedLine == nil {
                for edge in network.edges {
                    guard let n1 = network.nodes.first(where: { $0.id == edge.from }),
                          let n2 = network.nodes.first(where: { $0.id == edge.to }) else { continue }
                    
                    let p1 = finalPosition(for: n1, in: size, bounds: self.mapBounds)
                    let p2 = finalPosition(for: n2, in: size, bounds: self.mapBounds)
                    
                    let dist = distanceToSegment(p: location, v: p1, w: p2)
                    if dist < bestHitDist {
                        bestHitDist = dist
                        newSelectedEdgeId = edge.id.uuidString
                    }
                }
            }
        }
        
        // Update bindings
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let node = newSelectedNode {
                selectedNode = node
                selectedLine = nil
                selectedEdgeId = nil
                print("🎯 [Map] Selected Station: \(node.name)")
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
                // Deselect all ONLY in explore mode
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
        // If Snap enabled, maybe optional snap here? Usually explicit drag handles snap well enough.
        // We can just add it and let user drag to snap.
        
        let newNode = Node(id: UUID().uuidString, name: name, type: .station, latitude: lat, longitude: lon, capacity: 10, platforms: 2)
        network.nodes.append(newNode)
        print("📍 Nuova stazione creata: \(name) a [\(lat), \(lon)]")
        return newNode
    }

    private func schematicPoint(for node: Node, in size: CGSize, bounds: MapBounds) -> CGPoint {
        let lon = node.longitude ?? 0
        let lat = node.latitude ?? 0
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - 100) + 50
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - 100) + 50
        return CGPoint(x: x, y: y)
    }
    
    private func finalPosition(for node: Node, in size: CGSize, bounds: MapBounds) -> CGPoint {
        // HUB VISUALIZATION LOGIC:
        // If this node is a satellite (has parentHubId) and has a visual offset direction,
        // we calculate its position relative to the PARENT HUB's position.
        // This avoids overlapping dots when coordinates are identical.
        if let parentId = node.parentHubId,
           let parent = network.nodes.first(where: { $0.id == parentId }) {
            
            // 1. Calculate Parent's Base Position
            let pPos = schematicPoint(for: parent, in: size, bounds: bounds)
            
            // 2. Apply Visual Offset based on Direction
            // 25 pixels is a good visual distance for the "Hub Square" effect
            let offset: CGFloat = 25.0
            
            // Default to BottomRight if direction is missing but parent exists (fallback)
            let direction = node.hubOffsetDirection ?? .bottomRight
            
            switch direction {
            case .topLeft:
                return CGPoint(x: pPos.x - offset, y: pPos.y - offset)
            case .topRight:
                return CGPoint(x: pPos.x + offset, y: pPos.y - offset)
            case .bottomLeft:
                return CGPoint(x: pPos.x - offset, y: pPos.y + offset)
            case .bottomRight:
                return CGPoint(x: pPos.x + offset, y: pPos.y + offset)
            }
        }
        
        return schematicPoint(for: node, in: size, bounds: bounds)
    }
    
    // Create London Underground-style path with rounded corners
    private func createRoundedPath(from start: CGPoint, to end: CGPoint, cornerRadius: CGFloat) -> Path {
        return Path { path in
            // For now, simple straight line
            // TODO: Detect direction changes and add rounded corners at junctions
            path.move(to: start)
            path.addLine(to: end)
        }
    }

    // Helper: Generate Octilinear Path (0, 45, 90 degrees)
    // Tries to use "Centered Diagonal" approach: Horizontal/Vertical -> Diagonal -> Horizontal/Vertical
    private func generateSchematicPoints(
        from p1: CGPoint, 
        to p2: CGPoint, 
        avoidPoints: [CGPoint] = [],
        neighborsStart: [CGPoint] = [],
        neighborsEnd: [CGPoint] = []
    ) -> [CGPoint] {
        let candidates = generateSchematicCandidates(from: p1, to: p2)
        
        // If no constraints, return the first preference (Centered)
        if avoidPoints.isEmpty && neighborsStart.isEmpty && neighborsEnd.isEmpty {
            return candidates.first?.points ?? [p1, p2]
        }
        
        var bestCandidate: (points: [CGPoint], cost: Double)? = nil
        
        for cand in candidates {
            let cost = calculatePathCost(
                path: cand.points, 
                avoid: avoidPoints,
                neighborsStart: neighborsStart,
                neighborsEnd: neighborsEnd
            )
            
            if cost == 0 { return cand.points } // Found perfect path
            
            if bestCandidate == nil || cost < bestCandidate!.cost {
                bestCandidate = (cand.points, cost)
            }
        }
        
        return bestCandidate?.points ?? [p1, p2]
    }
    
    private struct SchematicCandidate {
        let points: [CGPoint]
        let type: String
    }
    
    private func generateSchematicCandidates(from p1: CGPoint, to p2: CGPoint) -> [SchematicCandidate] {
        var candidates: [SchematicCandidate] = []
        
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let adx = abs(dx)
        let ady = abs(dy)
        let minDiff = min(adx, ady)
        let sx: CGFloat = dx > 0 ? 1 : -1
        let sy: CGFloat = dy > 0 ? 1 : -1
        
        if minDiff < 5 || abs(adx - ady) < 5 {
             return [SchematicCandidate(points: [p1, p2], type: "Direct")]
        }
        
        let diagLen = minDiff
        let straightLen = max(adx, ady) - diagLen
        
        // 1. Centered Diagonal
        if adx > ady {
            let hSeg = straightLen / 2.0
            let m1 = CGPoint(x: p1.x + sx * hSeg, y: p1.y)
            let m2 = CGPoint(x: m1.x + sx * diagLen, y: m1.y + sy * diagLen)
            candidates.append(SchematicCandidate(points: [p1, m1, m2, p2], type: "Centered"))
            
            // 2. Late Diagonal (Horizontal then Diagonal)
            let m_late = CGPoint(x: p1.x + sx * straightLen, y: p1.y)
            candidates.append(SchematicCandidate(points: [p1, m_late, p2], type: "Late"))
            
            // 3. Early Diagonal (Diagonal then Horizontal)
            let m_early = CGPoint(x: p1.x + sx * diagLen, y: p1.y + sy * diagLen)
            candidates.append(SchematicCandidate(points: [p1, m_early, p2], type: "Early"))
            
        } else {
            let vSeg = straightLen / 2.0
            let m1 = CGPoint(x: p1.x, y: p1.y + sy * vSeg)
            let m2 = CGPoint(x: m1.x + sx * diagLen, y: m1.y + sy * diagLen)
            candidates.append(SchematicCandidate(points: [p1, m1, m2, p2], type: "Centered"))
            
            // Late Diagonal (Vertical then Diagonal)
            let m_late = CGPoint(x: p1.x, y: p1.y + sy * straightLen)
            candidates.append(SchematicCandidate(points: [p1, m_late, p2], type: "Late"))
            
            // Early Diagonal (Diagonal then Vertical)
            let m_early = CGPoint(x: p1.x + sx * diagLen, y: p1.y + sy * diagLen)
            candidates.append(SchematicCandidate(points: [p1, m_early, p2], type: "Early"))
        }
        
        // 4. L-Shapes (90 degrees, no diagonal) - Fallback
        candidates.append(SchematicCandidate(points: [p1, CGPoint(x: p2.x, y: p1.y), p2], type: "L-HV"))
        candidates.append(SchematicCandidate(points: [p1, CGPoint(x: p1.x, y: p2.y), p2], type: "L-VH"))
        
        return candidates
    }
    
    private func calculatePathCost(path: [CGPoint], avoid: [CGPoint], neighborsStart: [CGPoint], neighborsEnd: [CGPoint]) -> Double {
        var cost: Double = 0
        let collisionThreshold: CGFloat = 25.0
        
        // 1. Collision Cost
        for i in 0..<path.count-1 {
            let s1 = path[i]
            let s2 = path[i+1]
            
            for p in avoid {
                 let d = distanceToSegment(p, s1, s2)
                 if d < collisionThreshold {
                     cost += (collisionThreshold - d) * 100
                 }
            }
        }
        
        // 2. Angle Cost (Neighbors)
        // Check start node angles
        if path.count > 1 {
            let vStart = normalize(vector: CGPoint(x: path[1].x - path[0].x, y: path[1].y - path[0].y))
            for n in neighborsStart {
                let vN = normalize(vector: CGPoint(x: n.x - path[0].x, y: n.y - path[0].y))
                let dotProd = vStart.x * vN.x + vStart.y * vN.y
                // If dotProd >= 0, angle <= 90 degrees (Acute or Right). We want > 90 (Obtuse), so dotProd < 0.
                if dotProd > -0.01 { 
                    cost += 500 // Penalty for angles <= 90
                }
            }
        }
        
        // Check end node angles
        if path.count > 1 {
            let last = path[path.count-1]
            let prev = path[path.count-2]
            // Vector leaving the end node back onto the track
            let vEnd = normalize(vector: CGPoint(x: prev.x - last.x, y: prev.y - last.y))
            for n in neighborsEnd {
                // Vector leaving the end node towards neighbor
                let vN = normalize(vector: CGPoint(x: n.x - last.x, y: n.y - last.y))
                let dotProd = vEnd.x * vN.x + vEnd.y * vN.y
                if dotProd > -0.01 {
                    cost += 500
                }
            }
        }
        
        return cost
    }
    
    private func normalize(vector: CGPoint) -> CGPoint {
        let len = sqrt(vector.x*vector.x + vector.y*vector.y)
        return len > 0 ? CGPoint(x: vector.x/len, y: vector.y/len) : CGPoint(x: 1, y: 0)
    }

    private func distanceToSegment(_ p: CGPoint, _ v: CGPoint, _ w: CGPoint) -> CGFloat {
        let l2 = (v.x - w.x)*(v.x - w.x) + (v.y - w.y)*(v.y - w.y)
        if l2 == 0 { return hypot(p.x - v.x, p.y - v.y) }
        var t = ((p.x - v.x)*(w.x - v.x) + (p.y - v.y)*(w.y - v.y)) / l2
        t = max(0, min(1, t))
        
        return hypot(p.x - (v.x + t * (w.x - v.x)), p.y - (v.y + t * (w.y - v.y)))
    }

    private func currentSchematicTrainPos(for schedule: TrainSchedule, in size: CGSize, now: Date, bounds: MapBounds) -> CGPoint? {
        for i in 0..<(schedule.stops.count - 1) {
            let s1 = schedule.stops[i]
            let s2 = schedule.stops[i+1]
            guard let d1 = s1.departureTime, let a2 = s2.arrivalTime else { continue }
            
            if now >= d1 && now <= a2 {
                let duration = a2.timeIntervalSince(d1)
                let elapsed = now.timeIntervalSince(d1)
                let progress = duration > 0 ? elapsed / duration : 0.0
                
                guard let n1 = network.nodes.first(where: { $0.id == s1.stationId }),
                      let n2 = network.nodes.first(where: { $0.id == s2.stationId }) else { return nil }
                
                // Use same schematic path as tracks
                let p1 = schematicPoint(for: n1, in: size, bounds: bounds)
                let p2 = schematicPoint(for: n2, in: size, bounds: bounds)
                let points = generateSchematicPoints(from: p1, to: p2)
                
                // Walk the polyline to find the point at 'progress'
                // 1. Calculate total length
                var totalLen: CGFloat = 0
                var segmentLens: [CGFloat] = []
                for j in 0..<(points.count - 1) {
                    let d = hypot(points[j+1].x - points[j].x, points[j+1].y - points[j].y)
                    totalLen += d
                    segmentLens.append(d)
                }
                
                if totalLen == 0 { return p1 }
                
                // 2. Find segment
                let targetDist = totalLen * CGFloat(progress)
                var currentDist: CGFloat = 0
                
                for j in 0..<(points.count - 1) {
                    let sl = segmentLens[j]
                    if currentDist + sl >= targetDist {
                        // In this segment
                        let localProg = (targetDist - currentDist) / (sl > 0 ? sl : 1)
                        let sp1 = points[j]
                        let sp2 = points[j+1]
                        return CGPoint(
                            x: sp1.x + (sp2.x - sp1.x) * localProg,
                            y: sp1.y + (sp2.y - sp1.y) * localProg
                        )
                    }
                    currentDist += sl
                }
                return points.last
            }
        }
        return nil
    }
}

// MARK: - Station Node View
struct StationNodeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var node: Node
    var network: RailwayNetwork
    var canvasSize: CGSize
    var isSelected: Bool
    var snapToGrid: Bool
    var gridUnit: Double
    var bounds: SchematicRailwayView.MapBounds
    var onTap: () -> Void
    @Binding var isMoveModeEnabled: Bool
    var onDragStarted: (() -> Void)? = nil // Added callback
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        let isHubOrInterchange = node.type == .interchange
        
        Group {
            if isHubOrInterchange {
                // Tube Style: White Circle with Thick Red Border
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(Color.red, lineWidth: 5)
                        .frame(width: 19, height: 19)
                }
            } else {
                let color = Color(hex: node.customColor ?? node.defaultColor) ?? .black
                let visualType = node.visualType ?? node.defaultVisualType
                
                ZStack {
                    // White backing to cover track lines
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                    
                    symbolView(type: visualType, color: color)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .frame(width: 44, height: 44) // Larger interactive area
        .contentShape(Circle())
        .background(Circle().fill(Color.white).opacity(0.001))
        .overlay(
            Group {
                if isSelected {
                    Circle().stroke(Color.blue, lineWidth: 2).scaleEffect(1.4)
                }
                
                if isMoveModeEnabled {
                    Circle()
                        .stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                        .scaleEffect(1.3)
                }
            }
        )
        .overlay(alignment: .top) {
            // Hide label if it's part of a multi-node hub (Canvas handles Red Label for hubs)
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
        .onLongPressGesture(minimumDuration: 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isMoveModeEnabled.toggle()
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .onTapGesture {
            onTap()
        }
            .gesture(
                isMoveModeEnabled ?
                DragGesture(minimumDistance: 5)
                    .onChanged { val in
                        if dragOffset == .zero {
                            onDragStarted?()
                        }
                        let deltaX = val.translation.width - dragOffset.width
                        let deltaY = val.translation.height - dragOffset.height
                        dragOffset = val.translation
                        
                        let drawWidth = canvasSize.width - 100
                        let drawHeight = canvasSize.height - 100
                        let safeDrawWidth = drawWidth > 0 ? drawWidth : 1
                        let safeDrawHeight = drawHeight > 0 ? drawHeight : 1
                        
                        let dLon = (deltaX / safeDrawWidth) * bounds.xRange
                        let dLat = -(deltaY / safeDrawHeight) * bounds.yRange
                        
                        // Move this node
                        node.latitude = (node.latitude ?? 0) + dLat
                        node.longitude = (node.longitude ?? 0) + dLon
                        
                    }
                    .onEnded { val in
                        dragOffset = .zero
                        if snapToGrid {
                            snapNodeToGrid()
                        }
                    }
                : nil
            )
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
 
