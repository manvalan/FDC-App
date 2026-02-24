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
        
        var nodePositions: [String: CGPoint] = [:]
        for node in network.nodes {
            nodePositions[node.id] = finalPosition(for: node, in: size, bounds: bounds, network: network)
        }
        
        var nodeNeighbors: [String: Set<String>] = [:]
        for edge in network.edges {
            nodeNeighbors[edge.from, default: []].insert(edge.to)
            nodeNeighbors[edge.to, default: []].insert(edge.from)
        }
        
        // Group edges by station pairs to handle parallel tracks
        var edgesByPair: [String: [RailwayEdge]] = [:]
        for edge in network.edges {
            let key = edge.canonicalKey
            edgesByPair[key, default: []].append(edge)
        }
        
        var edgeGeometries: [String: [CGPoint]] = [:]
        for (canonicalKey, edges) in edgesByPair {
            guard let firstEdge = edges.first else { continue }
            guard let p1 = nodePositions[firstEdge.from], let p2 = nodePositions[firstEdge.to] else { continue }
            
            let avoid = nodePositions.values.filter { $0 != p1 && $0 != p2 }
            let nPosStart = (nodeNeighbors[firstEdge.from]?.filter { $0 != firstEdge.to } ?? []).compactMap { nodePositions[$0] }
            let nPosEnd = (nodeNeighbors[firstEdge.to]?.filter { $0 != firstEdge.from } ?? []).compactMap { nodePositions[$0] }
            
            // Check if the first edge has custom geometry points
            let basePoints: [CGPoint]
            if let customPoints = firstEdge.geometryPoints, !customPoints.isEmpty {
                // Use custom geometry points if defined
                var points: [CGPoint] = [p1]
                for gp in customPoints {
                    let x = (gp.longitude - bounds.minLon) / bounds.xRange * (size.width - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
                    let y = (1.0 - (gp.latitude - bounds.minLat) / bounds.yRange) * (size.height - MapConstants.canvasPadding * 2) + MapConstants.canvasPadding
                    points.append(CGPoint(x: x, y: y))
                }
                points.append(p2)
                basePoints = points
            } else {
                // Generate automatic schematic path
                basePoints = generateSchematicPoints(from: p1, to: p2, avoidPoints: Array(avoid), neighborsStart: nPosStart, neighborsEnd: nPosEnd)
            }
            
            // Calculate perpendicular offset for parallel tracks
            let trackCount = edges.count
            if trackCount == 1 {
                // Single track - no offset needed
                edgeGeometries[edges[0].id.uuidString] = basePoints
            } else if trackCount > 4 {
                // INNOVATIVE SOLUTION: For busy junctions (>4 lines), use compact bundling
                // Instead of spreading tracks infinitely, group them in a tight bundle
                // This is inspired by Apple Maps' approach to complex transit networks
                let maxSpread: CGFloat = 28.0  // Maximum total width for the bundle
                let offsetDistance: CGFloat = maxSpread / CGFloat(trackCount - 1)
                
                for (index, edge) in edges.enumerated() {
                    // Calculate offset: centered around the base path
                    let offset = (CGFloat(index) - CGFloat(trackCount - 1) / 2.0) * offsetDistance
                    
                    // Apply perpendicular offset to each point
                    var offsetPoints: [CGPoint] = []
                    for i in 0..<basePoints.count {
                        let p = basePoints[i]
                        
                        // Calculate perpendicular direction
                        var perpX: CGFloat = 0
                        var perpY: CGFloat = 0
                        
                        if i == 0 && basePoints.count > 1 {
                            // First point: use direction to next point
                            let next = basePoints[i + 1]
                            let dx = next.x - p.x
                            let dy = next.y - p.y
                            let len = sqrt(dx * dx + dy * dy)
                            if len > 0 {
                                perpX = -dy / len
                                perpY = dx / len
                            }
                        } else if i == basePoints.count - 1 && basePoints.count > 1 {
                            // Last point: use direction from previous point
                            let prev = basePoints[i - 1]
                            let dx = p.x - prev.x
                            let dy = p.y - prev.y
                            let len = sqrt(dx * dx + dy * dy)
                            if len > 0 {
                                perpX = -dy / len
                                perpY = dx / len
                            }
                        } else if basePoints.count > 2 {
                            // Middle points: average of directions
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
                        
                        // Apply offset
                        let offsetPoint = CGPoint(
                            x: p.x + perpX * offset,
                            y: p.y + perpY * offset
                        )
                        offsetPoints.append(offsetPoint)
                    }
                    
                    edgeGeometries[edge.id.uuidString] = offsetPoints
                }
            } else {
                // For 2-4 lines, use normal spacing
                let baseOffset: CGFloat = 8.0
                let offsetDistance: CGFloat = baseOffset
                
                for (index, edge) in edges.enumerated() {
                    // Calculate offset: centered around the base path
                    let offset = (CGFloat(index) - CGFloat(trackCount - 1) / 2.0) * offsetDistance
                    
                    // Apply perpendicular offset to each point
                    var offsetPoints: [CGPoint] = []
                    for i in 0..<basePoints.count {
                        let p = basePoints[i]
                        
                        // Calculate perpendicular direction
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
                        
                        // Apply offset
                        let offsetPoint = CGPoint(
                            x: p.x + perpX * offset,
                            y: p.y + perpY * offset
                        )
                        offsetPoints.append(offsetPoint)
                    }
                    
                    edgeGeometries[edge.id.uuidString] = offsetPoints
                }
            }
        }
        
        // First pass: collect lines by segment to determine bundle sizes
        var segmentLines: [SegmentKey: [(line: RailwayLine, color: Color, isSelected: Bool)]] = [:]
        for line in lines.lines {
            if hiddenLineIds.contains(line.id) { continue }
            guard line.stations.count >= 2 else { continue }
            for i in 0..<(line.stations.count - 1) {
                let key = SegmentKey(line.stations[i], line.stations[i+1])
                let color = Color(hex: line.color ?? "#000000") ?? .black
                let isSelected = line.id == selectedLine?.id
                segmentLines[key, default: []].append((line, color, isSelected))
            }
        }
        
        // Second pass: create PrecomputedLine with bundleSize
        var commercialLines: [SegmentKey: [MapRenderData.PrecomputedLine]] = [:]
        for (key, linesOnSegment) in segmentLines {
            let bundleSize = linesOnSegment.count
            for item in linesOnSegment {
                let precomputed = MapRenderData.PrecomputedLine(
                    line: item.line,
                    color: item.color,
                    isSelected: item.isSelected,
                    bundleSize: bundleSize
                )
                commercialLines[key, default: []].append(precomputed)
            }
        }
        
        // Calcolo Hubs
        var hubGeometries: [String: [CGPoint]] = [:]
        let hubNodes = network.nodes.filter { node in
            node.parentHubId != nil || network.nodes.contains(where: { $0.parentHubId == node.id })
        }
        var hubGroups: [String: [RailwayNode]] = [:]
        for node in hubNodes {
            let hubId = node.parentHubId ?? node.id
            hubGroups[hubId, default: []].append(node)
        }
        for (hubId, nodes) in hubGroups where nodes.count > 1 {
            hubGeometries[hubId] = nodes.map { nodePositions[$0.id] ?? .zero }
        }
        
        return MapRenderData(
            size: size,
            bounds: bounds,
            nodePositions: nodePositions,
            edgeGeometries: edgeGeometries,
            hubGeometries: hubGeometries,
            commercialLines: commercialLines
        )
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
