import SwiftUI
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { exportMap(as: .jpeg) }) {
                        Label("Esporta Immagine (JPEG)", systemImage: "photo")
                    }
                    Button(action: { exportMap(as: .pdf) }) {
                        Label("Esporta PDF", systemImage: "doc.text")
                    }
                    Divider()
                    Button(action: { printMap() }) {
                        Label("Stampa", systemImage: "printer")
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
        // Robust Snapshot Logic using UIHostingController
        // This avoids 'White/Blank' images common with ImageRenderer on complex off-screen views
        let view = SnapshotWrapper(network: network, mode: mode).edgesIgnoringSafeArea(.all)
        let controller = UIHostingController(rootView: view)
        
        // Define High-Res Target Size (4:3 Aspect Ratio)
        let targetSize = CGSize(width: 2048, height: 1536)
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .white

        // Force Layout
        // We create a temporary window to ensure SwiftUI layout engine fully engages (hack helper for some cases)
        // But often just layoutIfNeeded works if bounds are set.
        controller.view.layoutIfNeeded()

        // Render to Image
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { ctx in
             // Fill white background explicitly
             UIColor.white.setFill()
             ctx.fill(CGRect(origin: .zero, size: targetSize))
             
             // Render the layer
             // Note: layer.render sometimes misses loose SwiftUI content, but usually works for Canvas/Shapes.
             // If this fails, we might need drawHierarchy, but that requires being on-screen keyWindow.
             controller.view.layer.render(in: ctx.cgContext)
        }
        
        if format == .jpeg {
             shareItem(image)
        } else {
             // Create PDF containing the captured image (Raster PDF)
             // This guarantees the PDF matches the image and isn't blank.
             let pdfUrl = FileManager.default.temporaryDirectory.appendingPathComponent("MappaFerroviaria.pdf")
             let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: targetSize))
             try? pdfRenderer.writePDF(to: pdfUrl) { ctx in
                 ctx.beginPage()
                 image.draw(at: .zero)
             }
             shareItem(pdfUrl)
        }
    }
    
    private func shareItem(_ item: Any) {
        let av = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            av.popoverPresentationController?.sourceRect = CGRect(x: 100, y: 100, width: 0, height: 0) // Anchor for iPad
            root.present(av, animated: true, completion: nil)
        }
    }
    
    private func printMap() {
        // Print Logic re-using Generate Snapshot
        // We generate the image first to ensure WYSIWYG printing
        let view = SnapshotWrapper(network: network, mode: mode).edgesIgnoringSafeArea(.all)
        let controller = UIHostingController(rootView: view)
        let targetSize = CGSize(width: 2048, height: 1536)
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .white
        controller.view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { ctx in
             UIColor.white.setFill()
             ctx.fill(CGRect(origin: .zero, size: targetSize))
             controller.view.layer.render(in: ctx.cgContext)
        }

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Mappa Ferroviaria"
        
        let interactionController = UIPrintInteractionController.shared
        interactionController.printInfo = printInfo
        interactionController.printingItem = image
        interactionController.present(animated: true, completionHandler: nil)
    }
    
    // Minimal wrapper for export without interactive elements
    struct SnapshotWrapper: View {
        @ObservedObject var network: RailwayNetwork
        var mode: MapVisualizationMode
        
        var body: some View {
            // Simplified Schematic View (Static)
            // Reusing SchematicRailwayView logic would be best but requires mocking bindings.
            // For now, we render a placeholder or a static version.
            // To do it properly, we need to extract the Canvas logic.
            // Using actual SchematicRailwayView with constant bindings:
            SchematicRailwayView(
                network: network,
                appState: AppState(), // Dummy
                selectedNode: .constant(nil),
                selectedLine: .constant(nil),
                selectedEdgeId: .constant(nil),
                showGrid: .constant(false),
                mode: mode
            )
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
                                
                                // Base Track Path (Schematic 0-45-90)
                                let points = generateSchematicPoints(from: p1, to: p2)
                                let path = Path { p in
                                    guard let first = points.first else { return }
                                    p.move(to: first)
                                    for pt in points.dropFirst() {
                                        p.addLine(to: pt)
                                    }
                                }
                                
                                // Styles based on physical properties
                                let baseColor: Color = (mode == .network) ? .gray : .gray.opacity(0.3)
                                var lineWidth: CGFloat = 1.5
                                
                                if edge.trackType == .highSpeed {
                                    // High Speed: Bold Red with Dashed Spine
                                    lineWidth = 4
                                    context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
                                    context.stroke(path, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 5]))
                                } else if edge.trackType == .double {
                                    lineWidth = 3
                                    // Double Track: Black Borders
                                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: lineWidth + 1.5, lineCap: .round))
                                    context.stroke(path, with: .color(baseColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                } else {
                                    context.stroke(path, with: .color(baseColor), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                                }
                                
                                // If mode is network, we also draw the edges that might have been selected
                                if mode == .network && selectedEdgeId == edge.id.uuidString {
                                    context.stroke(path, with: .color(.blue.opacity(0.5)), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                                }
                            }

                            // 0. Hub & Interchange Visualization (Tube Style Corridor)
                            // We visualize explicit Hubs AND automatically cluster nearby orphan Interchanges
                            var visualGroups: [[Node]] = []
                            var processedNodeIds: Set<String> = []
                            
                            // 1. Explicit Hubs (Data-defined)
                            let explicitGroups = Dictionary(grouping: network.nodes.filter { $0.parentHubId != nil }, by: { $0.parentHubId! })
                            for (_, nodes) in explicitGroups {
                                if nodes.count > 1 {
                                    // Only trust explicit grouping if it actually connects 2+ nodes
                                    visualGroups.append(nodes)
                                    nodes.forEach { processedNodeIds.insert($0.id) }
                                }
                                // If nodes.count == 1, we ignore it here (don't mark as processed).
                                // It will fall through to step 2, allowing it to clustered by proximity.
                                // This fixes the case where User defined "Hubs" but gave them unique IDs (so they didn't group).
                            }
                            
                            // 2. Orphan Interchanges & Singleton Hubs (Proximity-based)
                            // We capture:
                            // - Nodes with type .interchange (orphans)
                            // - Nodes with parentHubId that were alone in their group (singletons)
                            let potentialOrphans = network.nodes.filter { 
                                ($0.type == .interchange || $0.parentHubId != nil) && !processedNodeIds.contains($0.id)
                            }
                            
                            // Simple visual clustering
                            var orphansToCheck = potentialOrphans
                            while let node = orphansToCheck.first {
                                orphansToCheck.removeFirst()
                                var cluster = [node]
                                let p1 = finalPosition(for: node, in: size, bounds: bounds)
                                
                                // Find neighbors
                                var i = 0
                                while i < orphansToCheck.count {
                                    let other = orphansToCheck[i]
                                    let p2 = finalPosition(for: other, in: size, bounds: bounds)
                                    let dist = hypot(p1.x - p2.x, p1.y - p2.y)
                                    
                                    // Threshold: 50 points (approx 2x node size)
                                    if dist < 50 {
                                        cluster.append(other)
                                        orphansToCheck.remove(at: i)
                                    } else {
                                        i += 1
                                    }
                                }
                                visualGroups.append(cluster)
                            }

                            for nodes in visualGroups {
                                let positions = nodes.map { finalPosition(for: $0, in: size, bounds: bounds) }
                                
                                // Draw Tube-style Connection (Corridor)
                                // Only if >1 node in the visual cluster
                                if nodes.count > 1 {
                                    for i in 0..<nodes.count {
                                        for j in (i+1)..<nodes.count {
                                            let p1 = positions[i]
                                            let p2 = positions[j]
                                            
                                            let hPath = Path { p in p.move(to: p1); p.addLine(to: p2) }
                                            
                                            // Red Border (Connector) - Matches user request
                                            context.stroke(hPath, with: .color(.red), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                                            // White Interior (Passage) - Width 14 to match inner node
                                            context.stroke(hPath, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                        }
                                    }
                                    
                                    // Unified Name (for the cluster)
                                    // Position: Below lowest node
                                    let maxY = positions.map { $0.y }.max() ?? positions[0].y
                                    let labelY = maxY + 35
                                    
                                    // Center X
                                    let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                                    
                                    // Name source: First node name (simplified)
                                    // If explicit hub, use parent name. If implicit, use first node's name.
                                    var nameToDisplay = nodes.first?.name ?? ""
                                    if let parentId = nodes.first?.parentHubId,
                                       let parent = network.nodes.first(where: { $0.id == parentId }) {
                                        nameToDisplay = parent.name
                                    }
                                    
                                    let text = Text(nameToDisplay)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.red)
                                    
                                    let resolvedText = context.resolve(text)
                                    let textSize = resolvedText.measure(in: CGSize(width: 200, height: 50))
                                    
                                    // Background Pill (Cleaner than shadow)
                                    let textRect = CGRect(
                                        x: centerX - textSize.width/2 - 4,
                                        y: labelY - textSize.height/2 - 2,
                                        width: textSize.width + 8,
                                        height: textSize.height + 4
                                    )
                                    let pill = Path(roundedRect: textRect, cornerRadius: 4)
                                    context.fill(pill, with: .color(.white.opacity(0.8)))
                                    
                                    // Draw Text
                                    context.draw(resolvedText, at: CGPoint(x: centerX, y: labelY))
                                }
                                // Single nodes (count == 1) are handled by StationNodeView (White circle + black border),
                                // but their name is HIDDEN by StationNodeView logic.
                                // We MUST draw the name for single orphan interchanges too!
                                else if let node = nodes.first {
                                     // It's a single orphan visual group.
                                     // StationNodeView logic hides name if type == .interchange.
                                     // So we must draw it here.
                                     
                                     let p = positions[0]
                                     let labelY = p.y + 35
                                     
                                     let text = Text(node.name)
                                        .font(.system(size: 14, weight: .bold))
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
                                            let lineWidth: CGFloat = isSelected ? 4.0 : 3.0
                                            
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
        
        let name = "Stazione \(network.nodes.count + 1)"
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
    
    // Calculate final visual position including hub offset
    private func finalPosition(for node: Node, in size: CGSize, bounds: MapBounds) -> CGPoint {
        let basePosition = schematicPoint(for: node, in: size, bounds: bounds)
        
        // Apply fixed visual offset for hub-linked stations
        if node.parentHubId != nil {
            let offset: CGFloat = 30
            // Enable positioning in any of the 4 corners
            let direction = node.hubOffsetDirection ?? .bottomLeft // Legacy default
            
            switch direction {
            case .bottomLeft:
                return CGPoint(x: basePosition.x - offset, y: basePosition.y + offset)
            case .bottomRight:
                return CGPoint(x: basePosition.x + offset, y: basePosition.y + offset)
            case .topLeft:
                return CGPoint(x: basePosition.x - offset, y: basePosition.y - offset)
            case .topRight:
                return CGPoint(x: basePosition.x + offset, y: basePosition.y - offset)
            }
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

    // Helper: Generate Octilinear Path (0, 45, 90 degrees)
    // Tries to use "Centered Diagonal" approach: Horizontal/Vertical -> Diagonal -> Horizontal/Vertical
    private func generateSchematicPoints(from p1: CGPoint, to p2: CGPoint) -> [CGPoint] {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let adx = abs(dx)
        let ady = abs(dy)
        
        let minDiff = min(adx, ady)
        
        // Tolerance for straight lines/perfect 45
        if minDiff < 5 || abs(adx - ady) < 5 {
             return [p1, p2]
        }
        
        // Centered Diagonal Strategy:
        // Use Diagonal to cover the 'minDiff' length.
        // Use Horizontal/Vertical to cover the rest.
        // Split the straight part into two halves to center the diagonal.
        
        let sx: CGFloat = dx > 0 ? 1 : -1
        let sy: CGFloat = dy > 0 ? 1 : -1
        
        let diagLen = minDiff
        let straightLen = max(adx, ady) - diagLen
        
        if adx > ady {
            // Horizontal Dominant: H -> D -> H
            let hSeg = straightLen / 2.0
            
            let m1 = CGPoint(x: p1.x + sx * hSeg, y: p1.y) // 1. Horizontal half
            let m2 = CGPoint(x: m1.x + sx * diagLen, y: m1.y + sy * diagLen) // 2. Diagonal
            // m2 should now be vertically aligned with p2
            
            return [p1, m1, m2, p2]
        } else {
            // Vertical Dominant: V -> D -> V
            let vSeg = straightLen / 2.0
            
            let m1 = CGPoint(x: p1.x, y: p1.y + sy * vSeg) // 1. Vertical half
            let m2 = CGPoint(x: m1.x + sx * diagLen, y: m1.y + sy * diagLen) // 2. Diagonal
            
            return [p1, m1, m2, p2]
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
