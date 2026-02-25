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
                // Junction simple representation
                Circle()
                    .fill(Color.black)
                    .frame(width: style.size * 0.4, height: style.size * 0.4)
                    .shadow(color: .white.opacity(0.8), radius: 1)
            } else if node.type == .interchange {
                // Interchange style
                ZStack {
                    Circle().fill(Color.white).frame(width: style.size, height: style.size)
                    Circle().stroke(Color.red, lineWidth: style.size * 0.3).frame(width: style.size, height: style.size)
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
    
    /// Disegna un nodo in un GraphicsContext (per Canvas o ImageRenderer)
    func drawNode(_ node: Node, in context: GraphicsContext, renderingContext: RenderingContext, style: NodeStyle) {
        let point = toCanvasCoordinates(lat: node.latitude ?? 0, lon: node.longitude ?? 0, context: renderingContext)
        
        if node.type == .interchange {
            // Draw Hub style
            let rect = CGRect(x: point.x - style.size/2, y: point.y - style.size/2, width: style.size, height: style.size)
            context.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(.white))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(.red), lineWidth: 5)
        } else {
            // Draw Regular Node
            let rect = CGRect(x: point.x - style.size/2, y: point.y - style.size/2, width: style.size, height: style.size)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
            
            // Draw symbol
            let visualType = node.visualType ?? node.defaultVisualType
            let symbolName = symbolSystemName(for: visualType)
            let symbol = context.resolve(Text(Image(systemName: symbolName)).font(.system(size: style.size, weight: .bold)).foregroundColor(style.fillColor))
            context.draw(symbol, at: point)
            
            // Draw Label
            if style.showLabel && !node.name.isEmpty && node.parentHubId == nil {
                let label = context.resolve(Text(node.name).font(.system(size: style.size * 1.2, weight: .black)).foregroundColor(.black))
                context.draw(label, at: CGPoint(x: point.x, y: point.y + style.size * 1.8))
            }
        }
        
        if style.isSelected {
            let selectRect = CGRect(x: point.x - style.size, y: point.y - style.size, width: style.size * 2, height: style.size * 2)
            context.stroke(Path(ellipseIn: selectRect), with: .color(.blue), lineWidth: 2)
        }
    }
    
    /// Disegna un binario in un GraphicsContext
    func drawEdge(points: [CGPoint], trackType: Edge.TrackType, in context: GraphicsContext, renderingContext: RenderingContext, style: EdgeStyle, isSelected: Bool) {
        let path = createSmoothPath(points: points)
        
        switch trackType {
        case .highSpeed:
            context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round))
            context.stroke(path, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: style.strokeWidth * 0.4, lineCap: .round, dash: [3, 3]))
            
        case .double:
            context.stroke(path, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round))
            context.stroke(path, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: style.strokeWidth - 1.5, lineCap: .round))
            context.stroke(path, with: .color(.black.opacity(0.9)), style: StrokeStyle(lineWidth: style.strokeWidth * 0.23, lineCap: .round))
            
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
    
    /// Disegna un gruppo di hub
    func drawHubGroup(positions: [CGPoint], label: String, center: CGPoint, fontSize: CGFloat, in context: GraphicsContext) {
        for i in 0..<positions.count {
            for j in (i+1)..<positions.count {
                let path = Path { p in p.move(to: positions[i]); p.addLine(to: positions[j]) }
                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            }
        }
        
        // Draw group label
        let text = context.resolve(Text(label).font(.system(size: fontSize, weight: .bold)).foregroundColor(.red))
        let sz = text.measure(in: CGSize(width: 400, height: 100))
        let bgRect = CGRect(x: center.x - sz.width/2 - 4, y: center.y - sz.height/2 - 2, width: sz.width + 8, height: sz.height + 4)
        context.fill(Path(roundedRect: bgRect, cornerRadius: 4), with: .color(.white.opacity(0.8)))
        context.draw(text, at: center)
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
