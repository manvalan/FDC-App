import SwiftUI

/// Motore geometrico per la mappa ferroviaria (Query Layer).
/// Gestisce il calcolo delle coordinate e delle generazioni dei tracciati schematici.
struct MapGeometryEngine {
    
    /// Trasforma coordinate geografiche in punti vista (Canvas).
    static func schematicPoint(for node: RailwayNode, in size: CGSize, bounds: MapBounds) -> CGPoint {
        let lon = node.longitude ?? 0; let lat = node.latitude ?? 0
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        return CGPoint(x: x, y: y)
    }
    
    /// Calcola la posizione finale di un nodo, considerando gli offset dei Hub.
    static func finalPosition(for node: RailwayNode, in size: CGSize, bounds: MapBounds, network: NetworkModel) -> CGPoint {
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
        let l2 = (v.x-w.x)*(v.x-w.x)+(v.y-w.y)*(v.y-w.y)
        if l2 == 0 { return hypot(p.x-v.x, p.y-v.y) }
        var t = ((p.x-v.x)*(w.x-v.x)+(p.y-v.y)*(w.y-v.y))/l2
        t = max(0, min(1, t))
        return hypot(p.x-(v.x+t*(w.x-v.x)), p.y-(v.y+t*(w.y-v.y)))
    }
    
