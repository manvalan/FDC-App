import Foundation
import SwiftUI

/// Servizio centralizzato per il rendering dell'infrastruttura ferroviaria.
///
/// Responsabilità:
/// - Rendering consistente di nodi (stazioni, junction, hub)
/// - Rendering consistente di edge (binari)
/// - Gestione stili e colori
/// - Conversione coordinate per diversi contesti (map, altimetric profile, etc)
///
/// Questo servizio segue i principi di "Code That Fits in Your Head":
/// - Single Responsibility: gestisce solo il rendering
/// - Nessuna logica di business
/// - View components riutilizzabili
/// - Supporta sia SwiftUI View che Canvas (GraphicsContext)
final class RailwayRenderer {
    
    // MARK: - Node Rendering
    
    /// Genera la vista per un nodo (decide automaticamente station/junction/hub)
    @ViewBuilder
    func renderNode(_ node: Node, context: RenderingContext, style: NodeStyle) -> some View {
        let point = toCanvasCoordinates(lat: node.latitude ?? 0, lon: node.longitude ?? 0, context: context)
        
        renderNodeIcon(node, style: style)
            .position(point)
    }
    
    /// Rendering della sola icona/rappresentazione visuale di un nodo
    @ViewBuilder
    func renderNodeIcon(_ node: Node, style: NodeStyle) -> some View {
        ZStack {
            if node.type == .junction {
                // Junction: small and subtle
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: style.size * 0.4, height: style.size * 0.4)
            } else if node.type == .interchange {
                // Interchange style: target-like icon
                ZStack {
                    Circle().stroke(Color.gray, lineWidth: 1).frame(width: style.size, height: style.size)
                    Circle().fill(Color.white).frame(width: style.size * 0.8, height: style.size * 0.8)
                    Circle().fill(style.fillColor).frame(width: style.size * 0.4, height: style.size * 0.4)
                }
            } else {
                // Standard station
                let visualType = node.visualType ?? node.defaultVisualType
                ZStack {
                    Circle().fill(Color.white).frame(width: style.size * 1.1, height: style.size * 1.1)
                    symbolView(type: visualType, color: style.fillColor)
                        .frame(width: style.size * 1.1, height: style.size * 1.1)
                }
            }
        }
    }
    
    @ViewBuilder
    private func symbolView(type: Node.StationVisualType, color: Color) -> some View {
        let size: CGFloat = 22 // Base size for SwiftUI Image
        switch type {
        case .filledSquare:
            Image(systemName: "square.fill").font(.system(size: size)).foregroundColor(color)
        case .emptySquare:
            Image(systemName: "square").font(.system(size: size, weight: .bold)).foregroundColor(color)
        case .filledCircle:
            Image(systemName: "circle.fill").font(.system(size: size)).foregroundColor(color)
        case .emptyCircle:
            Image(systemName: "circle").font(.system(size: size, weight: .bold)).foregroundColor(color)
        case .filledStar:
            Image(systemName: "star.fill").font(.system(size: size)).foregroundColor(color)
        }
    }
    
    /// Rendering specifico per stazioni
    @ViewBuilder
    func renderStation(_ node: Node, context: RenderingContext, style: StationStyle) -> some View {
        let point = toCanvasCoordinates(lat: node.latitude ?? 0, lon: node.longitude ?? 0, context: context)
        
        VStack(spacing: 2) {
            // Station shape
            Group {
                switch style.shape {
                case .circle:
                    Circle()
                        .fill(style.base.fillColor)
                        .frame(width: style.base.size, height: style.base.size)
                        .overlay(Circle().stroke(style.base.strokeColor, lineWidth: style.base.strokeWidth))
                case .square:
                    Rectangle()
                        .fill(style.base.fillColor)
                        .frame(width: style.base.size, height: style.base.size)
                        .overlay(Rectangle().stroke(style.base.strokeColor, lineWidth: style.base.strokeWidth))
                case .diamond:
                    DiamondShape()
                        .fill(style.base.fillColor)
                        .frame(width: style.base.size, height: style.base.size)
                        .overlay(DiamondShape().stroke(style.base.strokeColor, lineWidth: style.base.strokeWidth))
                }
            }
            .shadow(color: style.base.isHighlighted ? Color.orange.opacity(0.5) : Color.black.opacity(0.2), radius: style.base.isHighlighted ? 4 : 2)
            
            // Label
            if style.base.showLabel && !node.name.isEmpty {
                Text(node.name)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(4)
            }
        }
        .position(point)
    }
    
    /// Rendering specifico per junction nodes
    @ViewBuilder
    func renderJunction(_ node: Node, context: RenderingContext, style: JunctionStyle) -> some View {
        let point = toCanvasCoordinates(lat: node.latitude ?? 0, lon: node.longitude ?? 0, context: context)
        
        Circle()
            .fill(style.base.fillColor)
            .frame(width: style.base.size, height: style.base.size)
            .overlay(Circle().stroke(style.base.strokeColor, lineWidth: style.base.strokeWidth))
            .position(point)
    }
    
    /// Rendering specifico per hub/interscambi
    @ViewBuilder
    func renderHub(_ node: Node, context: RenderingContext, style: HubStyle) -> some View {
        let point = toCanvasCoordinates(lat: node.latitude ?? 0, lon: node.longitude ?? 0, context: context)
        
        VStack(spacing: 2) {
            // Hub shape (diamond)
            DiamondShape()
                .fill(style.base.fillColor)
                .frame(width: style.base.size, height: style.base.size)
                .overlay(
                    DiamondShape()
                        .stroke(style.base.strokeColor, lineWidth: style.base.strokeWidth)
                )
                .shadow(color: .black.opacity(0.3), radius: 3)
            
            // Label
            if style.base.showLabel && !node.name.isEmpty {
                Text(node.name)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(6)
                    .shadow(radius: 2)
            }
        }
        .position(point)
    }
    
    // MARK: - Edge Rendering
    
    @ViewBuilder
    func renderEdge(points: [CGPoint], style: EdgeStyle) -> some View {
        createSmoothPath(points: points)
            .stroke(style.strokeColor, style: StrokeStyle(
                lineWidth: style.strokeWidth,
                lineCap: .round,
                lineJoin: .round,
                dash: style.lineStyle.dashPattern ?? []
            ))
    }
    
    // MARK: - Disegno su Canvas (GraphicsContext)
    
    func drawNode(_ node: Node, at point: CGPoint, in context: GraphicsContext, zoomLevel: CGFloat, style: NodeStyle, hubRole: HubTopology.HubVisualRole = .none) {
        if hubRole != .none {
            if style.isSelected {
                let selectRadius: CGFloat = (zoomLevel > 4.0 ? 10 : 12) * 1.4
                let selectRect = CGRect(x: point.x - selectRadius / 2, y: point.y - selectRadius / 2, width: selectRadius, height: selectRadius)
                context.stroke(Path(ellipseIn: selectRect), with: .color(.blue), lineWidth: 2)
            }
            return
        }
        if node.type == .interchange {
            drawHubStationDot(at: point, in: context, zoomLevel: zoomLevel, isSelected: style.isSelected)
        } else {
            // Nodi standard: Icona basata su VisualType
            let rect = CGRect(x: point.x - style.size/2, y: point.y - style.size/2, width: style.size, height: style.size)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
            
            let visualType = node.visualType ?? node.defaultVisualType
            let symbolName = symbolSystemName(for: visualType)
            let symbolSize = style.size * 1.0 // Più grandi
            let symbol = context.resolve(Text(Image(systemName: symbolName)).font(.system(size: symbolSize, weight: .black)).foregroundColor(style.fillColor))
            context.draw(symbol, at: point)
        }
        
        // Disegno etichetta (SE consentito dalla LoD in InfrastruttureCanvas)
        if style.showLabel && !node.name.isEmpty {
            let labelColor = style.isSelected ? Color.blue : Color.black
            let isGroupedHub = hubRole != .none

            if (!isGroupedHub && node.parentHubId == nil) || style.isSelected {
                let isCaposaldo = (node.visualType ?? node.defaultVisualType) == .filledSquare || (node.visualType ?? node.defaultVisualType) == .filledStar
                let labelFontSize = isCaposaldo ? max(12, style.size * 0.7) : max(10, style.size * 0.55)
                let fontWeight: Font.Weight = (isCaposaldo || style.isSelected) ? .black : .bold

                drawReadableText(
                    node.name,
                    at: CGPoint(x: point.x, y: point.y + style.size * 1.5),
                    size: labelFontSize,
                    weight: fontWeight,
                    color: labelColor,
                    in: context
                )
            }
        }
        
        if style.isSelected {
            let selectRadius = style.size * 1.6
            let selectRect = CGRect(x: point.x - selectRadius/2, y: point.y - selectRadius/2, width: selectRadius, height: selectRadius)
            context.stroke(Path(ellipseIn: selectRect), with: .color(.blue), lineWidth: 3)
        }
    }
    
    /// Helper per disegnare testo leggibile con "alone" di contrasto
    /// Helper per disegnare testo leggibile con "alone" di contrasto
    private func drawReadableText(_ text: String, at point: CGPoint, size: CGFloat, weight: Font.Weight, color: Color, in context: GraphicsContext) {
        let textObj = Text(text).font(.system(size: size, weight: weight)).foregroundColor(color)
        let resolved = context.resolve(textObj)
        
        // Un solo disegno con ombra (glow) bianca è molto più rapido di 8 disegni spostati
        var glowContext = context
        glowContext.addFilter(.shadow(color: .white, radius: 2.5, x: 0, y: 0))
        glowContext.draw(resolved, at: point)
    }
    
    /// Disegna un binario in un GraphicsContext
    func drawEdge(points: [CGPoint], trackType: Edge.TrackType, in context: GraphicsContext, renderingContext: RenderingContext, style: EdgeStyle, isSelected: Bool) {
        let path = createSmoothPath(points: points)
        
        switch trackType {
        case .highSpeed:
            context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round))
            context.stroke(path, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: style.strokeWidth * 0.4, lineCap: .round, dash: [3, 3]))
            
        case .regional:
            context.stroke(path, with: .color(.blue.opacity(0.6)), style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round))
            
        case .single:
            context.stroke(path, with: .color(.gray.opacity(0.6)), style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round))
        }
        
        if isSelected {
            context.stroke(path, with: .color(Color.accentColor.opacity(0.4)), style: StrokeStyle(lineWidth: style.strokeWidth + 4, lineCap: .round))
            context.stroke(path, with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
    
    /// Disegna un bundle di linee commerciali
    func drawCommercialBundle(points: [CGPoint], colors: [Color], isSelected: Bool, globalLineWidth: CGFloat, bundleOffsetBase: CGFloat, in context: GraphicsContext) {
        let bundleSize = colors.count
        guard bundleSize > 0 else { return }
        
        for j in 0..<(points.count - 1) {
            let sp1 = points[j]; let sp2 = points[j+1]
            let angle = atan2(sp2.y - sp1.y, sp2.x - sp1.x)
            
            if bundleSize > 3 {
                // Style: Single path with gradient indicators for large bundles
                let path = Path { p in p.move(to: sp1); p.addLine(to: sp2) }
                context.stroke(path, with: .color(colors.first ?? .gray), style: StrokeStyle(lineWidth: globalLineWidth * 1.8, lineCap: .round))
                
                // Diamond indicator
                let mid = CGPoint(x: (sp1.x + sp2.x)/2, y: (sp1.y + sp2.y)/2)
                drawDiamond(at: mid, size: 6, in: context, color: .white, strokeColor: .gray.opacity(0.5))
            } else {
                for (i, color) in colors.enumerated() {
                    let offset = CGFloat(i) * bundleOffsetBase - (CGFloat(bundleSize - 1) * bundleOffsetBase / 2.0)
                    let lp1 = CGPoint(x: sp1.x - sin(angle) * offset, y: sp1.y + cos(angle) * offset)
                    let lp2 = CGPoint(x: sp2.x - sin(angle) * offset, y: sp2.y + cos(angle) * offset)
                    
                    let path = Path { p in p.move(to: lp1); p.addLine(to: lp2) }
                    let width = isSelected ? globalLineWidth * 1.5 : globalLineWidth
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
        }
    }
    
    /// Disegna un treno
    func drawTrain(position: CGPoint, name: String, color: Color, isSelected: Bool, fontSize: CGFloat, in context: GraphicsContext) {
        let rect = CGRect(x: position.x - 10, y: position.y - 10, width: 20, height: 20)
        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(color))
        context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white), lineWidth: 2)
        
        if isSelected {
            context.stroke(Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 6), with: .color(.blue), lineWidth: 2)
        }
        
        let label = context.resolve(Text(name).font(.system(size: fontSize, weight: .bold)).foregroundColor(.black))
        context.draw(label, at: CGPoint(x: position.x, y: position.y - 20))
    }
    
    /// Pallino rosso hub (stazione classica o AV).
    private func drawHubStationDot(at point: CGPoint, in context: GraphicsContext, zoomLevel: CGFloat, isSelected: Bool) {
        let dotSize: CGFloat = zoomLevel > 4.0 ? 10 : 12
        let rect = CGRect(x: point.x - dotSize / 2, y: point.y - dotSize / 2, width: dotSize, height: dotSize)
        context.fill(Path(ellipseIn: rect), with: .color(.white))
        context.stroke(Path(ellipseIn: rect), with: .color(.red), lineWidth: 3.5)
        if isSelected {
            let selectRect = rect.insetBy(dx: -4, dy: -4)
            context.stroke(Path(ellipseIn: selectRect), with: .color(.blue), lineWidth: 2)
        }
    }

    /// Icona hub: due pallini pieni, doppia fascia, bordo capsula fluido.
    func drawHubPair(
        classicPosition: CGPoint,
        avPosition: CGPoint,
        label: String,
        center: CGPoint,
        fontSize: CGFloat,
        zoomLevel: CGFloat,
        in context: GraphicsContext
    ) {
        let dx = avPosition.x - classicPosition.x
        let dy = avPosition.y - classicPosition.y
        let dist = hypot(dx, dy)
        let metrics = hubIconMetrics(zoomLevel: zoomLevel, centerDistance: max(dist, 1))
        let hubColor = Color(red: 0.92, green: 0.28, blue: 0.22)

        // 1. Alone bianco per il gap, poi contenuto pieno
        let borderPath = hubSmoothBorderPath(
            classicPosition: classicPosition,
            avPosition: avPosition,
            metrics: metrics
        )
        context.stroke(
            borderPath,
            with: .color(.white),
            style: StrokeStyle(lineWidth: metrics.borderWidth + metrics.shellGap * 2, lineCap: .round, lineJoin: .round)
        )

        context.fill(
            Path(ellipseIn: CGRect(
                x: classicPosition.x - metrics.dotRadius, y: classicPosition.y - metrics.dotRadius,
                width: metrics.dotRadius * 2, height: metrics.dotRadius * 2
            )),
            with: .color(hubColor)
        )
        context.fill(
            Path(ellipseIn: CGRect(
                x: avPosition.x - metrics.dotRadius, y: avPosition.y - metrics.dotRadius,
                width: metrics.dotRadius * 2, height: metrics.dotRadius * 2
            )),
            with: .color(hubColor)
        )

        if dist > 1 {
            let ux = dx / dist
            let uy = dy / dist
            let nx = -uy
            let ny = ux
            let trim = metrics.dotRadius * 0.75
            let start = CGPoint(x: classicPosition.x + ux * trim, y: classicPosition.y + uy * trim)
            let end = CGPoint(x: avPosition.x - ux * trim, y: avPosition.y - uy * trim)

            context.fill(
                hubBandQuad(from: start, to: end, normal: CGPoint(x: nx, y: ny), offset: metrics.lineOffset, halfThickness: metrics.bandHalf),
                with: .color(hubColor)
            )
            context.fill(
                hubBandQuad(from: start, to: end, normal: CGPoint(x: nx, y: ny), offset: -metrics.lineOffset, halfThickness: metrics.bandHalf),
                with: .color(hubColor)
            )
        }

        // 2. Bordo capsula sopra il riempimento
        context.stroke(
            borderPath,
            with: .color(hubColor),
            style: StrokeStyle(lineWidth: metrics.borderWidth, lineCap: .round, lineJoin: .round)
        )

        let adaptiveFontSize = zoomLevel > 4.0 ? fontSize * 0.85 : fontSize
        let text = context.resolve(Text(label).font(.system(size: adaptiveFontSize, weight: .black)).foregroundColor(.black))
        let sz = text.measure(in: CGSize(width: 400, height: 100))
        let bgRect = CGRect(x: center.x - sz.width / 2 - 4, y: center.y - sz.height / 2 - 2, width: sz.width + 8, height: sz.height + 4)
        context.fill(Path(roundedRect: bgRect, cornerRadius: 4), with: .color(.white.opacity(0.85)))
        context.draw(text, at: center)
    }

    private struct HubIconMetrics {
        let dotRadius: CGFloat
        let lineOffset: CGFloat
        let bandHalf: CGFloat
        let shellGap: CGFloat
        let borderWidth: CGFloat
    }

    private func hubIconMetrics(zoomLevel: CGFloat, centerDistance: CGFloat) -> HubIconMetrics {
        let scale: CGFloat = zoomLevel > 4.0 ? 0.9 : 1.0
        let dotRadius = min(10 * scale, max(4.5 * scale, centerDistance * 0.42))
        let sizeScale = dotRadius / (10 * scale)
        return HubIconMetrics(
            dotRadius: dotRadius,
            lineOffset: 5 * scale * sizeScale,
            bandHalf: 2.5 * scale * sizeScale,
            shellGap: 3.5 * scale * sizeScale,
            borderWidth: 3 * scale * sizeScale
        )
    }

    /// Contorno chiuso: due archi lunghi esterni sui pallini + due raccordi paralleli.
    private func hubSmoothBorderPath(
        classicPosition p1: CGPoint,
        avPosition p2: CGPoint,
        metrics: HubIconMetrics
    ) -> Path {
        let ringRadius = metrics.dotRadius + metrics.shellGap + metrics.borderWidth / 2
        let outerOff = metrics.lineOffset + metrics.bandHalf + metrics.shellGap + metrics.borderWidth / 2

        var path = Path()
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let dist = hypot(dx, dy)

        if dist < 1 {
            path.addEllipse(in: CGRect(x: p1.x - ringRadius, y: p1.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2))
            return path
        }

        let ux = dx / dist
        let uy = dy / dist
        let nx = -uy
        let ny = ux

        let sinPhi = min(outerOff / ringRadius, 0.95)
        let cosPhi = sqrt(max(0, 1 - sinPhi * sinPhi))

        func ringPoint(center: CGPoint, along: CGFloat, across: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + ringRadius * (along * ux + across * nx),
                y: center.y + ringRadius * (along * uy + across * ny)
            )
        }

        let p1Top = ringPoint(center: p1, along: cosPhi, across: sinPhi)
        let p1Bottom = ringPoint(center: p1, along: cosPhi, across: -sinPhi)
        let p2Top = ringPoint(center: p2, along: -cosPhi, across: sinPhi)
        let p2Bottom = ringPoint(center: p2, along: -cosPhi, across: -sinPhi)

        path.move(to: p1Top)
        path.addLine(to: p2Top)
        appendExteriorArc(on: &path, center: p2, from: p2Top, to: p2Bottom, awayFrom: p1)
        path.addLine(to: p1Bottom)
        appendExteriorArc(on: &path, center: p1, from: p1Bottom, to: p1Top, awayFrom: p2)
        path.closeSubpath()
        return path
    }

    /// Arco esterno tra due tangenti sullo stesso cerchio (quello più lontano dall'altro pallino).
    private func appendExteriorArc(
        on path: inout Path,
        center: CGPoint,
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        awayFrom other: CGPoint
    ) {
        let radius = hypot(startPoint.x - center.x, startPoint.y - center.y)
        let start = Double(atan2(startPoint.y - center.y, startPoint.x - center.x))
        let end = Double(atan2(endPoint.y - center.y, endPoint.x - center.x))

        func midpoint(clockwise: Bool) -> CGPoint {
            var span = end - start
            if clockwise {
                if span > 0 { span -= 2 * Double.pi }
            } else if span < 0 {
                span += 2 * Double.pi
            }
            let mid = start + span / 2
            return CGPoint(
                x: center.x + radius * CGFloat(cos(mid)),
                y: center.y + radius * CGFloat(sin(mid))
            )
        }

        let midCW = midpoint(clockwise: true)
        let midCCW = midpoint(clockwise: false)
        let distCW = hypot(midCW.x - other.x, midCW.y - other.y)
        let distCCW = hypot(midCCW.x - other.x, midCCW.y - other.y)
        let clockwise = distCW > distCCW

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .radians(start),
            endAngle: .radians(end),
            clockwise: clockwise
        )
    }

    private func hubBandQuad(from start: CGPoint, to end: CGPoint, normal: CGPoint, offset: CGFloat, halfThickness: CGFloat) -> Path {
        let o = CGPoint(x: normal.x * offset, y: normal.y * offset)
        let t = CGPoint(x: normal.x * halfThickness, y: normal.y * halfThickness)
        let a = CGPoint(x: start.x + o.x - t.x, y: start.y + o.y - t.y)
        let b = CGPoint(x: end.x + o.x - t.x, y: end.y + o.y - t.y)
        let c = CGPoint(x: end.x + o.x + t.x, y: end.y + o.y + t.y)
        let d = CGPoint(x: start.x + o.x + t.x, y: start.y + o.y + t.y)
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
    }

    /// Compatibilità snapshot: accetta due posizioni ordinate [classica, AV].
    func drawHubGroup(positions: [CGPoint], label: String, center: CGPoint, fontSize: CGFloat, zoomLevel: CGFloat, in context: GraphicsContext) {
        guard positions.count >= 2 else { return }
        drawHubPair(
            classicPosition: positions[0],
            avPosition: positions[1],
            label: label,
            center: center,
            fontSize: fontSize,
            zoomLevel: zoomLevel,
            in: context
        )
    }

    // MARK: - Path Helpers
    
    private func createSmoothPath(points: [CGPoint]) -> Path {
        guard points.count > 1 else { return Path() }
        return Path { path in
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
        }
    }
    
    private func drawDiamond(at point: CGPoint, size: CGFloat, in context: GraphicsContext, color: Color, strokeColor: Color) {
        let diamondPath = Path { p in
            p.move(to: CGPoint(x: point.x, y: point.y - size))
            p.addLine(to: CGPoint(x: point.x + size, y: point.y))
            p.addLine(to: CGPoint(x: point.x, y: point.y + size))
            p.addLine(to: CGPoint(x: point.x - size, y: point.y))
            p.closeSubpath()
        }
        context.fill(diamondPath, with: .color(color))
        context.stroke(diamondPath, with: .color(strokeColor), lineWidth: 1)
    }
    
    private func symbolSystemName(for type: Node.StationVisualType) -> String {
        return Self.symbolSystemNameStatic(for: type)
    }
    
    static func symbolSystemNameStatic(for type: Node.StationVisualType) -> String {
        switch type {
        case .filledSquare: return "square.fill"
        case .emptySquare: return "square"
        case .filledCircle: return "circle.fill"
        case .emptyCircle: return "circle"
        case .filledStar: return "star.fill"
        }
    }
    
    func renderPath(from fromNode: Node, to toNode: Node, via junctions: [Node], context: RenderingContext) -> Path {
        var path = Path()
        
        var points: [CGPoint] = []
        
        // Start point
        points.append(toCanvasCoordinates(lat: fromNode.latitude ?? 0, lon: fromNode.longitude ?? 0, context: context))
        
        // Junction points
        for junction in junctions {
            points.append(toCanvasCoordinates(lat: junction.latitude ?? 0, lon: junction.longitude ?? 0, context: context))
        }
        
        // End point
        points.append(toCanvasCoordinates(lat: toNode.latitude ?? 0, lon: toNode.longitude ?? 0, context: context))
        
        // Draw path
        if !points.isEmpty {
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
        }
        
        return path
    }
    
    // MARK: - Complex Rendering
    
    /// Rendering profilo altimetrico per una lista di punti
    @ViewBuilder
    func renderAltimetricProfile(
        points: [AltitudePoint],
        in geometry: GeometryProxy,
        style: AltitudeProfileStyle,
        pixelsPerKm: CGFloat,
        minAltitude: Double,
        altitudeRange: Double
    ) -> some View {
        ZStack(alignment: .topLeading) {
            // Grid background
            if style.showGrid {
                gridBackground(in: geometry, style: style)
            }
            
            // Altitude line
            altitudeLine(points: points, in: geometry, style: style, pixelsPerKm: pixelsPerKm, minAltitude: minAltitude, altitudeRange: altitudeRange)
            
            // Station and junction markers
            ForEach(points) { point in
                self.altitudePointMarker(
                    point: point,
                    in: geometry,
                    pixelsPerKm: pixelsPerKm,
                    minAltitude: minAltitude,
                    altitudeRange: altitudeRange
                )
            }
        }
    }
    
    // MARK: - Conversione Coordinate
    
    /// Converte coordinate geografiche (lat/lon) in coordinate canvas
    func toCanvasCoordinates(lat: Double, lon: Double, context: RenderingContext) -> CGPoint {
        let bounds = context.bounds
        let size = context.canvasSize
        
        let normalizedX = (lon - bounds.minLon) / bounds.xRange
        let normalizedY = 1.0 - ((lat - bounds.minLat) / bounds.yRange)  // Inverted Y
        
        let x = CGFloat(normalizedX) * size.width
        let y = CGFloat(normalizedY) * size.height
        
        return CGPoint(x: x, y: y)
    }
    
    /// Converte distanza chilometrica in pixel (per profilo altimetrico)
    func distanceToPixels(_ distance: Double, pixelsPerKm: CGFloat) -> CGFloat {
        return CGFloat(distance) * pixelsPerKm
    }
    
    /// Converte altitudine in coordinata Y (per profilo altimetrico)
    func altitudeToY(_ altitude: Double, geoHeight: CGFloat, minAltitude: Double, altitudeRange: Double) -> CGFloat {
        let normalizedAlt = CGFloat(altitude - minAltitude) / CGFloat(altitudeRange)
        return geoHeight - (normalizedAlt * geoHeight * 0.8) - (geoHeight * 0.1)
    }
    
    // MARK: - Private Helpers
    
    @ViewBuilder
    private func gridBackground(in geometry: GeometryProxy, style: AltitudeProfileStyle) -> some View {
        Path { path in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Horizontal grid lines
            for i in 0...10 {
                let y = height * CGFloat(i) / 10.0
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            
            // Vertical grid lines
            for i in 0...20 {
                let x = width * CGFloat(i) / 20.0
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
        }
        .stroke(style.gridColor, lineWidth: 1)
    }
    
    @ViewBuilder
    private func altitudeLine(
        points: [AltitudePoint],
        in geometry: GeometryProxy,
        style: AltitudeProfileStyle,
        pixelsPerKm: CGFloat,
        minAltitude: Double,
        altitudeRange: Double
    ) -> some View {
        if points.count >= 2 {
            Path { path in
                let firstPoint = points[0]
                let firstX = 50 + distanceToPixels(firstPoint.distance, pixelsPerKm: pixelsPerKm)
                let firstY = altitudeToY(firstPoint.altitude, geoHeight: geometry.size.height, minAltitude: minAltitude, altitudeRange: altitudeRange)
                
                path.move(to: CGPoint(x: firstX, y: firstY))
                
                for point in points.dropFirst() {
                    let x = 50 + distanceToPixels(point.distance, pixelsPerKm: pixelsPerKm)
                    let y = altitudeToY(point.altitude, geoHeight: geometry.size.height, minAltitude: minAltitude, altitudeRange: altitudeRange)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(style.lineColor, lineWidth: style.lineWidth)
        }
    }
    
    @ViewBuilder
    private func altitudePointMarker(
        point: AltitudePoint,
        in geometry: GeometryProxy,
        pixelsPerKm: CGFloat,
        minAltitude: Double,
        altitudeRange: Double
    ) -> some View {
        let x = 50 + distanceToPixels(point.distance, pixelsPerKm: pixelsPerKm)
        let y = altitudeToY(point.altitude, geoHeight: geometry.size.height, minAltitude: minAltitude, altitudeRange: altitudeRange)
        
        if point.isStation {
            // Station marker (larger white circle)
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                .position(x: x, y: y)
        } else {
            // Junction marker (small black circle)
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                .position(x: x, y: y)
        }
    }
}

// MARK: - Supporting Shapes

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.midY)
        
        path.move(to: top)
        path.addLine(to: right)
        path.addLine(to: bottom)
        path.addLine(to: left)
        path.closeSubpath()
        
        return path
    }
}
