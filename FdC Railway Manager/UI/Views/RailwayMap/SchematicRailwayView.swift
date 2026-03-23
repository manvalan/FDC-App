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
    var mode: MapVisualizationMode
    var onExport: (AppExportFormat) -> Void
    var onPrint: () -> Void

    // Local State
    @Binding var zoomLevel: CGFloat
    @State private var magnification: Double = 1.0
    private var editMode: MapEditMode {
        appState.mapEditMode
    }
    @State private var isEditToolbarVisible = false
    @State private var hiddenLineIds: Set<String> = []
    @State private var stationPlacementLocation: CGPoint = .zero
    var editorViewModel: EditorModeViewModel? = nil
    
    // Track Creation State
    @State private var newTrackFrom: Node?
    @State private var newTrackTo: Node?
    @State private var newTrackType: RailwayEdge.TrackType = .single
    @State private var newTrackDistance: Double = 1.0
    
    // Performance Cache
    @State private var cachedRenderData: MapRenderData?
    @State private var lastTopologyId: Int = 0
    @State private var lastSize: CGSize = .zero
    @State private var lastZoom: CGFloat = 0
    
    // Gesture state to coordinate nav vs brush
    @GestureState private var isNavigating = false
    
    private func updateRenderDataIfNeeded(size: CGSize, zoom: CGFloat) {
        let topologyId = appState.railroad.topologyId // Assume this exists or use network count/hash
        if cachedRenderData == nil || topologyId != lastTopologyId || size != lastSize || zoom != lastZoom {
            cachedRenderData = MapGeometryEngine.generateRenderData(
                network: appState.railroad.network,
                lines: appState.railroad.lines,
                size: size,
                bounds: self.mapBounds,
                hiddenLineIds: hiddenLineIds
            )
            lastTopologyId = topologyId
            lastSize = size
            lastZoom = zoom
        }
    }
    
    init(selectedNode: Binding<Node?>, selectedLine: Binding<RailwayLine?>, selectedEdgeId: Binding<String?>,
         showGrid: Binding<Bool>, highlightedConflictLocation: Binding<String?>, mode: MapVisualizationMode,
         zoomLevel: Binding<CGFloat>,
         onExport: @escaping (AppExportFormat) -> Void, onPrint: @escaping () -> Void,
         appState: AppState,
         editorViewModel: EditorModeViewModel? = nil) {
        self._selectedNode = selectedNode
        self._selectedLine = selectedLine
        self._selectedEdgeId = selectedEdgeId
        self._showGrid = showGrid
        self._highlightedConflictLocation = highlightedConflictLocation
        self.mode = mode
        self._zoomLevel = zoomLevel
        self.onExport = onExport
        self.onPrint = onPrint
        self.editorViewModel = editorViewModel
        
        self._interactionVM = StateObject(wrappedValue: MapInteractionViewModel(appState: appState))
    }

    private var editModeBinding: Binding<MapEditMode> {
        Binding(
            get: { appState.mapEditMode },
            set: { appState.mapEditMode = $0 }
        )
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
            
            let currentRenderData = cachedRenderData ?? MapGeometryEngine.generateRenderData(
                network: appState.railroad.network,
                lines: appState.railroad.lines,
                size: size,
                bounds: bounds,
                hiddenLineIds: hiddenLineIds
            )
            
            ZStack {
                mainViewContainer(size: size, bounds: bounds, renderData: currentRenderData)
                
                // Overlay fissi rispetto al viewport (NON all'area della mappa)
                VStack {
                    StationPickingIndicator()
                    Spacer()
                    if editMode == .addTrack {
                        TrackCreationOverlay(
                            editMode: editModeBinding,
                            newTrackFrom: $newTrackFrom,
                            newTrackTo: $newTrackTo,
                            newTrackDistance: $newTrackDistance,
                            newTrackType: $newTrackType,
                            onCreate: { 
                                if let from = newTrackFrom, let to = newTrackTo {
                                    interactionVM.createTrack(from: from, to: to, distance: newTrackDistance, type: newTrackType) 
                                    // Reset locale e AppState dopo creazione
                                    withAnimation {
                                        newTrackFrom = nil
                                        newTrackTo = nil
                                        appState.trackDraftFromId = nil
                                        appState.trackDraftToId = nil
                                        appState.mapEditMode = .explore
                                    }
                                }
                            }
                        )
                        .padding(.bottom, 20)
                    }
                }
                .padding()
                
                brushStrokeOverlay(size: size)
            }
                .onAppear {
                    // Initialize first render
                    updateRenderData(size: size)
                }
                .onChange(of: appState.railroad.topologyId) { _ in
                    updateRenderData(size: size)
                }
                .onChange(of: totalZoom) { _ in
                    updateRenderData(size: size)
                }
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

    private func updateRenderData(size: CGSize) {
        // Evitiamo ricalcoli inutili se i dati critici non sono cambiati
        if cachedRenderData != nil && 
           lastSize == size && 
           lastZoom == totalZoom && 
           lastTopologyId == appState.railroad.topologyId {
            return
        }
        
        let newRD = MapGeometryEngine.generateRenderData(
            network: appState.railroad.network,
            lines: appState.railroad.lines,
            size: size,
            bounds: self.mapBounds,
            hiddenLineIds: hiddenLineIds
        )
        
        self.cachedRenderData = newRD
        self.lastSize = size
        self.lastZoom = totalZoom
        self.lastTopologyId = appState.railroad.topologyId
    }

    private func canvasSize(for geoSize: CGSize) -> CGSize {
        CGSize(
            width: max(geoSize.width * totalZoom, geoSize.width),
            height: max(geoSize.height * totalZoom, geoSize.height)
        )
    }

    private func mainViewContainer(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        scrollViewLayer(size: size, bounds: bounds, renderData: renderData)
    }

    private func scrollViewLayer(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    mapBasement(size: size, bounds: bounds, renderData: renderData)
                    MapMainLayersView(
                        mode: mode,
                        renderData: renderData,
                        bounds: bounds,
                        size: size,
                        totalZoom: totalZoom,
                        coordinateGridStep: coordinateGridStep,
                        showGrid: showGrid,
                        onStationTap: { _, location in 
                            handleMapTap(at: location, renderData: renderData)
                        }
                    )
                    
                    brushStrokeOverlay(size: size)
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleMapTap(at: location, renderData: renderData)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            stationPlacementLocation = value.location
                            // Ignoriamo la pennellata se stiamo navigando (2 dita)
                            guard !isNavigating else { return }

                            if appState.mapEditMode == .brushPath || appState.mapEditMode == .erasePath {
                                appState.brushStrokePoints.append(value.location)
                                detectBrushHit(at: value.location, renderData: renderData)
                            }
                        }
                        .onEnded { _ in
                            if !appState.brushStrokePoints.isEmpty {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    appState.brushStrokePoints.removeAll()
                                }
                            }
                        }
                )
                .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 20) {
                    guard editMode == .addStation else { return }
                    let location = stationPlacementLocation
                    if let editorVM = editorViewModel {
                        editorVM.placeStation(at: location, in: size, bounds: bounds)
                    } else {
                        _ = interactionVM.createStation(at: location, in: size, bounds: bounds)
                        appState.mapEditMode = .explore
                    }
                }
            }
            .scrollDisabled(editMode == .addStation)
        }
    }

    private func mapBasement(size: CGSize, bounds: MapBounds, renderData: MapRenderData) -> some View {
        ZStack {
            Color.white
            if showGrid {
                CoordinateGridShape(bounds: bounds, unit: coordinateGridStep, size: size)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func handleMapTap(at location: CGPoint, renderData: MapRenderData) {
        // 1. Cerca il vincitore assoluto tra nodi e binari
        var bestNode: (id: String, distSq: CGFloat)? = nil
        var bestEdge: (id: String, distSq: CGFloat)? = nil
        
        let nodeThresholdSq: CGFloat = 900.0 // 30px
        let edgeThresholdSq: CGFloat = 625.0 // 25px
        
        for target in renderData.selectionIndex {
            guard target.bounds.contains(location) else { continue }
            
            if target.type == .node, let center = target.center {
                let dx = location.x - center.x
                let dy = location.y - center.y
                let dSq = dx*dx + dy*dy
                if dSq < nodeThresholdSq {
                    if bestNode == nil || dSq < bestNode!.distSq {
                        bestNode = (target.id, dSq)
                    }
                }
            } else if target.type == .edge, let points = target.points {
                for i in 0..<(points.count - 1) {
                    let dSq = squaredDistanceToSegment(p: location, a: points[i], b: points[i+1])
                    if dSq < edgeThresholdSq {
                        if bestEdge == nil || dSq < bestEdge!.distSq {
                            bestEdge = (target.id, dSq)
                        }
                    }
                }
            }
        }
        
        // 2. Decisione: Se siamo MOLTO vicini a un nodo (< 15px), vince il nodo. 
        // Altrimenti, vince ciò che è effettivamente più vicino.
        let finalSelection: (id: String, type: MapRenderData.HitTarget.TargetType)? = {
            if let node = bestNode, let edge = bestEdge {
                if node.distSq < 225.0 || node.distSq < edge.distSq {
                    return (node.id, .node)
                } else {
                    return (edge.id, .edge)
                }
            } else if let node = bestNode {
                return (node.id, .node)
            } else if let edge = bestEdge {
                return (edge.id, .edge)
            }
            return nil
        }()
        
        // 3. Applica selezione
        withAnimation(.easeInOut(duration: 0.2)) {
            if let sel = finalSelection {
                if sel.type == .node {
                    if let node = appState.railroad.network.nodes.first(where: { $0.id == sel.id }) {
                        interactionVM.handleStationTap(node, editMode: editModeBinding, newTrackFrom: $newTrackFrom, newTrackTo: $newTrackTo, newTrackDistance: $newTrackDistance)
                    }
                } else {
                    appState.selectedEdgeId = sel.id
                    appState.selectedNodeId = nil
                    appState.selectedRouteId = nil
                    appState.activePanel = .inspector
                }
            } else {
                appState.clearSelection()
            }
        }
    }

    private func squaredDistanceToSegment(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let l2 = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
        if l2 == 0 { 
            let dx = p.x - a.x
            let dy = p.y - a.y
            return dx*dx + dy*dy
        }
        var t = ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / l2
        t = max(0, min(1, t))
        let dx = p.x - (a.x + t * (b.x - a.x))
        let dy = p.y - (a.y + t * (b.y - a.y))
        return dx*dx + dy*dy
    }

    private func detectBrushHit(at location: CGPoint, renderData: MapRenderData) {
        let nodeThresholdSq: CGFloat = 625.0 // 25px per il pennello (leggermente meno del tap per precisione)
        
        for target in renderData.selectionIndex {
            guard target.type == .node, let center = target.center else { continue }
            guard target.bounds.contains(location) else { continue }
            
            let dx = location.x - center.x
            let dy = location.y - center.y
            let dSq = dx*dx + dy*dy
            
            if dSq < nodeThresholdSq {
                if let node = appState.railroad.network.nodes.first(where: { $0.id == target.id }) {
                    // Evitiamo di chiamare continuamente la logica se il nodo è già nello stato desiderato
                    let isAlreadySelected = appState.isCreatingLine ? appState.lineDraftStations.contains(node.id) : appState.selectedNodeIds.contains(node.id)
                    
                    if (appState.mapEditMode == .brushPath && !isAlreadySelected) || 
                       (appState.mapEditMode == .erasePath && isAlreadySelected) {
                        interactionVM.handleStationTap(node, editMode: editModeBinding, newTrackFrom: $newTrackFrom, newTrackTo: $newTrackTo, newTrackDistance: $newTrackDistance)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func brushStrokeOverlay(size: CGSize) -> some View {
        if !appState.brushStrokePoints.isEmpty {
            Canvas { context, size in
                var path = Path()
                if let first = appState.brushStrokePoints.first {
                    path.move(to: first)
                    for point in appState.brushStrokePoints.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                
                let color: Color = appState.mapEditMode == .erasePath ? .red : .orange
                context.stroke(path, with: .color(color.opacity(0.4)), style: StrokeStyle(lineWidth: 25, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .simultaneously(with: RotationGesture())
            .updating($isNavigating) { _, state, _ in
                state = true
            }
            .onChanged { value in
                magnification = value.first ?? 1.0
            }
            .onEnded { value in
                zoomLevel *= (value.first ?? 1.0)
                magnification = 1.0
            }
    }
}
