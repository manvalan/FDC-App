import SwiftUI
import Combine
import MapKit

struct InfrastructureCanvas: View {
    @EnvironmentObject var appState: AppState
    let mode: MapVisualizationMode
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
                mode: mode == .scheduler ? .scheduler : .infrastructure
            )

            // 1. Disegno Archi (Infrastruttura Fisica)
            for edge in appState.railroad.network.edges {
                guard let points = renderData.edgeGeometries[edge.id.uuidString] else { continue }
                
                let isSelected = !mode.isSchedulerMode && appState.isEdgeSelected(edge.id.uuidString)
                var style = EdgeStyle.forTrackType(edge.trackType)
                if totalZoom > 4.0 {
                    style.strokeWidth *= 0.8
                }
                
                renderer.drawEdge(
                    points: points,
                    trackType: edge.trackType,
                    in: context,
                    renderingContext: renderingContext,
                    style: style,
                    isSelected: isSelected
                )
            }

            // 2. Hub (icona unificata: bordo capsula + pallini + doppia linea)
            for (hubId, positions) in renderData.hubGeometries where positions.count >= 2 {
                let parentNode = appState.railroad.network.nodes.first(where: { $0.id == hubId })
                let centerX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
                let maxY = positions.map { $0.y }.max() ?? positions[0].y

                renderer.drawHubPair(
                    classicPosition: positions[0],
                    avPosition: positions[1],
                    label: parentNode?.name ?? "",
                    center: CGPoint(x: centerX, y: maxY + 35),
                    fontSize: appState.globalFontSize,
                    zoomLevel: totalZoom,
                    in: context
                )
            }

            // 3. Disegno NODI (Stazioni, Bivi, Hub)
            for node in appState.railroad.network.nodes {
                if renderData.hiddenNodeIds.contains(node.id) { continue }
                if appState.isDraggingNode && appState.selectedNodeId == node.id { continue }
                let isSelected = appState.selectedNodeId == node.id || appState.selectedNodeIds.contains(node.id)
                guard let point = renderData.nodePositions[node.id] else { continue }

                let hubRole = renderData.hubVisualRoles[node.id] ?? .none
                let isJunction = node.type == .junction
                let baseIconSize: CGFloat = isJunction ? 1.5 : 8
                let adaptiveSize = baseIconSize + (1.8 * totalZoom)

                let vType = node.visualType ?? node.defaultVisualType
                let isCaposaldo = isSelected || vType == .filledSquare || vType == .filledStar || hubRole != .none
                var showLabel = isCaposaldo
                if !showLabel {
                    let hashVal = abs(node.id.hashValue % 100)
                    if totalZoom > 2.8 { showLabel = true }
                    else if totalZoom > 1.8 { showLabel = hashVal < 60 }
                    else if totalZoom > 1.2 { showLabel = hashVal < 20 }
                }

                let style = NodeStyle(
                    fillColor: Color(hex: node.customColor ?? node.defaultColor) ?? .black,
                    strokeColor: isSelected ? .blue : (isJunction ? .clear : .black.opacity(0.2)),
                    strokeWidth: isSelected ? 2.5 : 0.5,
                    size: adaptiveSize,
                    showLabel: showLabel,
                    isHighlighted: false,
                    isSelected: isSelected
                )
                renderer.drawNode(node, at: point, in: context, zoomLevel: totalZoom, style: style, hubRole: hubRole)
            }
            
            // 4. Linee Commerciali (Ottimizzate: niente più ricerche O(N))
            if mode.isSchedulerMode {
                for (_, precomputedLines) in renderData.commercialLines {
                    guard let firstLine = precomputedLines.first else { continue }
                    let points = firstLine.points
                    let colors = precomputedLines.map { $0.color }
                    let isBundleSelected = precomputedLines.contains { $0.line.id == appState.selectedRouteId }
                    
                    renderer.drawCommercialBundle(
                        points: points,
                        colors: colors,
                        isSelected: isBundleSelected,
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
