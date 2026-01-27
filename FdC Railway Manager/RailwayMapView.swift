import SwiftUI
import MapKit

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
    var mode: MapVisualizationMode // Added mode

    var body: some View {
        ZStack {
            SchematicRailwayView(
                network: network,
                appState: appState,
                selectedNode: $selectedNode,
                selectedLine: $selectedLine,
                selectedEdgeId: $selectedEdgeId,
                showGrid: $showGrid,
                mode: mode
            )
        }
        .navigationTitle("Schema Rete")
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
    var mode: RailwayMapView.MapVisualizationMode
    
    @State private var zoomLevel: CGFloat = 2.0
    @State private var editMode: EditMode = .explore
    @State private var firstStationId: String? = nil
    
    // Grid State: managed by parent binding now
    private let gridSize: CGFloat = 50.0
    
    // New state for line filtering
    @State private var hiddenLineIds: Set<String> = []
    
    // Track Selection: managed by parent binding
    // Removed local state
    
    enum EditMode: String, CaseIterable, Identifiable {
        case explore = "Esplora"
        case addTrack = "Crea Binari"
        case addStation = "Aggiungi Stazione"
        var id: String { rawValue }
    }
    
    // Pinch to Zoom state
    @State private var magnification: CGFloat = 1.0
    
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
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 100
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 100
        let xr = maxLon - minLon
        let yr = maxLat - minLat
        return MapBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon,
                         xRange: xr == 0 ? 1.0 : xr, yRange: yr == 0 ? 1.0 : yr)
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
                        
                        // 1. Draw Map Content
                        TimelineView(.animation) { timelineContext in
                            Canvas { context, size in
                                // Helper to project point
                                func p(_ node: Node) -> CGPoint {
                                    self.schematicPoint(for: node, in: size, bounds: bounds)
                                }

                            if mode == .network {
                                // Draw RAW Infrastructure (Edges)
                                for edge in network.edges {
                                    guard let n1 = network.nodes.first(where: { $0.id == edge.from }),
                                          let n2 = network.nodes.first(where: { $0.id == edge.to }) else { continue }
                                    
                                    let p1 = p(n1)
                                    let p2 = p(n2)
                                    
                                    let path = Path { p in
                                        p.move(to: p1)
                                        p.addLine(to: p2)
                                    }
                                    
                                    // Styles based on physical properties
                                    var strokeColor: Color = .gray
                                    var lineWidth: CGFloat = 2
                                    
                                    if edge.trackType == .highSpeed {
                                        strokeColor = .black
                                        lineWidth = 3
                                    } else if edge.trackType == .double {
                                        strokeColor = .gray
                                        lineWidth = 3
                                    } else {
                                        strokeColor = .gray.opacity(0.8)
                                        lineWidth = 1.5
                                    }
                                    
                                    context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                }
                            }
                            
                            if mode == .lines {
                                // Draw Commercial Lines
                                // 1. Draw "Faint" background tracks for context (optional, maybe very light)
                                // Let's skip background tracks as per user request ("show only when requested")
                                
                                // 2. Draw Lines
                                // To handle multiple lines on same segment, we can use a simple offset strategy?
                                // Or just draw them on top of each other with blending.
                                // Let's do simple drawing first.
                                
                                for (index, line) in network.lines.enumerated() {
                                    if hiddenLineIds.contains(line.id) { continue }
                                    
                                    let color = Color(hex: line.color ?? "") ?? .blue
                                    let lineWidth: CGFloat = 3.0
                                    
                                    // Construct Path from stations
                                    var path = Path()
                                    guard line.stations.count > 1 else { continue }
                                    
                                    if let first = network.nodes.first(where: { $0.id == line.stations[0] }) {
                                        path.move(to: p(first))
                                    }
                                    
                                    for i in 1..<line.stations.count {
                                        let sPrev = line.stations[i-1]
                                        let sCurr = line.stations[i]
                                        
                                        if let nPrev = network.nodes.first(where: { $0.id == sPrev }),
                                           let nCurr = network.nodes.first(where: { $0.id == sCurr }) {
                                            
                                            // TODO: Offset logic for parallelism?
                                            // Simple offset based on index to avoid total occlusion
                                            // Just basic line for now
                                            path.addLine(to: p(nCurr))
                                        }
                                    }
                                    
                                    context.stroke(path, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                }
                            }
                            
                                // Draw Active Trains (Overlay)
                                 let now = timelineContext.date
                                 for schedule in appState.simulator.schedules {
                                    if let pos = self.currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds) {
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
                        
                        // 2. Interactive Nodes
                        ForEach(visibleNodeIndices, id: \.self) { index in
                            StationNodeView(
                                node: $network.nodes[index],
                                network: network,
                                canvasSize: canvasSize,
                                isSelected: selectedNode?.id == network.nodes[index].id,
                                snapToGrid: showGrid,
                                gridUnit: coordinateGridStep,
                                bounds: bounds,
                                onTap: { handleStationTap(network.nodes[index]) }
                            )
                            .position(schematicPoint(for: network.nodes[index], in: canvasSize, bounds: bounds))
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            magnification = value
                        }
                        .onEnded { value in
                            zoomLevel *= magnification
                            magnification = 1.0
                        }
                )
                
                // Controls
                VStack(alignment: .trailing, spacing: 10) {
                    if editMode != .explore {
                        HStack {
                            Text(editMode.rawValue)
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.yellow)
                                .cornerRadius(8)
                            
                            Button(action: { editMode = .explore }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.trailing)
                    }
                    
                    VStack(spacing: 8) {
                        // Grid toggle moved to Settings

                        Button(action: {
                            withAnimation { zoomLevel = min(zoomLevel + 0.5, 5.0) }
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .padding(12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        Button(action: {
                            withAnimation { zoomLevel = max(zoomLevel - 0.5, 1.0) }
                        }) {
                            Image(systemName: "minus")
                                .font(.title2)
                                .padding(12)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        Button(action: {
                            withAnimation { zoomLevel = 1.0 }
                        }) {
                            Image(systemName: "arrow.down.left.and.arrow.up.right")
                                .font(.title2)
                                .padding(12)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // ... (Keep existing toolbar items)
                
                // 1. Zoom to Fit
                Button(action: { withAnimation { zoomLevel = 1.0 } }) {
                    Label("Zoom", systemImage: "arrow.down.left.and.arrow.up.right")
                }
                
                Menu {
                     Text("Visibilità Linee")
                     Divider()
                     ForEach(network.lines) { line in
                         Button(action: {
                             // Force update workaround
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
                     Button("Mostra Tutte") { 
                         hiddenLineIds.removeAll()
                         selectedLine = nil
                     }
                } label: {
                     Label("Linee", systemImage: "line.3.horizontal.decrease.circle")
                }

                Menu {
                    Button(action: {
                        editMode = .addStation
                    }) {
                        Label("Aggiungi Stazione", systemImage: "building.2.fill")
                    }
                    Button(action: { editMode = .addTrack }) {
                        Label("Crea Binari", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                } label: {
                    Label("Modifica", systemImage: "pencil.circle")
                }
            }
        }
    }
    
    // MARK: - Interaction Handlers
    private func handleStationTap(_ node: Node) {
        if editMode == .addTrack {
            if let first = firstStationId {
                if first != node.id {
                    // Create Edge
                    // Note: Edge likely needs an ID if we want to select it by ID.
                    // If Edge struct doesn't have ID in constructor, we might need to change Edge struct or rely on internal generating.
                    // Assuming Edge has default init, let's try standard.
                    // If Edge has `id`, we should use it. 
                    // Let's check `Edge` definition if possible, but for now assuming it exists.
                    let newEdge = Edge(from: first, to: node.id, distance: 10, trackType: .regional, maxSpeed: 120, capacity: 10)
                    network.edges.append(newEdge)
                    firstStationId = nil
                }
            } else {
                firstStationId = node.id
            }
        } else {
            selectedNode = node
        }
    }
    
    private func handleCanvasTap(at location: CGPoint, in size: CGSize) {
        if editMode == .addStation {
            createStation(at: location, in: size)
            return
        }
        
        selectedNode = nil
        
        // Hit Test for Edges
        var closestDist: CGFloat = 20.0
        var foundEdgeId: String? = nil
        
        for edge in network.edges {
            guard let n1 = network.nodes.first(where: { $0.id == edge.from }),
                  let n2 = network.nodes.first(where: { $0.id == edge.to }) else { continue }
            
            let p1 = schematicPoint(for: n1, in: size, bounds: self.mapBounds)
            let p2 = schematicPoint(for: n2, in: size, bounds: self.mapBounds)
            
            let dist = distanceToSegment(p: location, v: p1, w: p2)
            if dist < closestDist {
                closestDist = dist
                if let uid = edge.id as? UUID {
                    foundEdgeId = uid.uuidString
                } else {
                    foundEdgeId = "\(edge.id)"
                }
            }
        }
        
        // Set binding instead of local state
        selectedEdgeId = foundEdgeId
    }
    
    private func distanceToSegment(p: CGPoint, v: CGPoint, w: CGPoint) -> CGFloat {
        let l2 = (v.x - w.x)*(v.x - w.x) + (v.y - w.y)*(v.y - w.y)
        if l2 == 0 { return hypot(p.x - v.x, p.y - v.y) }
        var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
        t = max(0, min(1, t))
        let proj = CGPoint(x: v.x + t * (w.x - v.x), y: v.y + t * (w.y - v.y))
        return hypot(p.x - proj.x, p.y - proj.y)
    }
    
    private func createStation(at location: CGPoint, in size: CGSize) {
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
        
        let name = "Stazione \(network.nodes.count + 1)"
        // If Snap enabled, maybe optional snap here? Usually explicit drag handles snap well enough.
        // We can just add it and let user drag to snap.
        
        let newNode = Node(id: UUID().uuidString, name: name, type: .station, latitude: lat, longitude: lon, capacity: 10, platforms: 2)
        network.nodes.append(newNode)
    }

    private func schematicPoint(for node: Node, in size: CGSize, bounds: MapBounds) -> CGPoint {
        let lon = node.longitude ?? 0
        let lat = node.latitude ?? 0
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - 100) + 50
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - 100) + 50
        return CGPoint(x: x, y: y)
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
                
                let p1 = schematicPoint(for: n1, in: size, bounds: bounds)
                let p2 = schematicPoint(for: n2, in: size, bounds: bounds)
                
                return CGPoint(
                    x: p1.x + (p2.x - p1.x) * progress,
                    y: p1.y + (p2.y - p1.y) * progress
                )
            }
        }
        return nil
    }
    
    private var visibleNodeIndices: [Int] {
        return Array(network.nodes.indices)
    }
}

// MARK: - Station Node View
struct StationNodeView: View {
    @Binding var node: Node
    var network: RailwayNetwork
    var canvasSize: CGSize
    var isSelected: Bool
    var snapToGrid: Bool
    var gridUnit: Double
    var bounds: SchematicRailwayView.MapBounds
    var onTap: () -> Void
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        let color = Color(hex: node.customColor ?? "") ?? (node.type == Node.NodeType.interchange ? .red : .black)
        let visualType = node.visualType ?? (node.type == Node.NodeType.interchange ? Node.StationVisualType.filledSquare : Node.StationVisualType.filledCircle)
        
        symbolView(type: visualType, color: color)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.white).scaleEffect(0.8))
            .overlay(
                Group {
                    if isSelected {
                        Circle().stroke(Color.blue, lineWidth: 2).scaleEffect(1.4)
                    }
                }
            )
            .overlay(alignment: .top) {
                Text(node.name)
                    .font(.system(size: 14, weight: .black))
                    .fixedSize()
                    .foregroundColor(.black)
                    .shadow(color: .white, radius: 2)
                    .offset(y: 28)
            }
            .onTapGesture {
                onTap()
            }
            .gesture(
                DragGesture()
                    .onChanged { val in
                        let deltaX = val.translation.width - dragOffset.width
                        let deltaY = val.translation.height - dragOffset.height
                        dragOffset = val.translation
                        
                        let drawWidth = canvasSize.width - 100
                        let drawHeight = canvasSize.height - 100
                        let safeDrawWidth = drawWidth > 0 ? drawWidth : 1
                        let safeDrawHeight = drawHeight > 0 ? drawHeight : 1
                        
                        let dLon = (deltaX / safeDrawWidth) * bounds.xRange
                        let dLat = -(deltaY / safeDrawHeight) * bounds.yRange
                        
                        node.latitude = (node.latitude ?? 0) + dLat
                        node.longitude = (node.longitude ?? 0) + dLon
                    }
                    .onEnded { val in
                        dragOffset = .zero
                        if snapToGrid {
                            snapNodeToGrid()
                        }
                    }
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
