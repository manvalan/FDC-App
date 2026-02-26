import SwiftUI
import Combine
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct InfrastructureCanvas: View {
    @EnvironmentObject var appState: AppState
    let mode: RailwayMapView.MapVisualizationMode
    let renderData: MapRenderData
    let totalZoom: CGFloat
    
    private let renderer = RailwayRenderer()
    
    var body: some View {
        Canvas { context, size in
            let renderingContext = RenderingContext(
                bounds: RenderingContext.MapBounds(
                    minLat: renderData.bounds.minLat,
                    maxLat: renderData.bounds.maxLat,
                    minLon: renderData.bounds.minLon,
                    maxLon: renderData.bounds.maxLon,
                    xRange: renderData.bounds.xRange,
                    yRange: renderData.bounds.yRange
                ),
                canvasSize: size,
                zoomLevel: totalZoom,
                mode: mode == .infrastructure ? .infrastructure : .schematic
            )

            // 1. Disegno Archi (Infrastruttura Fisica)
            for edge in appState.railroad.network.edges {
                guard let points = renderData.edgeGeometries[edge.id.uuidString] else { continue }
                
                // Highlight Ferrovia (Back)
                if let selectedInfraLine = appState.selectedInfraLine {
                    let nodeIds = selectedInfraLine.nodeIds
                    var isPartOfFerrovia = false
                    for i in 0..<(nodeIds.count - 1) {
                        let s1 = nodeIds[i]
                        let s2 = nodeIds[i+1]
                        if (edge.from == s1 && edge.to == s2) || (edge.from == s2 && edge.to == s1) {
                            isPartOfFerrovia = true
                            break
                        }
                    }
                    if isPartOfFerrovia {
                        let fColor = Color(hex: selectedInfraLine.color ?? "#000000") ?? .blue
                        let path = Path { p in p.move(to: points[0]); for i in 1..<points.count { p.addLine(to: points[i]) } }
                        context.stroke(path, with: .color(fColor.opacity(0.4)), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    }
                }
                
                let isSelected = !mode.isSchedulerMode && appState.selectedEdgeId == edge.id.uuidString
                let style = EdgeStyle.forTrackType(edge.trackType)
                
                renderer.drawEdge(
                    points: points,
                    trackType: edge.trackType,
                    in: context,
                    renderingContext: renderingContext,
                    style: style,
                    isSelected: isSelected
                )
            }

            // 2. Visualizzazione Hub
            for (hubId, positions) in renderData.hubGeometries {
                let parentNode = appState.railroad.network.nodes.first(where: { $0.id == hubId }) ?? appState.railroad.network.nodes.first
                let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                let maxY = positions.map { $0.y }.max() ?? positions[0].y
                
                renderer.drawHubGroup(
                    positions: positions,
                    label: parentNode?.name ?? "",
                    center: CGPoint(x: centerX, y: maxY + 35),
                    fontSize: appState.globalFontSize,
                    in: context
                )
            }
            
            // 3. Linee Commerciali
            if mode.isSchedulerMode {
                for (key, precomputedLines) in renderData.commercialLines {
                    let matchingEdge = appState.railroad.network.edges.first { edge in
                        (edge.from == key.from && edge.to == key.to) || (edge.from == key.to && edge.to == key.from)
                    }
                    guard let edge = matchingEdge,
                          let points = renderData.edgeGeometries[edge.id.uuidString] else { continue }
                    
                    let colors = precomputedLines.map { $0.color }
                    let isSelected = precomputedLines.contains { $0.isSelected }
                    
                    renderer.drawCommercialBundle(
                        points: points,
                        colors: colors,
                        isSelected: isSelected,
                        globalLineWidth: appState.globalLineWidth,
                        bundleOffsetBase: MapConstants.lineOffsetBase,
                        in: context
                    )
                }
            }
        }
        .frame(width: renderData.size.width, height: renderData.size.height)
    }
}
