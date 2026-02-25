import SwiftUI

/// Motore geometrico per la mappa ferroviaria (Query Layer).
/// Gestisce il calcolo delle coordinate e delle generazioni dei tracciati schematici.
struct MapGeometryEngine {
    
    /// Trasforma coordinate geografiche in punti vista (Canvas).
    static func schematicPoint(for node: RailwayNode, in size: CGSize, bounds: SchematicRailwayView.MapBounds) -> CGPoint {
        let lon = node.longitude ?? 0; let lat = node.latitude ?? 0
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        return CGPoint(x: x, y: y)
    }
    
    /// Calcola la posizione finale di un nodo, considerando gli offset dei Hub.
    static func finalPosition(for node: RailwayNode, in size: CGSize, bounds: SchematicRailwayView.MapBounds, network: NetworkModel) -> CGPoint {
        if let parentId = node.parentHubId, let parent = network.nodes.first(where: { $0.id == parentId }) {
            let pPos = schematicPoint(for: parent, in: size, bounds: bounds)
            let offset: CGFloat = 25.0 // Offset fisso per chiarezza visiva nei hub
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
    
    /// Genera i punti per un tracciato schematico (angolazioni 45/90 gradi).
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
            let start = path[0]; let first = path[1]
            let vS = normalize(vector: CGPoint(x: first.x - start.x, y: first.y - start.y))
            for n in neighborsStart {
                let vN = normalize(vector: CGPoint(x: n.x - start.x, y: n.y - start.y))
                if (vS.x * vN.x + vS.y * vN.y) > -0.01 { cost += 500 }
            }
            
            let last = path.last!; let prev = path[path.count-2]
            let vE = normalize(vector: CGPoint(x: prev.x - last.x, y: prev.y - last.y))
            for n in neighborsEnd {
                let vN = normalize(vector: CGPoint(x: n.x - last.x, y: n.y - last.y))
                if (vE.x * vN.x + vE.y * vN.y) > -0.01 { cost += 500 }
            }
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
    
    /// Calcola la posizione attuale di un treno.
    static func currentSchematicTrainPos(for schedule: TrainSchedule, in size: CGSize, now: Date, bounds: SchematicRailwayView.MapBounds, network: NetworkModel) -> CGPoint? {
        guard schedule.stops.count >= 2 else { return nil }
        for i in 0..<(schedule.stops.count - 1) {
            let s1 = schedule.stops[i]; let s2 = schedule.stops[i+1]
            guard let d1 = s1.departureTime, let a2 = s2.arrivalTime else { continue }
            if now >= d1 && now <= a2 {
                let duration = a2.timeIntervalSince(d1); let elapsed = now.timeIntervalSince(d1)
                let progress = duration > 0 ? elapsed / duration : 0.0
                guard let n1 = network.nodes.first(where: { $0.id == s1.stationId }),
                      let n2 = network.nodes.first(where: { $0.id == s2.stationId }) else { return nil }
                let p1 = finalPosition(for: n1, in: size, bounds: bounds, network: network)
                let p2 = finalPosition(for: n2, in: size, bounds: bounds, network: network)
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

    /// Pre-calcola tutti i dati necessari per il rendering di un frame della mappa.
    /// Questa è la "Query" del CQS che estrae la logica dal body della View.
    static func generateRenderData(network: NetworkModel, 
                                 lines: LinesManager, 
                                 size: CGSize, 
                                 bounds: SchematicRailwayView.MapBounds, 
                                 selectedLine: RailwayLine?, 
                                 selectedEdgeId: String?, 
                                 hiddenLineIds: Set<String>) -> MapRenderData {
        
        // 1. Posizioni Nodi
        let nodePositions = calculateNodePositions(network: network, size: size, bounds: bounds)
        
        // 2. Geometrie Edge (Binari paralleli)
        let edgeGeometries = calculateEdgeGeometries(network: network, nodePositions: nodePositions, size: size, bounds: bounds)
        
        // 3. Linee Commerciali (Bundle)
        let commercialLines = calculateCommercialLines(lines: lines, hiddenLineIds: hiddenLineIds, selectedLine: selectedLine)
        
        // 4. Hubs
        let hubGeometries = calculateHubGeometries(network: network, nodePositions: nodePositions)
        
        return MapRenderData(
            size: size,
            bounds: bounds,
            nodePositions: nodePositions,
            edgeGeometries: edgeGeometries,
            hubGeometries: hubGeometries,
            commercialLines: commercialLines
        )
    }

    // MARK: - Private Extraction Methods

    /// Calcola le posizioni di tutti i nodi nella rete.
    private static func calculateNodePositions(network: NetworkModel, size: CGSize, bounds: SchematicRailwayView.MapBounds) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        for node in network.nodes {
            positions[node.id] = finalPosition(for: node, in: size, bounds: bounds, network: network)
        }
        return positions
    }

    /// Calcola le geometrie di tutti gli edge, gestendo i binari paralleli.
    private static func calculateEdgeGeometries(network: NetworkModel, 
                                              nodePositions: [String: CGPoint], 
                                              size: CGSize, 
                                              bounds: SchematicRailwayView.MapBounds) -> [String: [CGPoint]] {
        var geometries: [String: [CGPoint]] = [:]
        
        let nodeNeighbors = buildNodeNeighbors(network: network)
        let edgesByPair = groupEdgesByPair(network: network)
        
        for (_, edges) in edgesByPair {
            processEdgePair(edges, nodePositions: nodePositions, nodeNeighbors: nodeNeighbors, size: size, bounds: bounds, results: &geometries)
        }
        
        return geometries
    }

    /// Costruisce una mappa dei vicini per ogni nodo.
    private static func buildNodeNeighbors(network: NetworkModel) -> [String: Set<String>] {
        var neighbors: [String: Set<String>] = [:]
        for edge in network.edges {
            neighbors[edge.from, default: []].insert(edge.to)
            neighbors[edge.to, default: []].insert(edge.from)
        }
        return neighbors
    }

    /// Raggruppa gli edge per coppia di stazioni (chiave canonica).
    private static func groupEdgesByPair(network: NetworkModel) -> [String: [RailwayEdge]] {
        var grouped: [String: [RailwayEdge]] = [:]
        for edge in network.edges {
            grouped[edge.canonicalKey, default: []].append(edge)
        }
        return grouped
    }

    /// Elabora una coppia di edge tra due stazioni, calcolando i percorsi e gli offset.
    private static func processEdgePair(_ edges: [RailwayEdge], 
                                      nodePositions: [String: CGPoint], 
                                      nodeNeighbors: [String: Set<String>], 
                                      size: CGSize, 
                                      bounds: SchematicRailwayView.MapBounds, 
                                      results: inout [String: [CGPoint]]) {
        guard let firstEdge = edges.first,
              let p1 = nodePositions[firstEdge.from],
              let p2 = nodePositions[firstEdge.to] else { return }
        
        let avoid = nodePositions.values.filter { $0 != p1 && $0 != p2 }
        let nPosStart = (nodeNeighbors[firstEdge.from]?.filter { $0 != firstEdge.to } ?? []).compactMap { nodePositions[$0] }
        let nPosEnd = (nodeNeighbors[firstEdge.to]?.filter { $0 != firstEdge.from } ?? []).compactMap { nodePositions[$0] }
        
        let basePoints = getBasePoints(for: firstEdge, from: p1, to: p2, avoid: avoid, nPosStart: nPosStart, nPosEnd: nPosEnd, size: size, bounds: bounds)
        
        applyOffsets(for: edges, basePoints: basePoints, results: &results)
    }

    /// Ottiene i punti base per un edge (custom o schematici).
    private static func getBasePoints(for edge: RailwayEdge, 
                                    from p1: CGPoint, 
                                    to p2: CGPoint, 
                                    avoid: [CGPoint], 
                                    nPosStart: [CGPoint], 
                                    nPosEnd: [CGPoint], 
                                    size: CGSize, 
                                    bounds: SchematicRailwayView.MapBounds) -> [CGPoint] {
        if let customPoints = edge.geometryPoints, !customPoints.isEmpty {
            var points: [CGPoint] = [p1]
            for gp in customPoints {
                points.append(toCanvasCoords(lat: gp.latitude, lon: gp.longitude, size: size, bounds: bounds))
            }
            points.append(p2)
            return points
        }
        
        return generateSchematicPoints(from: p1, to: p2, avoidPoints: avoid, neighborsStart: nPosStart, neighborsEnd: nPosEnd)
    }

    /// Converte coordinate geo in punti canvas.
    private static func toCanvasCoords(lat: Double, lon: Double, size: CGSize, bounds: SchematicRailwayView.MapBounds) -> CGPoint {
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        return CGPoint(x: x, y: y)
    }

    /// Applica gli offset perpendicolari per i binari paralleli.
    private static func applyOffsets(for edges: [RailwayEdge], basePoints: [CGPoint], results: inout [String: [CGPoint]]) {
        let trackCount = edges.count
        if trackCount == 1 {
            results[edges[0].id.uuidString] = basePoints
            return
        }
        
        let offsetDistance: CGFloat = trackCount > 4 ? (28.0 / CGFloat(trackCount - 1)) : 8.0
        
        for (index, edge) in edges.enumerated() {
            let offset = (CGFloat(index) - CGFloat(trackCount - 1) / 2.0) * offsetDistance
            results[edge.id.uuidString] = offsetPoints(basePoints, offset: offset)
        }
    }

    /// Applica un offset a una serie di punti.
    private static func offsetPoints(_ points: [CGPoint], offset: CGFloat) -> [CGPoint] {
        var offsetPoints: [CGPoint] = []
        for i in 0..<points.count {
            let perp = calculatePerpendicularAt(i, in: points)
            offsetPoints.append(CGPoint(x: points[i].x + perp.x * offset, y: points[i].y + perp.y * offset))
        }
        return offsetPoints
    }

    /// Calcola la direzione perpendicolare in un punto di un tracciato.
    private static func calculatePerpendicularAt(_ i: Int, in points: [CGPoint]) -> CGPoint {
        guard points.count >= 2 else { return .zero }
        
        if i == 0 {
            return perpendicularBetween(points[0], points[1])
        } else if i == points.count - 1 {
            return perpendicularBetween(points[i-1], points[i])
        } else {
            let p1 = perpendicularBetween(points[i-1], points[i])
            let p2 = perpendicularBetween(points[i], points[i+1])
            let avg = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            let len = sqrt(avg.x * avg.x + avg.y * avg.y)
            return len > 0 ? CGPoint(x: avg.x / len, y: avg.y / len) : p1
        }
    }

    /// Calcola la perpendicolare a un segmento.
    private static func perpendicularBetween(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let len = sqrt(dx * dx + dy * dy)
        return len > 0 ? CGPoint(x: -dy / len, y: dx / len) : .zero
    }

    /// Calcola i dati per il rendering delle linee commerciali (bundle).
    private static func calculateCommercialLines(lines: LinesManager, 
                                               hiddenLineIds: Set<String>, 
                                               selectedLine: RailwayLine?) -> [SegmentKey: [MapRenderData.PrecomputedLine]] {
        var segmentLines: [SegmentKey: [(line: RailwayLine, color: Color, isSelected: Bool)]] = [:]
        for line in lines.lines {
            if hiddenLineIds.contains(line.id) || line.stations.count < 2 { continue }
            for i in 0..<(line.stations.count - 1) {
                let key = SegmentKey(line.stations[i], line.stations[i+1])
                let color = Color(hex: line.color ?? "#000000") ?? .black
                let isSelected = line.id == selectedLine?.id
                segmentLines[key, default: []].append((line, color, isSelected))
            }
        }
        
        var commercialLines: [SegmentKey: [MapRenderData.PrecomputedLine]] = [:]
        for (key, linesOnSegment) in segmentLines {
            let bundleSize = linesOnSegment.count
            commercialLines[key] = linesOnSegment.map { item in
                MapRenderData.PrecomputedLine(line: item.line, color: item.color, isSelected: item.isSelected, bundleSize: bundleSize)
            }
        }
        return commercialLines
    }

    /// Calcola le geometrie per i Hub (gruppi di stazioni vicine).
    private static func calculateHubGeometries(network: NetworkModel, nodePositions: [String: CGPoint]) -> [String: [CGPoint]] {
        var hubGroups: [String: [RailwayNode]] = [:]
        for node in network.nodes {
            let hubId = node.parentHubId ?? (network.nodes.contains(where: { $0.parentHubId == node.id }) ? node.id : nil)
            if let hid = hubId { hubGroups[hid, default: []].append(node) }
        }
        
        var geometries: [String: [CGPoint]] = [:]
        for (hubId, nodes) in hubGroups where nodes.count > 1 {
            geometries[hubId] = nodes.map { nodePositions[$0.id] ?? .zero }
        }
        return geometries
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
