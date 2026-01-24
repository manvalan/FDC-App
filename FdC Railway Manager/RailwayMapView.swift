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
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                
                // ScrollView for native scrolling/panning
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    let canvasSize = CGSize(
                        width: max(geo.size.width * zoomLevel, geo.size.width),
                        height: max(geo.size.height * zoomLevel, geo.size.height)
                    )
                    
                    ZStack(alignment: .topLeading) {
                        // Background (White + Grid)
                        ZStack {
                            Color.white
                            if showGrid {
                                GridShape(spacing: gridSize)
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            }
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .onTapGesture(count: 1, coordinateSpace: .local) { location in
                            handleCanvasTap(at: location, in: canvasSize)
                        }
                        
                        // 1. Draw Map Content
                        Canvas { context, size in
                            // Helper to project point
                            func p(_ node: Node) -> CGPoint {
                                schematicPoint(for: node, in: size)
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
                             let now = Date()
                             for schedule in appState.simulator.schedules {
                                if let pos = currentSchematicTrainPos(for: schedule, in: size, now: now) {
                                    let trainDot = Path(ellipseIn: CGRect(x: pos.x - 6, y: pos.y - 6, width: 12, height: 12))
                                    context.fill(trainDot, with: .color(.yellow))
                                    context.stroke(trainDot, with: .color(.black), lineWidth: 1)
                                    // Label? Only on high zoom
                                    if zoomLevel > 2.0 {
                                        let label = Text(schedule.trainName).font(.caption2).bold()
                                        context.draw(label, at: CGPoint(x: pos.x, y: pos.y - 15))
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
                                gridSize: gridSize,
                                onTap: { handleStationTap(network.nodes[index]) }
                            )
                            .position(schematicPoint(for: network.nodes[index], in: canvasSize))
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                }
                
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
                    Button(action: { editMode = .addStation }) {
                        Label("Aggiungi Stazione", systemImage: "building.2.crop.circle.badge.plus")
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
            
            let p1 = schematicPoint(for: n1, in: size)
            let p2 = schematicPoint(for: n2, in: size)
            
            let dist = distanceToSegment(p: location, v: p1, w: p2)
            if dist < closestDist {
                closestDist = dist
                // ERROR FIX: Convert UUID to String
                foundEdgeId = edge.id.uuidString 
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

    private func schematicPoint(for node: Node, in size: CGSize, network: RailwayNetwork? = nil) -> CGPoint {
        let net = network ?? self.network
        let lats = net.nodes.compactMap { $0.latitude }
        let lons = net.nodes.compactMap { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 100
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 100
        
        let xRange = maxLon - minLon
        let yRange = maxLat - minLat
        let safeXRange = xRange == 0 ? 1.0 : xRange
        let safeYRange = yRange == 0 ? 1.0 : yRange
        
        let x = (node.longitude ?? 0 - minLon) / safeXRange * (size.width - 100) + 50
        let y = (1.0 - (node.latitude ?? 0 - minLat) / safeYRange) * (size.height - 100) + 50
        
        return CGPoint(x: x, y: y)
    }

    private func currentSchematicTrainPos(for schedule: TrainSchedule, in size: CGSize, now: Date) -> CGPoint? {
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
                
                let p1 = schematicPoint(for: n1, in: size)
                let p2 = schematicPoint(for: n2, in: size)
                
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
    var gridSize: CGFloat
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
                        
                        let drawWidth = canvasSize.width - 100
                        let drawHeight = canvasSize.height - 100
                        let safeDrawWidth = drawWidth > 0 ? drawWidth : 1
                        let safeDrawHeight = drawHeight > 0 ? drawHeight : 1
                        
                        var dLon = (deltaX / safeDrawWidth) * safeXRange
                        var dLat = -(deltaY / safeDrawHeight) * safeYRange
                        
                        node.latitude = (node.latitude ?? 0) + dLat
                        node.longitude = (node.longitude ?? 0) + dLon
                        
                        // Note: Real-time snapping in coordinates is hard because of projection. 
                        // Instead, we snap the DISPLAY position by updating lat/lon to match snapped screen points?
                        // Actually, better to just let it drift and snap on END, or snap delta?
                        // Simplest: update lat/lon normally, but if snapToGrid, round lat/lon to resemble grid?
                        // No, snapping usually happens on screen coordinates.
                        // Let's implement visual snap here is tricky due to circular dependency (lat->point->lat).
                        // Better approach: Calculate current Point, Snap Point, Convert Point->Lat/Lon.
                    }
                    .onEnded { val in
                        dragOffset = .zero
                        if snapToGrid {
                            snapNodeToGrid()
                        }
                    }
            )
    }
    
    // Helper to snap ACTUAL lat/lon based on screen grid
    private func snapNodeToGrid() {
        // 1. Convert current Lat/Lon to Screen Point
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
        
        let drawWidth = canvasSize.width - 100
        let drawHeight = canvasSize.height - 100
        
        // Current Screen Pos
        let curX = (node.longitude ?? 0 - minLon) / safeXRange * drawWidth + 50
        let curY = (1.0 - (node.latitude ?? 0 - minLat) / safeYRange) * drawHeight + 50
        
        // Snap Screen Pos
        let snappedX = round(curX / gridSize) * gridSize
        let snappedY = round(curY / gridSize) * gridSize
        
        // Convert Snapped Point back to Lat/Lon
        let newLon = minLon + ((snappedX - 50) / drawWidth) * safeXRange
        let newLat = minLat + (1.0 - (snappedY - 50) / drawHeight) * safeYRange
        
        node.latitude = newLat
        node.longitude = newLon
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

struct GridShape: Shape {
    var spacing: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        for x in stride(from: 0, to: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, to: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}
