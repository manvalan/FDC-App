// MARK: - Extracted Map Views (Self-contained for performance)

struct InfrastructureCanvas: View {
    @ObservedObject var network: RailwayNetwork
    @ObservedObject var appState: AppState
    let mode: RailwayMapView.MapVisualizationMode
    let selectedLine: RailwayLine?
    let selectedEdgeId: String?
    let hiddenLineIds: Set<String>
    let bounds: SchematicRailwayView.MapBounds
    let size: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Pre-calculate all node positions
            var allNodePoints: [String: CGPoint] = [:]
            for node in network.nodes {
                allNodePoints[node.id] = MapGeometry.finalPosition(for: node, in: size, bounds: bounds, network: network)
            }
            
            // Structure for neighbor lookup
            var nodeNeighbors: [String: Set<String>] = [:]
            for edge in network.edges {
                nodeNeighbors[edge.from, default: []].insert(edge.to)
                nodeNeighbors[edge.to, default: []].insert(edge.from)
            }
            
            // Helper struct for segment mapping
            struct SegmentKey: Hashable {
                let from: String; let to: String
                init(_ a: String, _ b: String) { if a < b { from = a; to = b } else { from = b; to = a } }
            }
            var segmentLineMap: [SegmentKey: [RailwayLine]] = [:]
            for line in network.lines {
                if hiddenLineIds.contains(line.id) { continue }
                for i in 0..<(line.stations.count - 1) {
                    let key = SegmentKey(line.stations[i], line.stations[i+1])
                    segmentLineMap[key, default: []].append(line)
                }
            }
            