    /// Calcola la posizione attuale di un treno usando i dati pre-calcolati.
    static func currentTrainPos(for schedule: TrainSchedule, in renderData: MapRenderData, now: Date, network: NetworkModel) -> CGPoint? {
        guard schedule.stops.count >= 2 else { return nil }
        for i in 0..<(schedule.stops.count - 1) {
            let s1 = schedule.stops[i]; let s2 = schedule.stops[i+1]
            guard let d1 = s1.departureTime, let a2 = s2.arrivalTime else { continue }
            if now >= d1 && now <= a2 {
                let duration = a2.timeIntervalSince(d1); let elapsed = now.timeIntervalSince(d1)
                let progress = duration > 0 ? elapsed / duration : 0.0
                
                let key = SegmentKey(s1.stationId, s2.stationId)
                // We identify the edge geometries by segment key for consistency
                guard let points = renderData.edgeGeometries.first(where: { k, v in 
                    let ek = network.edges.first(where: { $0.id.uuidString == k })?.canonicalKey
                    return ek == key.from + "-" + key.to || ek == key.to + "-" + key.from
                })?.value else {
                    return nil
                }
                
                var totalLen: CGFloat = 0; var segmentLens: [CGFloat] = []
                for j in 0..<(points.count - 1) {
                    let d = hypot(points[j+1].x-points[j].x, points[j+1].y-points[j].y); totalLen += d; segmentLens.append(d)
                }
                if totalLen == 0 { return points.first }
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

    /// Calcola i MapBounds in base ai nodi della rete
    static func calculateBounds(nodes: [RailwayNode]) -> MapBounds {
        let lats = nodes.compactMap { $0.latitude }
        let lons = nodes.compactMap { $0.longitude }
        let minLat = lats.min() ?? 38.0
        let maxLat = lats.max() ?? 48.0
        let minLon = lons.min() ?? 7.0
        let maxLon = lons.max() ?? 19.0
        let xr = maxLon - minLon
        let yr = maxLat - minLat
        let padX = xr == 0 ? 0.5 : xr * 0.1
        let padY = yr == 0 ? 0.5 : yr * 0.1
        return MapBounds(
            minLat: minLat - padY, 
            maxLat: maxLat + padY, 
            minLon: minLon - padX, 
            maxLon: maxLon + padX, 
            xRange: xr + 2 * padX, 
            yRange: yr + 2 * padY
        )
    }

    /// Pre-calcola tutti i dati necessari per il rendering di un frame della mappa.
    static func generateRenderData(
        network: NetworkModel,
        lines: LinesManager,
        size: CGSize,
        bounds: MapBounds,
        hiddenLineIds: Set<String>
    ) -> MapRenderData {
        let nodePositions = calculateNodePositions(network: network, size: size, bounds: bounds)
        let nodeNeighbors = buildNodeNeighbors(network: network)
        let edgesByPair = groupEdgesByPair(network: network)
        let edgeGeometries = buildEdgeGeometries(
            edgesByPair: edgesByPair, nodePositions: nodePositions,
            nodeNeighbors: nodeNeighbors, size: size, bounds: bounds)
        let commercialLines = buildCommercialLineIndex(
            edgesByPair: edgesByPair, nodePositions: nodePositions,
            nodeNeighbors: nodeNeighbors, lines: lines,
            hiddenLineIds: hiddenLineIds, size: size, bounds: bounds)
        let hubGeometries = calculateHubGeometries(network: network, nodePositions: nodePositions)
        let selectionIndex = buildSelectionIndex(nodePositions: nodePositions, edgeGeometries: edgeGeometries)
        return MapRenderData(
            size: size, bounds: bounds, nodePositions: nodePositions,
            edgeGeometries: edgeGeometries, hubGeometries: hubGeometries,
            commercialLines: commercialLines, selectionIndex: selectionIndex)
    }

    /// Calcola la geometria (punti canvas con offset) per ogni edge fisico.
    private static func buildEdgeGeometries(
        edgesByPair: [String: [RailwayEdge]],
        nodePositions: [String: CGPoint],
        nodeNeighbors: [String: Set<String>],
        size: CGSize,
        bounds: MapBounds
    ) -> [String: [CGPoint]] {
        var geometries: [String: [CGPoint]] = [:]
        for (_, edges) in edgesByPair {
            guard let first = edges.first,
                  let p1 = nodePositions[first.from],
                  let p2 = nodePositions[first.to] else { continue }
            let avoid = nodePositions.values.filter { $0 != p1 && $0 != p2 }
            let nStart = (nodeNeighbors[first.from]?.filter { $0 != first.to } ?? []).compactMap { nodePositions[$0] }
            let nEnd = (nodeNeighbors[first.to]?.filter { $0 != first.from } ?? []).compactMap { nodePositions[$0] }
            let base = getBasePoints(for: first, from: p1, to: p2, avoid: avoid,
                                     nPosStart: nStart, nPosEnd: nEnd, size: size, bounds: bounds)
            let trackCount = edges.count
            let offsetDist: CGFloat = trackCount > 4 ? (28.0 / CGFloat(trackCount - 1)) : 8.0
            for (index, edge) in edges.enumerated() {
                let offset = trackCount == 1 ? 0 : (CGFloat(index) - CGFloat(trackCount - 1) / 2.0) * offsetDist
                geometries[edge.id.uuidString] = offsetPoints(base, offset: offset)
            }
        }
        return geometries
    }

    /// Costruisce l'indice delle linee commerciali per segmento (per il rendering sovrapposto).
    private static func buildCommercialLineIndex(
        edgesByPair: [String: [RailwayEdge]],
        nodePositions: [String: CGPoint],
        nodeNeighbors: [String: Set<String>],
        lines: LinesManager,
        hiddenLineIds: Set<String>,
        size: CGSize,
        bounds: MapBounds
    ) -> [SegmentKey: [MapRenderData.PrecomputedLine]] {
        var index: [SegmentKey: [MapRenderData.PrecomputedLine]] = [:]
        for (_, edges) in edgesByPair {
            guard let first = edges.first,
                  let p1 = nodePositions[first.from],
                  let p2 = nodePositions[first.to] else { continue }
            let segmentKey = SegmentKey(first.from, first.to)
            let avoid = nodePositions.values.filter { $0 != p1 && $0 != p2 }
            let nStart = (nodeNeighbors[first.from]?.filter { $0 != first.to } ?? []).compactMap { nodePositions[$0] }
            let nEnd = (nodeNeighbors[first.to]?.filter { $0 != first.from } ?? []).compactMap { nodePositions[$0] }
            let base = getBasePoints(for: first, from: p1, to: p2, avoid: avoid,
                                     nPosStart: nStart, nPosEnd: nEnd, size: size, bounds: bounds)
            let precomputed = precomputedLines(for: segmentKey, basePoints: base,
                                               lines: lines, hiddenLineIds: hiddenLineIds)
            if !precomputed.isEmpty { index[segmentKey] = precomputed }
        }
        return index
    }

    /// Query pura: filtra le linee commerciali che passano per un segmento e le pre-renderizza.
    private static func precomputedLines(
        for key: SegmentKey,
        basePoints: [CGPoint],
        lines: LinesManager,
        hiddenLineIds: Set<String>
    ) -> [MapRenderData.PrecomputedLine] {
        let matching = lines.lines.filter { line in
            guard !hiddenLineIds.contains(line.id), line.stationIds.count >= 2 else { return false }
            return (0..<(line.stationIds.count - 1)).contains { i in
                (line.stationIds[i] == key.from && line.stationIds[i+1] == key.to) ||
                (line.stationIds[i] == key.to   && line.stationIds[i+1] == key.from)
            }
        }
        return matching.map { line in
            MapRenderData.PrecomputedLine(
                line: line,
                color: Color(hex: line.color ?? "#000000") ?? .black,
                bundleSize: matching.count,
                points: basePoints)
        }
    }

    private static func calculateNodePositions(network: NetworkModel, size: CGSize, bounds: MapBounds) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        for node in network.nodes {
            positions[node.id] = finalPosition(for: node, in: size, bounds: bounds, network: network)
        }
        return positions
    }

    private static func buildNodeNeighbors(network: NetworkModel) -> [String: Set<String>] {
        var neighbors: [String: Set<String>] = [:]
        for edge in network.edges {
            neighbors[edge.from, default: []].insert(edge.to)
            neighbors[edge.to, default: []].insert(edge.from)
        }
        return neighbors
    }

    private static func groupEdgesByPair(network: NetworkModel) -> [String: [RailwayEdge]] {
        var grouped: [String: [RailwayEdge]] = [:]
        for edge in network.edges {
            grouped[edge.canonicalKey, default: []].append(edge)
        }
        return grouped
    }

    private static func getBasePoints(for edge: RailwayEdge, from p1: CGPoint, to p2: CGPoint, avoid: [CGPoint], nPosStart: [CGPoint], nPosEnd: [CGPoint], size: CGSize, bounds: MapBounds) -> [CGPoint] {
        if !edge.controlPoints.isEmpty {
            var points: [CGPoint] = [p1]
            for cp in edge.controlPoints {
                points.append(toCanvasCoords(lat: cp.latitude, lon: cp.longitude, size: size, bounds: bounds))
            }
            points.append(p2); return points
        }
        return generateSchematicPoints(from: p1, to: p2, avoidPoints: avoid, neighborsStart: nPosStart, neighborsEnd: nPosEnd)
    }

    private static func toCanvasCoords(lat: Double, lon: Double, size: CGSize, bounds: MapBounds) -> CGPoint {
        let x = (lon - bounds.minLon) / bounds.xRange * (size.width - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * (size.height - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
        return CGPoint(x: x, y: y)
    }

    private static func offsetPoints(_ points: [CGPoint], offset: CGFloat) -> [CGPoint] {
        if offset == 0 { return points }
        var result: [CGPoint] = []
        for i in 0..<points.count {
            let perp = calculatePerpendicularAt(i, in: points)
            result.append(CGPoint(x: points[i].x + perp.x * offset, y: points[i].y + perp.y * offset))
        }
        return result
    }

    private static func calculatePerpendicularAt(_ i: Int, in points: [CGPoint]) -> CGPoint {
        guard points.count >= 2 else { return .zero }
        if i == 0 { return perpendicularBetween(points[0], points[1]) }
        if i == points.count - 1 { return perpendicularBetween(points[i-1], points[i]) }
        let p1 = perpendicularBetween(points[i-1], points[i])
        let p2 = perpendicularBetween(points[i], points[i+1])
        let avg = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        let len = hypot(avg.x, avg.y)
        return len > 0 ? CGPoint(x: avg.x / len, y: avg.y / len) : p1
    }

    private static func perpendicularBetween(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        let dx = p2.x - p1.x; let dy = p2.y - p1.y; let len = hypot(dx, dy)
        return len > 0 ? CGPoint(x: -dy / len, y: dx / len) : .zero
    }

    private static func calculateHubGeometries(network: NetworkModel, nodePositions: [String: CGPoint]) -> [String: [CGPoint]] {
        var hubGroups: [String: [RailwayNode]] = [:]
        for node in network.nodes {
            if let hid = node.parentHubId ?? (network.nodes.contains(where: { $0.parentHubId == node.id }) ? node.id : nil) {
                hubGroups[hid, default: []].append(node)
            }
        }
        var geometries: [String: [CGPoint]] = [:]
        for (hubId, nodes) in hubGroups where nodes.count > 1 {
            geometries[hubId] = nodes.map { nodePositions[$0.id] ?? .zero }
        }
        return geometries
    }

    private static func buildSelectionIndex(nodePositions: [String: CGPoint], edgeGeometries: [String: [CGPoint]]) -> [MapRenderData.HitTarget] {
        var index: [MapRenderData.HitTarget] = []
        let nodeThreshold: CGFloat = 25.0
        let edgeThreshold: CGFloat = 20.0
        for (id, pos) in nodePositions {
            let rect = CGRect(x: pos.x - nodeThreshold, y: pos.y - nodeThreshold, width: nodeThreshold * 2, height: nodeThreshold * 2)
            index.append(MapRenderData.HitTarget(id: id, type: .node, bounds: rect, center: pos, points: nil))
        }
        for (id, points) in edgeGeometries {
            guard !points.isEmpty else { continue }
            let minX = points.map { $0.x }.min() ?? 0; let maxX = points.map { $0.x }.max() ?? 0
            let minY = points.map { $0.y }.min() ?? 0; let maxY = points.map { $0.y }.max() ?? 0
            let rect = CGRect(x: minX - edgeThreshold, y: minY - edgeThreshold, width: (maxX - minX) + edgeThreshold * 2, height: (maxY - minY) + edgeThreshold * 2)
            index.append(MapRenderData.HitTarget(id: id, type: .edge, bounds: rect, center: nil, points: points))
        }
        return index
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
