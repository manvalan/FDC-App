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
final class RailwayRenderer {
    
    // MARK: - Node Rendering
    
    /// Genera la vista per un nodo (decide automaticamente station/junction/hub)
    @ViewBuilder
    func renderNode(_ node: Node, context: RenderingContext, style: NodeStyle) -> some View {
        switch node.type {
        case .station:
            renderStation(node, context: context, style: StationStyle(base: style, shape: .circle, showTracks: false))
        case .junction:
            renderJunction(node, context: context, style: JunctionStyle(base: style, showInProfile: true))
        case .interchange:
            renderHub(node, context: context, style: HubStyle(base: style, showConnectionLines: false))
        }
    }
    
    /// Rendering specifico per stazioni
    @ViewBuilder
    func renderStation(_ node: Node, context: RenderingContext, style: StationStyle) -> some View {
        let point = toCanvasCoordinates(lat: node.latitude ?? 0, lon: node.longitude ?? 0, context: context)
        
        VStack(spacing: 2) {
            // Station shape
            shapeForStation(style.shape)
                .fill(style.base.fillColor)
                .frame(width: style.base.size, height: style.base.size)
                .overlay(
                    shapeForStation(style.shape)
                        .stroke(style.base.strokeColor, lineWidth: style.base.strokeWidth)
                )
                .shadow(color: style.base.isHighlighted ? .orange.opacity(0.5) : .black.opacity(0.2), radius: style.base.isHighlighted ? 4 : 2)
            
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
            diamondShape()
                .fill(style.base.fillColor)
                .frame(width: style.base.size, height: style.base.size)
                .overlay(
                    diamondShape()
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
    
    /// Genera la vista per un edge/binario
    @ViewBuilder
    func renderEdge(_ edge: Edge, fromNode: Node, toNode: Node, context: RenderingContext, style: EdgeStyle) -> some View {
        let fromPoint = toCanvasCoordinates(lat: fromNode.latitude ?? 0, lon: fromNode.longitude ?? 0, context: context)
        let toPoint = toCanvasCoordinates(lat: toNode.latitude ?? 0, lon: toNode.longitude ?? 0, context: context)
        
        Path { path in
            path.move(to: fromPoint)
            path.addLine(to: toPoint)
        }
        .stroke(style.strokeColor, style: StrokeStyle(
            lineWidth: style.strokeWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: style.lineStyle.dashPattern ?? []
        ))
    }
    
    /// Genera percorso tra due nodi (gestisce junction intermedi)
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
                altitudePointMarker(
                    point: point,
                    in: geometry,
                    pixelsPerKm: pixelsPerKm,
                    minAltitude: minAltitude,
                    altitudeRange: altitudeRange
                )
            }
        }
    }
    
    // MARK: - Coordinate Conversion
    
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
    private func shapeForStation(_ shape: StationStyle.StationShape) -> some Shape {
        switch shape {
        case .circle:
            Circle()
        case .square:
            Rectangle()
        case .diamond:
            diamondShape()
        }
    }
    
    private func diamondShape() -> some Shape {
        DiamondShape()
    }
    
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
