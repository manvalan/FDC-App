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

                            // 1. Draw RAW Infrastructure (Edges)
                            // We draw these even in .lines mode but fainter if needed, or with borders as requested
                            for edge in network.edges {
                                guard let n1 = network.nodes.first(where: { $0.id == edge.from }),
                                      let n2 = network.nodes.first(where: { $0.id == edge.to }) else { continue }
                                
                                let p1 = finalPosition(for: n1, in: size, bounds: bounds)
                                let p2 = finalPosition(for: n2, in: size, bounds: bounds)
                                
                                // Base Track Path
                                let path = Path { p in
                                    p.move(to: p1)
                                    p.addLine(to: p2)
                                }
                                
                                // Styles based on physical properties
                                let baseColor: Color = (mode == .network) ? .gray : .gray.opacity(0.3)
                                var lineWidth: CGFloat = 1.5
                                
                                if edge.trackType == .highSpeed {
                                    lineWidth = 3
                                    // High Speed: Red Borders
                                    context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: lineWidth + 1.5, lineCap: .round))
                                    context.stroke(path, with: .color(baseColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                } else if edge.trackType == .double {
                                    lineWidth = 3
                                    // Double Track: Black Borders
                                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: lineWidth + 1.5, lineCap: .round))
                                    context.stroke(path, with: .color(baseColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                } else {
                                    context.stroke(path, with: .color(baseColor), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
                                }
                                
                                // If mode is network, we also draw the edges that might have been selected
                                if mode == .network && selectedEdgeId == edge.id.uuidString {
                                    context.stroke(path, with: .color(.blue.opacity(0.5)), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                                }
                            }

                            // 0. Hub & Interchange Visualization (Tube Style Corridor)
                            // We visualize both explicitly grouped Hubs (parentHubId) AND standalone Interchanges
                            var visualGroups: [String: [Node]] = [:]
                            
                            // Group 1: Explicit Hubs
                            let explicitHubs = Dictionary(grouping: network.nodes.filter { $0.parentHubId != nil }, by: { $0.parentHubId! })
                            visualGroups.merge(explicitHubs) { current, _ in current }
                            
                            // Group 2: Standalone Interchanges
                            let orphanInterchanges = network.nodes.filter { $0.type == .interchange && $0.parentHubId == nil }
                            for node in orphanInterchanges {
                                visualGroups[node.id] = [node]
                            }

                            for (groupId, nodes) in visualGroups {
                                let positions = nodes.map { finalPosition(for: $0, in: size, bounds: bounds) }
                                
                                // Draw Tube-style Connection (Corridor) for groups
                                // Black outline, White center.
                                
                                if nodes.count > 1 {
                                    // Connected components (pairwise)
                                    for i in 0..<nodes.count {
                                        for j in (i+1)..<nodes.count {
                                            let p1 = positions[i]
                                            let p2 = positions[j]
                                            
                                            let hPath = Path { p in p.move(to: p1); p.addLine(to: p2) }
                                            
                                            // Black Border (Connector)
                                            context.stroke(hPath, with: .color(.black), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                            // White Interior (Passage)
                                            context.stroke(hPath, with: .color(.white), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                        }
                                    }
                                }
                                
                                // Unified Name
                                if let parentNode = network.nodes.first(where: { $0.id == groupId }) ?? nodes.first {
                                    // Position: "Sotto a tutto" (Below highest Y value, which is lowest on screen)
                                    // Find max Y among nodes
                                    let maxY = positions.map { $0.y }.max() ?? positions[0].y
                                    let labelY = maxY + 35 // Offset below the lowest station
                                    
                                    // Center X of the group
                                    let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                                    
                                    let text = Text(parentNode.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.red) // User requested RED
                                    
                                    // Draw text shadow (white glow)
                                    var solvedText = context.resolve(text.foregroundColor(.white))
                                    context.draw(solvedText, at: CGPoint(x: centerX, y: labelY + 1))
                                    context.draw(solvedText, at: CGPoint(x: centerX - 1, y: labelY))
                                    context.draw(solvedText, at: CGPoint(x: centerX + 1, y: labelY))
                                    
                                    // Draw main text in RED
                                    solvedText = context.resolve(text.foregroundColor(.red))
                                    context.draw(solvedText, at: CGPoint(x: centerX, y: labelY))
                                }
                            }
                            
                            if mode == .lines {
                                // Draw Commercial Lines with London Underground-style rounded corners
                                for (key, lines) in segmentLineMap {
                                    guard let n1 = network.nodes.first(where: { $0.id == key.from }),
                                          let n2 = network.nodes.first(where: { $0.id == key.to }) else { continue }
                                    
                                    let p1 = finalPosition(for: n1, in: size, bounds: bounds)
                                    let p2 = finalPosition(for: n2, in: size, bounds: bounds)
                                    
                                    let angle = atan2(p2.y - p1.y, p2.x - p1.x)
                                    let offsetBase: CGFloat = 3.0
                                    
                                    for (i, line) in lines.enumerated() {
                                        let offset = CGFloat(i) * offsetBase - (CGFloat(lines.count - 1) * offsetBase / 2.0)
                                        
                                        // Offset perpendicular to segment
                                        let offsetVector = CGPoint(
                                            x: -sin(angle) * offset,
                                            y: cos(angle) * offset
                                        )
                                        
                                        let start = CGPoint(x: p1.x + offsetVector.x, y: p1.y + offsetVector.y)
                                        let end = CGPoint(x: p2.x + offsetVector.x, y: p2.y + offsetVector.y)
                                        
                                        // Create path with rounded corners (London Underground style)
                                        let linePath = createRoundedPath(from: start, to: end, cornerRadius: 12)
                                        
                                        let color = Color(hex: line.color ?? "") ?? .blue
                                        let thickness = (line.id == selectedLine?.id) ? 3.0 : 1.2
                                        
                                        context.stroke(linePath, with: .color(color), style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                                        
                                        // Highlight selected line
                                        if line.id == selectedLine?.id {
                                            context.stroke(linePath, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: thickness + 4, lineCap: .round, lineJoin: .round))
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
                                onTap: { handleStationTap(node) }
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
        .toolbar(content: {
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
        })
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
        
        // Reset selections if tapping empty space (start with a threshold)
        var bestHitDist: CGFloat = 15.0
        var newSelectedNode: Node? = nil
        var newSelectedLine: RailwayLine? = nil
        var newSelectedEdgeId: String? = nil
        
        // 1. Hit Test for Nodes (Stations)
        for node in network.nodes {
            let pNode = schematicPoint(for: node, in: size, bounds: self.mapBounds)
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
                                let p1 = schematicPoint(for: n1, in: size, bounds: self.mapBounds)
                                let p2 = schematicPoint(for: n2, in: size, bounds: self.mapBounds)
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
                    
                    let p1 = schematicPoint(for: n1, in: size, bounds: self.mapBounds)
                    let p2 = schematicPoint(for: n2, in: size, bounds: self.mapBounds)
                    
                    let dist = distanceToSegment(p: location, v: p1, w: p2)
                    if dist < bestHitDist {
                        bestHitDist = dist
                        newSelectedEdgeId = edge.id.uuidString
                    }
                }
            }
        }
        
        // Update bindings
        if newSelectedNode != nil {
            selectedNode = newSelectedNode
        } else if newSelectedLine != nil {
            selectedLine = newSelectedLine
        } else if newSelectedEdgeId != nil {
            selectedEdgeId = newSelectedEdgeId
        } else {
            // Deselect all
            selectedNode = nil
            selectedLine = nil
            selectedEdgeId = nil
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
        print("📍 Nuova stazione creata: \(name) a [\(lat), \(lon)]")
    }

    private func schematicPoint(for node: Node, in size: CGSize, bounds: MapBounds) -> CGPoint {
        let lon = node.longitude ?? 0
        let lat = node.latitude ?? 0
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - 100) + 50
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - 100) + 50
        return CGPoint(x: x, y: y)
    }
    
    // Calculate final visual position including hub offset
    private func finalPosition(for node: Node, in size: CGSize, bounds: MapBounds) -> CGPoint {
        let basePosition = schematicPoint(for: node, in: size, bounds: bounds)
        
        // Apply fixed visual offset for hub-linked stations
        if node.parentHubId != nil {
            return CGPoint(x: basePosition.x - 30, y: basePosition.y + 30)
        }
        return basePosition
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
        let isHubOrInterchange = node.type == .interchange || node.parentHubId != nil
        
        Group {
            if isHubOrInterchange {
                // Tube Style: White Circle with Thick Black Border
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(Color.black, lineWidth: 5)
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
            }
        )
        .overlay(alignment: .top) {
            // Hide label if it's a Hub or Interchange (Canvas handles Red Label)
            if !isHubOrInterchange {
                Text(node.name)
                    .font(.system(size: 14, weight: .black))
                    .fixedSize()
                    .foregroundColor(.black)
                    .shadow(color: .white, radius: 2)
                    .offset(y: 28)
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture {
            onTap()
        }
            .gesture(
                DragGesture(minimumDistance: 5)
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
                        
                        // Move this node
                        node.latitude = (node.latitude ?? 0) + dLat
                        node.longitude = (node.longitude ?? 0) + dLon
                        
                        // Also move linked hub stations (synchronized movement)
                        if let parentHubId = node.parentHubId,
                           let parentIndex = network.nodes.firstIndex(where: { $0.id == parentHubId }) {
                            // This station is a child, move the parent too
                            network.nodes[parentIndex].latitude = (network.nodes[parentIndex].latitude ?? 0) + dLat
                            network.nodes[parentIndex].longitude = (network.nodes[parentIndex].longitude ?? 0) + dLon
                        } else {
                            // This might be a parent, move all children
                            for i in network.nodes.indices {
                                if network.nodes[i].parentHubId == node.id {
                                    network.nodes[i].latitude = (network.nodes[i].latitude ?? 0) + dLat
                                    network.nodes[i].longitude = (network.nodes[i].longitude ?? 0) + dLon
                                }
                            }
                        }
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
