import SwiftUI

struct MapMainLayersView: View {
    @EnvironmentObject var appState: AppState
    let mode: RailwayMapView.MapVisualizationMode
    let renderData: MapRenderData
    let bounds: MapBounds
    let size: CGSize
    let totalZoom: CGFloat
    let coordinateGridStep: Double
    let showGrid: Bool
    var onStationTap: (RailwayNode, CGPoint) -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            InfrastructureCanvas(
                mode: mode,
                renderData: renderData,
                totalZoom: totalZoom
            )
            .allowsHitTesting(false)
            
            if !appState.simulator.schedules.isEmpty && mode.isSchedulerMode {
                TrainOverlayCanvas(renderData: renderData, canvasSize: size, totalZoom: totalZoom)
                    .allowsHitTesting(false)
            }
            
            StationMarkersView(
                selectedNode: .constant(nil), // Handled by AppState
                selectedLine: .constant(nil),
                selectedEdgeId: .constant(nil),
                renderData: renderData,
                canvasSize: size,
                bounds: bounds,
                showGrid: showGrid,
                coordinateGridStep: coordinateGridStep,
                onTap: onStationTap
            )
        }
        .frame(width: renderData.size.width, height: renderData.size.height)
    }
}