            // 1. Draw Edges
            var drawnKeys = Set<String>()
            for edge in network.edges {
                let key = edge.canonicalKey
                if drawnKeys.contains(key) { continue }
                drawnKeys.insert(key)
                
                guard let p1 = allNodePoints[edge.from], let p2 = allNodePoints[edge.to] else { continue }
                let avoid = allNodePoints.values.filter { $0 != p1 && $0 != p2 }
                let nPosStart = (nodeNeighbors[edge.from]?.filter { $0 != edge.to } ?? []).compactMap { allNodePoints[$0] }
                let nPosEnd = (nodeNeighbors[edge.to]?.filter { $0 != edge.from } ?? []).compactMap { allNodePoints[$0] }
                
                let points = MapGeometry.generateSchematicPoints(from: p1, to: p2, avoidPoints: Array(avoid), neighborsStart: nPosStart, neighborsEnd: nPosEnd)
                let path = Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                
                let effectiveType = edge.trackType
                var lineWidth: CGFloat = 1.0
                if effectiveType == .highSpeed {
                    lineWidth = appState.trackWidthHighSpeed
                    context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
                    context.stroke(path, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth * 0.4, lineCap: .round, dash: [3, 3]))
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
                
                if mode == .network && selectedEdgeId == edge.id.uuidString {
                    context.stroke(path, with: .color(.blue.opacity(0.5)), style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round))
                }
            }

            // Hubs
            let hubNodes = network.nodes.filter { node in
                node.parentHubId != nil || network.nodes.contains(where: { $0.parentHubId == node.id })
            }
            var hubGroups: [String: [Node]] = [:]
            for node in hubNodes {
                let hubId = node.parentHubId ?? node.id
                hubGroups[hubId, default: []].append(node)
            }
            for (hubId, nodes) in hubGroups {
                if nodes.count > 1 {
                    let positions = nodes.map { MapGeometry.finalPosition(for: $0, in: size, bounds: bounds, network: network) }
                    for i in 0..<nodes.count {
                        for j in (i+1)..<nodes.count {
                            let hPath = Path { p in p.move(to: positions[i]); p.addLine(to: positions[j]) }
                            context.stroke(hPath, with: .color(.red), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                            context.stroke(hPath, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        }
                    }
                    let maxY = positions.map { $0.y }.max() ?? positions[0].y
                    let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                    let parentNode = nodes.first(where: { $0.id == hubId }) ?? nodes.first
                    MapDrawing.drawNodeLabel(context: context, text: parentNode?.name ?? "", at: CGPoint(x: centerX, y: maxY + 35), color: .red, fontSize: appState.globalFontSize)
                }
            }
            
            // Line Labels for orphan interchanges
            let orphanInterchanges = network.nodes.filter { node in
                node.type == .interchange && hubGroups[node.parentHubId ?? node.id]?.count ?? 0 <= 1
            }
            for node in orphanInterchanges {
                let p = MapGeometry.finalPosition(for: node, in: size, bounds: bounds, network: network)
                MapDrawing.drawNodeLabel(context: context, text: node.name, at: CGPoint(x: p.x, y: p.y + 35), color: .red, fontSize: appState.globalFontSize)
            }

            // Commercial Lines Overlay
            if mode == .lines {
                for (key, lines) in segmentLineMap {
                    guard let n1 = network.nodes.first(where: { $0.id == key.from }),
                          let n2 = network.nodes.first(where: { $0.id == key.to }) else { continue }
                    let p1 = allNodePoints[n1.id]!; let p2 = allNodePoints[n2.id]!
                    let points = MapGeometry.generateSchematicPoints(from: p1, to: p2)
                    for j in 0..<(points.count - 1) {
                        let sp1 = points[j]; let sp2 = points[j+1]
                        let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
                        let offsetBase: CGFloat = 4.0
                        for (i, line) in lines.enumerated() {
                            let offset = CGFloat(i) * offsetBase - (CGFloat(lines.count - 1) * offsetBase / 2.0)
                            let lp1 = CGPoint(x: sp1.x - sin(angle) * offset, y: sp1.y + cos(angle) * offset)
                            let lp2 = CGPoint(x: sp2.x - sin(angle) * offset, y: sp2.y + cos(angle) * offset)
                            let path = Path { p in p.move(to: lp1); p.addLine(to: lp2) }
                            let isSelected = (line.id == selectedLine?.id)
                            let lineWidth = isSelected ? appState.globalLineWidth * 1.5 : appState.globalLineWidth
                            context.stroke(path, with: .color(Color(hex: line.color ?? "#000000") ?? .black), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        }
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

struct TrainOverlayCanvas: View {
    @ObservedObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    let bounds: SchematicRailwayView.MapBounds
    let canvasSize: CGSize
    let totalZoom: CGFloat
    
    var body: some View {
        TimelineView(.animation) { timelineContext in
            Canvas { context, size in
                let now = timelineContext.date.normalized()
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
    @ObservedObject var network: RailwayNetwork
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
                node: $network.nodes[index],
                network: network,
                canvasSize: canvasSize,
                isSelected: selectedNode?.id == network.nodes[index].id,
                snapToGrid: showGrid,
                gridUnit: coordinateGridStep,
                bounds: bounds,
                onTap: { onTap(network.nodes[index]) },
                isMoveModeEnabled: $isMoveModeEnabled,
                onDragStarted: { network.createCheckpoint() }
            )
            .position(MapGeometry.finalPosition(for: network.nodes[index], in: canvasSize, bounds: bounds, network: network))
            .id("node-\(network.nodes[index].id)")
        }
    }
}

struct MapGeometry {
    static func schematicPoint(for node: Node, in size: CGSize, bounds: SchematicRailwayView.MapBounds) -> CGPoint {
        let lon = node.longitude ?? 0; let lat = node.latitude ?? 0
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - 100) + 50
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - 100) + 50
        return CGPoint(x: x, y: y)
    }
    
    static func finalPosition(for node: Node, in size: CGSize, bounds: SchematicRailwayView.MapBounds, network: RailwayNetwork) -> CGPoint {
        if let parentId = node.parentHubId, let parent = network.nodes.first(where: { $0.id == parentId }) {
            let pPos = schematicPoint(for: parent, in: size, bounds: bounds)
            let offset: CGFloat = 25.0
            let direction = node.hubOffsetDirection ?? .bottomRight
            switch direction {
            case .topLeft: return CGPoint(x: pPos.x - offset, y: pPos.y - offset)
            case .topRight: return CGPoint(x: pPos.x + offset, y: pPos.y - offset)
            case .bottomLeft: return CGPoint(x: pPos.x - offset, y: pPos.y + offset)
            case .bottomRight: return CGPoint(x: pPos.x + offset, y: pPos.y + offset)
            }
        }
        return schematicPoint(for: node, in: size, bounds: bounds)
    }
    
    static func generateSchematicPoints(from p1: CGPoint, to p2: CGPoint, avoidPoints: [CGPoint] = [], neighborsStart: [CGPoint] = [], neighborsEnd: [CGPoint] = []) -> [CGPoint] {
        let candidates = generateSchematicCandidates(from: p1, to: p2)
        if avoidPoints.isEmpty && neighborsStart.isEmpty && neighborsEnd.isEmpty { return candidates.first?.points ?? [p1, p2] }
        var best: (points: [CGPoint], cost: Double)? = nil
        for cand in candidates {
            let cost = calculatePathCost(path: cand.points, avoid: avoidPoints, neighborsStart: neighborsStart, neighborsEnd: neighborsEnd)
            if cost == 0 { return cand.points }
            if best == nil || cost < best!.cost { best = (cand.points, cost) }
        }
        return best?.points ?? [p1, p2]
    }
    
    private struct SchematicCandidate { let points: [CGPoint]; let type: String }
    
    private static func generateSchematicCandidates(from p1: CGPoint, to p2: CGPoint) -> [SchematicCandidate] {
        var cands: [SchematicCandidate] = []
        let dx = p2.x - p1.x; let dy = p2.y - p1.y
        let adx = abs(dx); let ady = abs(dy)
        let minD = min(adx, ady); let sx: CGFloat = dx > 0 ? 1 : -1; let sy: CGFloat = dy > 0 ? 1 : -1
        if minD < 5 || abs(adx - ady) < 5 { return [SchematicCandidate(points: [p1, p2], type: "Direct")] }
        let diag = minD; let str = max(adx, ady) - diag
        if adx > ady {
            let h = str / 2.0; let m1 = CGPoint(x: p1.x + sx * h, y: p1.y); let m2 = CGPoint(x: m1.x + sx * diag, y: m1.y + sy * diag)
            cands.append(SchematicCandidate(points: [p1, m1, m2, p2], type: "Centered"))
            cands.append(SchematicCandidate(points: [p1, CGPoint(x: p1.x + sx * str, y: p1.y), p2], type: "Late"))
            cands.append(SchematicCandidate(points: [p1, CGPoint(x: p1.x + sx * diag, y: p1.y + sy * diag), p2], type: "Early"))
        } else {
            let v = str / 2.0; let m1 = CGPoint(x: p1.x, y: p1.y + sy * v); let m2 = CGPoint(x: m1.x + sx * diag, y: m1.y + sy * diag)
            cands.append(SchematicCandidate(points: [p1, m1, m2, p2], type: "Centered"))
            cands.append(SchematicCandidate(points: [p1, CGPoint(x: p1.x, y: p1.y + sy * str), p2], type: "Late"))
            cands.append(SchematicCandidate(points: [p1, CGPoint(x: p1.x + sx * diag, y: p1.y + sy * diag), p2], type: "Early"))
        }
        cands.append(SchematicCandidate(points: [p1, CGPoint(x: p2.x, y: p1.y), p2], type: "L-HV"))
        cands.append(SchematicCandidate(points: [p1, CGPoint(x: p1.x, y: p2.y), p2], type: "L-VH"))
        return cands
    }
    
    private static func calculatePathCost(path: [CGPoint], avoid: [CGPoint], neighborsStart: [CGPoint], neighborsEnd: [CGPoint]) -> Double {
        var cost: Double = 0
        for i in 0..<path.count-1 {
            for p in avoid { if distanceToSegment(p, path[i], path[i+1]) < 25 { cost += 500 } }
        }
        if path.count > 1 {
            let vS = normalize(vector: CGPoint(x: path[1].x-path[0].x, y: path[1].y-path[0].y))
            for n in neighborsStart { if (vS.x*normalize(vector: CGPoint(x: n.x-path[0].x, y: n.y-path[0].y)).x + vS.y*normalize(vector: CGPoint(x: n.y-path[0].y)).y) > -0.01 { cost += 500 } }
            let last = path.last!; let prev = path[path.count-2]
            let vE = normalize(vector: CGPoint(x: prev.x-last.x, y: prev.y-last.y))
            for n in neighborsEnd { if (vE.x*normalize(vector: CGPoint(x: n.x-last.x, y: n.y-last.y)).x + vE.y*normalize(vector: CGPoint(x: n.y-last.y)).y) > -0.01 { cost += 500 } }
        }
        return cost
    }
    
    private static func normalize(vector: CGPoint) -> CGPoint {
        let l = hypot(vector.x, vector.y); return l > 0 ? CGPoint(x: vector.x/l, y: vector.y/l) : CGPoint(x: 1, y: 0)
    }
    
    private static func distanceToSegment(_ p: CGPoint, _ v: CGPoint, _ w: CGPoint) -> CGFloat {
        let l2 = (v.x-w.x)*(v.x-w.x)+(v.y-w.y)*(v.y-w.y); if l2 == 0 { return hypot(p.x-v.x, p.y-v.y) }
        var t = ((p.x-v.x)*(w.x-v.x)+(p.y-v.y)*(w.y-v.y))/l2; t = max(0, min(1, t))
        return hypot(p.x-(v.x+t*(w.x-v.x)), p.y-(v.y+t*(w.y-v.y)))
    }
    
    static func currentSchematicTrainPos(for schedule: TrainSchedule, in size: CGSize, now: Date, bounds: SchematicRailwayView.MapBounds, network: RailwayNetwork) -> CGPoint? {
        for i in 0..<(schedule.stops.count - 1) {
            let s1 = schedule.stops[i]; let s2 = schedule.stops[i+1]
            guard let d1 = s1.departureTime, let a2 = s2.arrivalTime else { continue }
            if now >= d1 && now <= a2 {
                let duration = a2.timeIntervalSince(d1); let elapsed = now.timeIntervalSince(d1)
                let progress = duration > 0 ? elapsed / duration : 0.0
                guard let n1 = network.nodes.first(where: { $0.id == s1.stationId }),
                      let n2 = network.nodes.first(where: { $0.id == s2.stationId }) else { return nil }
                let p1 = schematicPoint(for: n1, in: size, bounds: bounds); let p2 = schematicPoint(for: n2, in: size, bounds: bounds)
                let points = generateSchematicPoints(from: p1, to: p2)
                var totalLen: CGFloat = 0; var segmentLens: [CGFloat] = []
                for j in 0..<(points.count - 1) {
                    let d = hypot(points[j+1].x-points[j].x, points[j+1].y-points[j].y); totalLen += d; segmentLens.append(d)
                }
                if totalLen == 0 { return p1 }
                let targetDist = totalLen * CGFloat(progress); var currentDist: CGFloat = 0
                for j in 0..<(points.count - 1) {
                    let sl = segmentLens[j]
                    if currentDist + sl >= targetDist {
                        let lp = (targetDist - currentDist) / (sl > 0 ? sl : 1)
                        return CGPoint(x: points[j].x + (points[j+1].x - points[j].x) * lp, y: points[j].y + (points[j+1].y - points[j].y) * lp)
                    }
                    currentDist += sl
                }
                return points.last
            }
        }
        return nil
    }
}

struct MapDrawing {
    static func drawNodeLabel(context: GraphicsContext, text: String, at: CGPoint, color: Color, fontSize: CGFloat) {
        let textObj = Text(text).font(.system(size: fontSize, weight: .bold)).foregroundColor(color)
        let resolved = context.resolve(textObj)
        let sz = resolved.measure(in: CGSize(width: 200, height: 50))
        let rect = CGRect(x: at.x-sz.width/2-4, y: at.y-sz.height/2-2, width: sz.width+8, height: sz.height+4)
        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white.opacity(0.8)))
        context.draw(resolved, at: at)
    }
}
