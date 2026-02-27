import SwiftUI
import Combine
import MapKit
import UniformTypeIdentifiers

struct SchematicRailwayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var interactionVM: MapInteractionViewModel
    
    // Bindings from parent
    @Binding var selectedNode: Node?
    @Binding var selectedLine: RailwayLine?
    @Binding var selectedEdgeId: String?
    @Binding var showGrid: Bool
    @Binding var highlightedConflictLocation: String?
    var mode: RailwayMapView.MapVisualizationMode
    var onExport: (RailwayMapView.ExportFormat) -> Void
    var onPrint: () -> Void

    // Local State
    @State private var zoomLevel: CGFloat = 1.0
    @State private var magnification: Double = 1.0
    @State private var editMode: MapEditMode = .explore
    @State private var isEditToolbarVisible = false
    @State private var hiddenLineIds: Set<String> = []
    
    // Track Creation State
    @State private var newTrackFrom: Node?
    @State private var newTrackTo: Node?
    @State private var newTrackType: RailwayEdge.TrackType = .double
    @State private var newTrackDistance: Double = 1.0
    
    init(selectedNode: Binding<Node?>, selectedLine: Binding<RailwayLine?>, selectedEdgeId: Binding<String?>,
         showGrid: Binding<Bool>, highlightedConflictLocation: Binding<String?>, mode: RailwayMapView.MapVisualizationMode,
         onExport: @escaping (RailwayMapView.ExportFormat) -> Void, onPrint: @escaping () -> Void) {
        self._selectedNode = selectedNode
        self._selectedLine = selectedLine
        self._selectedEdgeId = selectedEdgeId
        self._showGrid = showGrid
        self._highlightedConflictLocation = highlightedConflictLocation
        self.mode = mode
        self.onExport = onExport
        self.onPrint = onPrint
        
        self._interactionVM = StateObject(wrappedValue: MapInteractionViewModel())
    }

    private var totalZoom: CGFloat { zoomLevel * magnification }
    private var coordinateGridStep: Double {
        let zoom = totalZoom
        if zoom < 1.5 { return 10.0 }
        if zoom < 3.0 { return 5.0 }
        return 1.0
    }

    private var mapBounds: MapBounds {
        MapGeometryEngine.calculateBounds(nodes: appState.railroad.network.nodes)
    }

    var body: some View {
        GeometryReader { geo in
            let size = canvasSize(for: geo.size)
            let bounds = self.mapBounds
            let renderData = MapGeometryEngine.generateRenderData(
                network: appState.railroad.network,
                lines: appState.railroad.lines,
                size: size,
                bounds: bounds,
                selectedRouteId: appState.selectedRouteId,
                selectedEdgeId: selectedEdgeId,
                hiddenLineIds: hiddenLineIds
            )
            
            mainViewContainer(size: size, bounds: bounds, renderData: renderData)
        }
        .background(Color.white)
        .simultaneousGesture(zoomGesture)
        .toolbar {
            MapToolbarView(zoomLevel: Binding(get: { Double(zoomLevel) }, set: { zoomLevel = CGFloat($0) }), hiddenLineIds: $hiddenLineIds)
        }
        .onAppear {
            interactionVM.appState = appState
        }
    }

    private func canvasSize(for geoSize: CGSize) -> CGSize {
        CGSize(
            width: max(geoSize.width * totalZoom, geoSize.width),
            height: max(geoSize.height * totalZoom, geoSize.height)
        )
    }

    private func mainViewContainer(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ZStack {
            scrollViewLayer(size: size, bounds: bounds, renderData: renderData)
            
            StationPickingIndicator()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            TrackCreationOverlay(
                editMode: $editMode,
                newTrackFrom: $newTrackFrom,
                newTrackTo: $newTrackTo,
                newTrackDistance: $newTrackDistance,
                newTrackType: $newTrackType,
                onCreate: { 
                    if let from = newTrackFrom, let to = newTrackTo {
                        interactionVM.createTrack(from: from, to: to, distance: newTrackDistance, type: newTrackType) 
                    }
                }
            )
            
            MapControlsView(
                isEditToolbarVisible: $isEditToolbarVisible,
                editMode: $editMode,
                zoomLevel: $zoomLevel,
                onExport: onExport,
                onPrint: onPrint
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private func scrollViewLayer(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    mapBasement(size: size, bounds: bounds)
                    MapMainLayersView(
                        mode: mode,
                        renderData: renderData,
                        bounds: bounds,
                        size: size,
                        totalZoom: totalZoom,
                        coordinateGridStep: coordinateGridStep,
                        showGrid: showGrid,
                        onStationTap: { interactionVM.handleStationTap($0, editMode: $editMode, newTrackFrom: $newTrackFrom, newTrackTo: $newTrackTo, newTrackDistance: $newTrackDistance) }
                    )
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }

    private func mapBasement(size: CGSize, bounds: MapBounds) -> some View {
        ZStack {
            Color.white
            if showGrid {
                CoordinateGridShape(bounds: bounds, unit: coordinateGridStep, size: size)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification = $0 }
            .onEnded { value in
                zoomLevel *= value
                magnification = 1.0
            }
    }
}
