//
//  EditorModeView.swift
//  FdC Railway Manager
//

import Foundation
import Combine
import SwiftUI
import MapKit
import CoreLocation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UniformTypeIdentifiers

struct EditorModeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    

    @State private var lockedNodeIds: Set<String> = []
    @State private var isShowingLineCreation = false
    @State private var editingLineId: String? = nil
    
    // Altimetry State
    // REMOVED local isCreatingTrackMode to sync with appState
    
    var body: some View {
        ZStack {
            // 0. ABSOLUTE BASE (Prevent any black flickering)
            Color.white.ignoresSafeArea()
            
            GeometryReader { proxy in
                ZStack {
                    // 1. Map (Full Screen)
                    RailwayMapView(
                        selectedNode: Binding(
                            get: { appState.selectedNode },
                            set: { node in
                                handleNodeSelection(node)
                            }
                        ),
                        selectedLine: Binding(
                            get: { appState.selectedLine },
                            set: { line in
                                appState.selectedLineId = line?.id
                                if line != nil { appState.showPanel(.inspector) }
                            }
                        ),
                        selectedEdgeId: Binding(
                            get: { appState.selectedEdgeId },
                            set: { edgeId in
                                appState.selectedEdgeId = edgeId
                                if edgeId != nil { appState.showPanel(.inspector) }
                            }
                        ),
                        showGrid: $appState.showGrid,
                        isMoveModeEnabled: .constant(true),
                        highlightedConflictLocation: .constant(nil),
                        mode: $appState.mapVisualizationMode 
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                    
                    // 2. Control Overlays
                    ZStack(alignment: .topLeading) {
                        // Top Toolbar - REMOVED (no longer needed)
                        // editorToolbar
                        //     .padding(.top, proxy.safeAreaInsets.top + 8)
                        //     .frame(maxWidth: .infinity, alignment: .top)
                        
                        // Left Toolbox
                        verticalToolbox
                            .padding(.top, proxy.safeAreaInsets.top + 60)
                            .padding(.leading, proxy.safeAreaInsets.leading + 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(true)

                    // 3. Bottom Panel (Floating)
                    // Show elevation profile for: lines, edges, single nodes, multi-selection, and ferrovie
                    // BUT NOT in multi-select mode (to allow selecting stations without obstruction)
                    let showProfile = !appState.isMultiSelectMode && ((appState.selectedLineId != nil) || (appState.selectedEdgeId != nil) || (appState.selectedNodeId != nil) || (appState.selectedNodeIds.count > 1) || (appState.selectedFerroviaId != nil))
                    FdCBottomPanel(
                        isPresented: .constant(showProfile),
                        title: "Profilo Altimetrico",
                        preferredHeight: 380
                    ) {
                        AltimetricProfileView(lockedNodeIds: $lockedNodeIds)
                    }
                
                // Inspector Panel (right side)
                // Only show if NOT using the main InspectorOverlay (activePanel == .inspector means user opened Rete menu)
                if (appState.selectedNodeId != nil || appState.selectedEdgeId != nil || appState.selectedLineId != nil || appState.selectedFerroviaId != nil) && appState.activePanel != .inspector {
                    FdCInspectorPanel(
                        title: inspectorTitle,
                        onClose: {
                            appState.selectedNodeId = nil
                            appState.selectedEdgeId = nil
                            appState.selectedLineId = nil
                            selectedFerroviaId = nil
                        }
                    ) {
                        EditorInspectorContent(editingLineId: $editingLineId)
                    }
                }
            }
            }
        }
        .onAppear {
            if appState.selectedFerroviaId != nil || appState.selectedLineId != nil {
                // Clear single node/edge selections when focusing on a line or railway
                // This hides the inspector and focuses on the profile.
                appState.selectedNodeId = nil
                appState.selectedEdgeId = nil
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isShowingLineCreation) {
            LineCreationView()
                .presentationDetents([.height(180), .medium, .large])
                .presentationBackgroundInteraction(.enabled)
        }
        .sheet(item: Binding(
            get: { editingLineId.map { IdentifiableString(id: $0) } },
            set: { editingLineId = $0?.id }
        )) { ident in
            NavigationStack {
                LineEditView(lineId: ident.id)
            }
        }
        .onAppear {
            appState.currentMode = .editor
        }
        .onDisappear {
            loader.saveCurrentState()
        }
    }
    
    // MARK: - Inspector Title
    
    private var inspectorTitle: String {
        if let node = appState.selectedNode {
            return node.name
        } else if let lineId = appState.selectedLineId,
                  let line = appState.railroad.lines.findLine(id: lineId) {
            return line.name
        }
        return "Proprietà"
    }
    
    // MARK: - Editor Toolbar
    
    private var editorToolbar: some View {
        FdCToolbar(
            items: editorToolbarItems,
            onUndo: { appState.railroad.network.undo() },
            onRedo: { appState.railroad.network.redo() },
            canUndo: appState.railroad.network.canUndo,
            canRedo: appState.railroad.network.canRedo
        )
    }
    
    private var selectedFerroviaId: String? {
        get { appState.selectedFerroviaId }
        nonmutating set { appState.selectedFerroviaId = newValue }
    }
    
    private var editorToolbarItems: [FdCToolbarItem] {
        let items: [FdCToolbarItem] = [
            .button(icon: "square.and.arrow.down", label: "Esporta", action: saveScenario),
            .button(icon: "folder", label: "Apri", action: loadScenario),
        ]
        
        return items
    }
    
    private var verticalToolbox: some View {
        VStack(spacing: 12) {
            Group {
                ToolIcon(icon: "building.2.fill", label: "S", help: "Nuova Stazione", active: false) {
                    createStation()
                }
                
                ToolIcon(icon: "tram.fill", label: "B", help: "Nuovo Binario", active: appState.isCreatingTrack) {
                    appState.isCreatingTrack.toggle()
                    if appState.isCreatingTrack {
                        appState.selectedNodeId = nil
                        appState.selectedEdgeId = nil
                        appState.selectedFerroviaId = nil
                    }
                }
                
                ToolIcon(icon: "plus.rectangle.on.rectangle", label: "F", help: "Crea Ferrovia", active: false) {
                    if appState.selectedNodeIds.count > 1 {
                        createNewFerrovia()
                    }
                }
                .disabled(appState.selectedNodeIds.count < 2)
                
                Divider().frame(width: 30)
                
                ToolIcon(icon: appState.isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle", label: "M", help: "Multiselezione", active: appState.isMultiSelectMode) {
                    toggleMultiSelect()
                }
                
                if !appState.selectedNodeIds.isEmpty || appState.selectedNodeId != nil || appState.selectedEdgeId != nil || selectedFerroviaId != nil {
                    ToolIcon(icon: "trash", label: "", help: "Elimina", active: false, isDestructive: true) {
                        deleteSelectedItems()
                    }
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
    
    // MARK: - Actions
    
    func createLineFromSelection() {
        let nodes = appState.railroad.network.nodes.filter { appState.selectedNodeIds.contains($0.id) }
            .sorted { ($0.longitude ?? 0) < ($1.longitude ?? 0) }
            
        guard nodes.count > 1 else { return }
        
        appState.railroad.network.createCheckpoint()
        
        for i in 0..<nodes.count - 1 {
            let n1 = nodes[i]
            let n2 = nodes[i+1]
            
            let l1 = CLLocation(latitude: n1.latitude ?? 0, longitude: n1.longitude ?? 0)
            let l2 = CLLocation(latitude: n2.latitude ?? 0, longitude: n2.longitude ?? 0)
            let distKm = l1.distance(from: l2) / 1000.0
            
            if appState.railroad.network.findEdge(from: n1.id, to: n2.id) == nil {
                let edge = Edge(from: n1.id, to: n2.id, distance: distKm, trackType: .double, maxSpeed: 160)
                appState.railroad.network.addEdge(edge)
            }
        }
    }
    
    func createLogicalLine() {
        appState.lineDraftStations.removeAll()
        withAnimation {
            isShowingLineCreation = true
        }
    }
    
    func createNewFerrovia() {
        let count = appState.railroad.network.ferrovie.count + 1
        // Use the ordered selection if available, otherwise fallback to set (unordered)
        let stations = appState.selectedNodeIdsOrder.isEmpty ? Array(appState.selectedNodeIds) : appState.selectedNodeIdsOrder
        
        // Auto-create missing edges between consecutive stations
        for i in 0..<stations.count - 1 {
            let fromId = stations[i]
            let toId = stations[i + 1]
            
            // Check if edge already exists (in either direction)
            if appState.railroad.network.findEdge(from: fromId, to: toId) == nil &&
               appState.railroad.network.findEdge(from: toId, to: fromId) == nil {
                
                // Get the nodes to calculate distance
                guard let fromNode = appState.railroad.network.nodes.first(where: { $0.id == fromId }),
                      let toNode = appState.railroad.network.nodes.first(where: { $0.id == toId }) else {
                    continue
                }
                
                // Calculate distance using geographic coordinates
                let loc1 = CLLocation(latitude: fromNode.latitude ?? 0, longitude: fromNode.longitude ?? 0)
                let loc2 = CLLocation(latitude: toNode.latitude ?? 0, longitude: toNode.longitude ?? 0)
                let distanceKm = loc1.distance(from: loc2) / 1000.0
                
                let edgeForward = RailwayEdge(
                    id: UUID(),
                    from: fromId,
                    to: toId,
                    distance: distanceKm,
                    trackType: .double,  // Default to double track
                    maxSpeed: 160  // Default max speed (km/h)
                )
                appState.railroad.network.addEdge(edgeForward)
                
                print("✅ Auto-created edge between \(fromNode.name) and \(toNode.name) (distance: \(String(format: "%.1f", distanceKm)) km)")
            }
        }
        
        let newFerrovia = Ferrovia(
            name: "Ferrovia \(count)",
            color: ["#3498db", "#e74c3c", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c"][count % 6],
            stationIds: stations
        )
        appState.railroad.network.ferrovie.append(newFerrovia)
        appState.selectedFerroviaId = newFerrovia.id
        appState.selectedNodeIds = Set(newFerrovia.stationIds)
        appState.selectedNodeIdsOrder = Array(newFerrovia.stationIds)
        
        // Exit multi-select mode after creating ferrovia
        appState.isMultiSelectMode = false
        
        // Don't call showPanel(.inspector) in editor mode - the internal FdCInspectorPanel
        // will automatically show when selectedFerroviaId is set
        // Only call it if we're NOT in editor/design mode
        if appState.currentMode != .editor && appState.currentMode != .design {
            appState.showPanel(.inspector)
        }
        
        appState.objectWillChange.send()
    }
    
    private func createStation() {
        let id = "ST-\(Int.random(in: 1000...9999))"
        // Center of the current bounds or a default location
        // Roughly center of Italy as default if no context
        // Add slight random offset to avoid exact overlap
        let latOffset = Double.random(in: -0.02...0.02)
        let lonOffset = Double.random(in: -0.02...0.02)
        
        let newStation = RailwayNode(
            id: id,
            name: "Stazione Nuova",
            type: .station,
            latitude: 45.4642 + latOffset, // Default Milano-ish
            longitude: 9.1900 + lonOffset,
            altitude: 100,
            platforms: 2
        )
        appState.railroad.network.addNode(newStation)
        appState.selectedNodeId = id
        appState.selectedEdgeId = nil
        appState.selectedLineId = nil
    }
    
    private func toggleTrackCreation() {
        appState.isCreatingTrack.toggle()
        if appState.isCreatingTrack {
            appState.selectedNodeId = nil
            appState.selectedEdgeId = nil
        }
    }
    
    private func toggleMultiSelect() {
        appState.isMultiSelectMode.toggle()
        if !appState.isMultiSelectMode {
            // Convert to single selection if possible
            if appState.selectedNodeIds.count == 1, let first = appState.selectedNodeIds.first {
                appState.selectedNodeId = first
            } else {
                appState.selectedNodeIds.removeAll()
                appState.selectedNodeId = nil
            }
        }
    }
    
    private func handleNodeSelection(_ node: RailwayNode?) {
        guard let node = node else { 
            if !appState.isMultiSelectMode {
                appState.selectedNodeId = nil 
            }
            return 
        }
        
        if appState.isMultiSelectMode {
            appState.toggleNodeSelection(node.id)
        } else {
            appState.selectedNodeId = node.id
            appState.selectedEdgeId = nil
            appState.selectedLineId = nil
            appState.selectedFerroviaId = nil
            
            // Non mostrare l'ispettore se stiamo creando binari o se abbiamo appena selezionato il secondo nodo per un binario
            if !appState.isCreatingTrack {
                appState.showPanel(.inspector)
            }
        }
    }
    
    private func createTrack(from: String, to: String) {
        // Check if exists
        if appState.railroad.network.edges.contains(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) {
            return // Already exists
        }
        
        // Calculate distance
        let n1 = appState.railroad.network.nodes.first(where: { $0.id == from })
        let n2 = appState.railroad.network.nodes.first(where: { $0.id == to })
        var distance = 10.0
        
        if let lat1 = n1?.latitude, let lon1 = n1?.longitude,
           let lat2 = n2?.latitude, let lon2 = n2?.longitude {
            let loc1 = CLLocation(latitude: lat1, longitude: lon1)
            let loc2 = CLLocation(latitude: lat2, longitude: lon2)
            distance = loc1.distance(from: loc2) / 1000.0 // km
        }
        
        // Create Edge
        var newEdge = RailwayEdge(from: from, to: to, distance: distance, trackType: .regional, maxSpeed: 140)
        
        // Auto-generate segments
        let segmentLength = 2.0 // km
        let count = Int(ceil(distance / segmentLength))
        var segments: [TrackSegment] = []
        for i in 0..<count {
            let len = (i == count - 1) ? (distance - Double(i) * segmentLength) : segmentLength
            segments.append(TrackSegment(order: i, length: len, speedLimit: 140))
        }
        newEdge.segments = segments
        
        // Use addEdge to ensure checkpoint creation (Undo/Redo)
        appState.railroad.network.addEdge(newEdge)
        appState.selectedEdgeId = newEdge.id.uuidString
        appState.selectedNodeId = nil
        appState.selectedLineId = nil
        selectedFerroviaId = nil
    }
    
    // MARK: - Scenario Management
    private func saveScenario() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "scenario.json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(appState.railroad)
                    try data.write(to: url)
                } catch {
                    print("Error saving scenario: \(error)")
                }
            }
        }
        #else
        print("Saving not supported on this platform")
        #endif
    }
    
    private func loadScenario() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let railroad = try decoder.decode(RailroadNetwork.self, from: data)
                    appState.railroad = railroad
                    appState.objectWillChange.send()
                } catch {
                     print("Error loading scenario: \(error)")
                }
            }
        }
        #else
        print("Loading not supported on this platform")
        #endif
    }
    
    private func deleteSelectedItems() {
        appState.railroad.network.createCheckpoint()
        
        // 1. Delete Multi-selected Nodes
        if !appState.selectedNodeIds.isEmpty {
            for nodeId in appState.selectedNodeIds {
                appState.railroad.network.removeNode(nodeId)
            }
            appState.selectedNodeIds.removeAll()
        }
        
        // 2. Delete Single selected Node
        if let nodeId = appState.selectedNodeId {
            appState.railroad.network.removeNode(nodeId)
            appState.selectedNodeId = nil
            appState.selectedNodeIds.remove(nodeId)
        }
        
        // 3. Delete Edge if selected
        if let edgeId = appState.selectedEdgeId {
             if let id = UUID(uuidString: edgeId) {
                 appState.railroad.network.removeEdge(id)
             }
             appState.selectedEdgeId = nil
        }
        
        // 4. Reset Selection
        appState.selectedLineId = nil
    }
}

// Helper Styles
struct EditorButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bgColor(isPressed: configuration.isPressed))
            .foregroundColor(fgColor)
            .cornerRadius(8)
            .shadow(radius: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
    
    private func bgColor(isPressed: Bool) -> Color {
        if isDestructive { return isPressed ? .red.opacity(0.8) : .red }
        if isActive { return .blue }
        return isPressed ? .white.opacity(0.9) : .white
    }
    
    private var fgColor: Color {
        if isDestructive { return .white }
        if isActive { return .white }
        return .primary
    }
}

struct ToolIcon: View {
    let icon: String
    let label: String
    let help: String
    let active: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 10, weight: .black))
                }
            }
            .frame(width: 44, height: 44)
            .background(active ? Color.blue : (isDestructive ? Color.red.opacity(0.1) : Color.white.opacity(0.1)))
            .foregroundColor(active ? .white : (isDestructive ? .red : .primary))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct EditorInspectorContent: View {
    @EnvironmentObject var appState: AppState
    @Binding var editingLineId: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let node = appState.selectedNode, let index = appState.railroad.network.nodes.firstIndex(where: { $0.id == node.id }) {
                    // Use unified StationInspectorView
                    StationInspectorView(
                        station: Binding(
                            get: { appState.railroad.network.nodes[index] },
                            set: { appState.railroad.network.nodes[index] = $0 }
                        ),
                        isMoveModeEnabled: .constant(false),
                        onDelete: {
                            appState.railroad.network.removeNode(node.id)
                            appState.selectedNodeId = nil
                            appState.selectedNodeIds.remove(node.id)
                        }
                    )
                } else if let edgeId = appState.selectedEdgeId,
                          let index = appState.railroad.network.edges.firstIndex(where: { $0.id.uuidString == edgeId }) {
                    TrackInspectorView(
                        edge: Binding(
                            get: { appState.railroad.network.edges[index] },
                            set: { appState.railroad.network.edges[index] = $0 }
                        ),
                        onDelete: {
                            let edge = appState.railroad.network.edges[index]
                            appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                            appState.selectedEdgeId = nil
                        },
                        onBack: nil
                    )
                } else if let ferroviaId = appState.selectedFerroviaId,
                           let index = appState.railroad.network.ferrovie.firstIndex(where: { $0.id == ferroviaId }) {
                    FerroviaInspectorView(
                        ferrovia: Binding(
                            get: { appState.railroad.network.ferrovie[index] },
                            set: { appState.railroad.network.ferrovie[index] = $0 }
                        ),
                        onDelete: {
                            appState.railroad.network.ferrovie.remove(at: index)
                            appState.selectedFerroviaId = nil
                        },
                        onBack: nil
                    )
                } else {
                    Text("Seleziona una stazione, binario o ferrovia per modificare le proprietà fisiche.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    private func addStationToLine(node: RailwayNode, line: RailwayLine) {
        appState.railroad.network.createCheckpoint()
        var updatedLine = line
        let newStop = RelationStop(stationId: node.id, minDwellTime: 1, track: "1")
        updatedLine.stops.append(newStop)
        
        if let idx = appState.railroad.lines.lines.firstIndex(where: { $0.id == line.id }) {
            appState.railroad.lines.lines[idx] = updatedLine
        }
    }

    

    
    @ViewBuilder
    private func lineEditor(line: RailwayLine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Linea: \(line.name)")
                    .font(.headline)
                Spacer()
                
                Button(action: { editingLineId = line.id }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Modifica Percorso e Dettagli")
                
                Button(role: .destructive) {
                    appState.railroad.lines.lines.removeAll(where: { $0.id == line.id })
                    appState.selectedLineId = nil
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            ForEach(0..<line.stops.count, id: \.self) { i in
                let stop = line.stops[i]
                if let node = appState.railroad.network.nodes.first(where: { $0.id == stop.stationId }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(node.name)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Spacer()
                            TextField("Alt", value: Binding(
                                get: { node.altitude ?? 0 },
                                set: { appState.railroad.network.updateNode(node.id, alt: $0) }
                            ), format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            Text("m").font(.caption)
                        }
                        
                        // Edge to next
                        if i < line.stops.count - 1 {
                            let nextStop = line.stops[i+1]
                            if let nextNode = appState.railroad.network.nodes.first(where: { $0.id == nextStop.stationId }) {
                                let edge = appState.railroad.network.findEdge(from: node.id, to: nextNode.id)
                                let dist = edge?.distance ?? {
                                    let l1 = CLLocation(latitude: node.latitude ?? 0, longitude: node.longitude ?? 0)
                                    let l2 = CLLocation(latitude: nextNode.latitude ?? 0, longitude: nextNode.longitude ?? 0)
                                    return l1.distance(from: l2) / 1000.0
                                }()
                                
                                let currentSlope = calculateSlope(from: node, to: nextNode)
                                
                                HStack {
                                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2, height: 20).padding(.leading, 5)
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text("\(String(format: "%.1f", dist)) km")
                                            .font(.caption2).foregroundColor(.secondary)
                                        
                                        HStack(spacing: 4) {
                                            Text("Pend:")
                                                .font(.caption2)
                                            TextField("0", value: Binding(
                                                get: { currentSlope },
                                                set: { newSlope in
                                                    // Propagate altitude to next node
                                                    let deltaH = newSlope * dist // m (since slope is ‰ and dist is km, conversion cancels out: (‰/1000) * (km*1000) = ‰ * km = m? Wait.
                                                    // 10‰ * 1km = 0.01 * 1000m = 10m. Correct.
                                                    let newAlt = (node.altitude ?? 0) + deltaH
                                                    appState.railroad.network.updateNode(nextNode.id, alt: newAlt)
                                                }
                                            ), format: .number)
                                            .frame(width: 40)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.caption)
                                            Text("‰")
                                                .font(.caption2)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
    }
    
    @ViewBuilder

    private func calculateSlope(from: RailwayNode, to: RailwayNode) -> Double {
        guard let alt1 = from.altitude, let alt2 = to.altitude else { return 0 }
        
        // Distance
        var distM: Double = 0
        if let edge = appState.railroad.network.findEdge(from: from.id, to: to.id) {
             distM = edge.distance * 1000
        } else {
             let l1 = CLLocation(latitude: from.latitude ?? 0, longitude: from.longitude ?? 0)
             let l2 = CLLocation(latitude: to.latitude ?? 0, longitude: to.longitude ?? 0)
             distM = l1.distance(from: l2)
        }
        
        guard distM > 0 else { return 0 }
        
        let deltaH = alt2 - alt1 // meters
        return (deltaH / distM) * 1000 // Permille
    }
    private func getNodeName(_ id: String) -> String {
        appState.railroad.network.nodes.first(where: { $0.id == id })?.name ?? id
    }
    
    // Removed duplicate updateNode, updateEdge, generateSegments, updateSegment, splitEdge methods.
    // Calls now directly reference appState.railroad.network.methodName
}

// MARK: - Altimetric Profile View
struct AltimetricProfileView: View {
    @EnvironmentObject var appState: AppState
    @Binding var lockedNodeIds: Set<String>
    
    @State private var altitudeEditNodeId: String? = nil
    @State private var altitudeEditText: String = ""
    @State private var horizontalScale: CGFloat = 0.5  // Start with compact scale to show entire line
    @State private var verticalScale: CGFloat = 1.0    // Scale for vertical zoom (altitude)
    
    private var selectedFerroviaId: String? {
        get { appState.selectedFerroviaId }
        nonmutating set { appState.selectedFerroviaId = newValue }
    }
    
    private func updateNode(_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil) {
        appState.railroad.network.createCheckpoint()
        appState.railroad.network.updateNode(id, lat: lat, lon: lon, alt: alt)
        appState.objectWillChange.send()
    }
    
    enum SlopeLimit {
        case highSpeed, freight, mountain, standard
        var maxStandard: Double {
            switch self {
            case .highSpeed: return 15
            case .freight: return 8
            case .mountain: return 30
            case .standard: return 12
            }
        }
        var technicalLimit: Double {
            switch self {
            case .highSpeed: return 35
            case .freight: return 12
            case .mountain: return 35
            case .standard: return 35
            }
        }
        static func from(_ line: RailwayLine) -> SlopeLimit {
            let name = line.name.lowercased()
            if name.contains("av") || name.contains("high speed") { return .highSpeed }
            if name.contains("merci") || name.contains("freight") { return .freight }
            if name.contains("montagna") || name.contains("mountain") { return .mountain }
            return .standard
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            GeometryReader { geo in
                contentView(geo: geo)
            }
        }
        .background(Color.white)
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Menu {
                Text("Seleziona Ferrovia")
                Divider()
                ForEach(appState.railroad.network.ferrovie) { ferrovia in
                    Button(ferrovia.name) {
                        selectedFerroviaId = ferrovia.id
                        appState.selectedLineId = nil
                        appState.selectedNodeId = nil
                        appState.selectedEdgeId = nil
                        appState.selectedNodeIds = Set(ferrovia.stationIds)
                    }
                }
            } label: {
                HStack {
                    if let fId = selectedFerroviaId, let f = appState.railroad.network.ferrovie.first(where: { $0.id == fId }) {
                        Text(f.name)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    } else {
                        Text("Profilo Altimetrico")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
            
            // Zoom controls
            HStack(spacing: 16) {
                // Horizontal zoom
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: { horizontalScale = max(0.5, horizontalScale - 0.25) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                    
                    Text("\(Int(horizontalScale * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 38)
                    
                    Button(action: { horizontalScale = min(3.0, horizontalScale + 0.25) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(6)
                
                // Vertical zoom
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: { verticalScale = max(0.5, verticalScale - 0.25) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                    
                    Text("\(Int(verticalScale * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 38)
                    
                    Button(action: { verticalScale = min(3.0, verticalScale + 0.25) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(6)
                
                Button(action: { 
                    horizontalScale = 1.0
                    verticalScale = 1.0
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            if let lineId = appState.selectedLineId,
               let line = appState.railroad.lines.findLine(id: lineId) {
                let limit = SlopeLimit.from(line)
                Text("Limiti: \(Int(limit.maxStandard))‰ / \(Int(limit.technicalLimit))‰")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if selectedFerroviaId != nil {
                // Standard limit for infrastructure view
                Text("Limiti: 12‰ / 35‰")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    @ViewBuilder
    private func contentView(geo: GeometryProxy) -> some View {
        let fId = appState.selectedFerroviaId
        let lineId = appState.selectedLineId
        let selectedNodeIds = appState.selectedNodeIds
        let edgeId = appState.selectedEdgeId
        
        let stations: [RailwayNode] = {
            if let fId = fId, let fer = appState.railroad.network.ferrovie.first(where: { $0.id == fId }) {
                // For ferrovie, rebuild complete path including junction nodes
                let service = InfrastructureService(network: appState.railroad.network)
                var completePath: [RailwayNode] = []
                
                for i in 0..<fer.stationIds.count {
                    let stationId = fer.stationIds[i]
                    guard let station = appState.railroad.network.nodes.first(where: { $0.id == stationId }) else {
                        continue
                    }
                    
                    if i == 0 {
                        // First station
                        completePath.append(station)
                    } else {
                        // Find path from previous station to this one (includes junctions)
                        let prevStationId = fer.stationIds[i - 1]
                        
                        if let pathResult = service.findPath(from: prevStationId, to: stationId) {
                            // Add all nodes from path except the first (already in completePath)
                            completePath.append(contentsOf: pathResult.nodes.dropFirst())
                        } else {
                            // No path found, just add the station anyway
                            completePath.append(station)
                        }
                    }
                }
                
                return completePath
            } else if let lId = lineId, let line = appState.railroad.lines.findLine(id: lId) {
                return line.stops.compactMap { stop in appState.railroad.network.nodes.first(where: { $0.id == stop.stationId }) }
            } else if selectedNodeIds.count > 1 {
                return attemptToChain(appState.railroad.network.nodes.filter { selectedNodeIds.contains($0.id) })
            } else if let eId = edgeId, let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == eId }),
                      let n1 = appState.railroad.network.nodes.first(where: { $0.id == edge.from }),
                      let n2 = appState.railroad.network.nodes.first(where: { $0.id == edge.to }) {
                return [n1, n2]
            }
            return []
        }()
        
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            if stations.count >= 2 {
                ScrollView(.horizontal, showsIndicators: true) {
                    profileGraph(stations: stations, geo: geo)
                }
            } else if let nodeId = appState.selectedNodeId,
                      let node = appState.railroad.network.nodes.first(where: { $0.id == nodeId }) {
                  if let alt = node.altitude {
                      VStack {
                          Text("Quota: \(Int(alt)) m")
                              .font(.largeTitle.bold())
                          
                          Toggle("Blocca Altezza", isOn: Binding(
                              get: { lockedNodeIds.contains(node.id) },
                              set: { if $0 { lockedNodeIds.insert(node.id) } else { lockedNodeIds.remove(node.id) } }
                          ))
                          .toggleStyle(.button)
                          .padding(.top, 8)
                      }
                      .position(x: geo.size.width/2, y: geo.size.height/2)
                  } else {
                     Text("Nessuna quota definita")
                         .foregroundColor(.secondary)
                         .position(x: geo.size.width/2, y: geo.size.height/2)
                 }
            } else {
                 Text("Seleziona un elemento per visualizzare il profilo.")
                     .foregroundColor(.secondary)
                     .position(x: geo.size.width/2, y: geo.size.height/2)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    // Pinch to zoom both axes proportionally
                    horizontalScale = max(0.5, min(3.0, value))
                    verticalScale = max(0.5, min(3.0, value))
                }
        )
    }
    
    @ViewBuilder
    private func profileGraph(stations: [RailwayNode], geo: GeometryProxy) -> some View {
        let totalDist = totalDistance(stations: stations, network: appState.railroad.network)
        // Calculate base width to fit entire line compactly
        // availableWidth is geo width minus some padding
        let availableWidth = geo.size.width - 120
        let basePixelsPerKm: CGFloat = totalDist > 0 ? max(30, availableWidth / CGFloat(totalDist)) : 50
        
        let graphWidth = (CGFloat(totalDist) * basePixelsPerKm + 100) * horizontalScale
        
        let alts = stations.compactMap { $0.altitude }
        let minAlt = floor((alts.min() ?? 0) / 100) * 100
        let maxAlt = ceil((alts.max() ?? 100) / 100) * 100
        let baseAltRange = max(100, maxAlt - minAlt)
        // Apply vertical scale to altitude range (smaller range = more zoom)
        let altRange = baseAltRange / Double(verticalScale)
        
        let scaledPixelsPerKm = basePixelsPerKm * horizontalScale
        let pointsData = calculatePoints(stations: stations, graphWidth: graphWidth, geoHeight: geo.size.height, minAlt: minAlt, altRange: altRange, baseAltRange: baseAltRange, pixelsPerKm: scaledPixelsPerKm)
        
        ZStack {
            // Background
            Color.white
                .frame(width: graphWidth, height: geo.size.height)
            
            // Grid
            ForEach(0...4, id: \.self) { i in
                let y = geo.size.height * 0.1 + CGFloat(i) * (geo.size.height * 0.8 / 4)
                let altValue = maxAlt - (Double(i) / 4.0) * altRange
                
                Path { path in
                    path.move(to: CGPoint(x: 40, y: y))
                    path.addLine(to: CGPoint(x: graphWidth, y: y))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                
                Text("\(Int(altValue))m")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .position(x: 20, y: y)
            }
            
            // Station vertical lines (dashed)
            ForEach(pointsData.filter { $0.isStation }) { p in
                Path { path in
                    path.move(to: CGPoint(x: p.point.x, y: geo.size.height * 0.1))
                    path.addLine(to: CGPoint(x: p.point.x, y: geo.size.height * 0.9))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(.blue.opacity(0.3))
                
                // Station name at bottom
                if let nodeId = p.nodeId, let station = appState.railroad.network.nodes.first(where: { $0.id == nodeId }) {
                    Text(station.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(4)
                        .rotationEffect(.degrees(-45))
                        .position(x: p.point.x + 25, y: geo.size.height * 0.92)
                }
            }
            
            // Segments (draw lines between all consecutive points)
            if pointsData.count > 1 {
                ForEach(0..<pointsData.count - 1, id: \.self) { i in
                    let p1 = pointsData[i]
                    let p2 = pointsData[i+1]
                    
                    // Calculate slope between these two points (meters / km = permille)
                    let alt1 = getAltitudeForPoint(p1)
                    let alt2 = getAltitudeForPoint(p2)
                    let distKm = abs(p2.cumulativeDistance - p1.cumulativeDistance)
                    let slope = distKm > 0 ? (alt2 - alt1) / distKm : 0
                    
                    // Draw slope line (tap handling delegated to global gesture)
                    Path { path in
                        path.move(to: p1.point)
                        path.addLine(to: p2.point)
                    }
                    .stroke(slopeColor(slope), lineWidth: 3)
                    
                    // Show slope percentage
                    let midX = (p1.point.x + p2.point.x) / 2
                    let midY = (p1.point.y + p2.point.y) / 2
                    Text(String(format: "%.1f‰", abs(slope)))
                         .font(.system(size: 9, weight: .bold))
                         .foregroundColor(slopeColor(slope))
                         .padding(2)
                         .background(Color.white.opacity(0.8))
                         .cornerRadius(4)
                         .position(x: midX, y: midY - 15)
                }
            }
            
            // Points
            ForEach(pointsData) { p in
                if let nodeId = p.nodeId,
                   let station = appState.railroad.network.nodes.first(where: { $0.id == nodeId }) {
                    // Node point (Station or Junction)
                    DraggablePointView(
                        point: p.point,
                        station: station,
                        altRange: baseAltRange,
                        geoHeight: geo.size.height,
                        isLocked: lockedNodeIds.contains(station.id),
                        isEditing: altitudeEditNodeId == station.id,
                        editText: $altitudeEditText,
                        onUpdate: { newAlt in
                            smartUpdateNodeAltitude(stationId: station.id, newAltitude: newAlt, chain: stations)
                        },
                        onLongPress: {
                            altitudeEditText = "\(Int(station.altitude ?? 0))"
                            altitudeEditNodeId = station.id
                        },
                        onCommitEdit: {
                            let sanitized = altitudeEditText.replacingOccurrences(of: ",", with: ".")
                            if let val = Double(sanitized) {
                                smartUpdateNodeAltitude(stationId: station.id, newAltitude: val, chain: stations)
                            }
                            altitudeEditNodeId = nil
                        },
                        onCancelEdit: {
                            altitudeEditNodeId = nil
                        },
                        onToggleLock: {
                            if lockedNodeIds.contains(station.id) {
                                lockedNodeIds.remove(station.id)
                            } else {
                                lockedNodeIds.insert(station.id)
                            }
                        }
                    )
                    .help("\(station.name.isEmpty ? (station.type == .junction ? "Bivio" : "Punto") : station.name): \(Int(station.altitude ?? 0))m")
                } else if !p.isStation, let segmentId = p.segmentId, let edgeId = p.edgeId,
                          let edge = appState.railroad.network.edges.first(where: { $0.id == edgeId }),
                          let segment = edge.segments.first(where: { $0.id == segmentId }) {
                    // Intermediate segment point
                    IntermediatePointView(
                        point: p.point,
                        segment: segment,
                        edge: edge,
                        altRange: baseAltRange,
                        geoHeight: geo.size.height,
                        isEditing: altitudeEditNodeId == segmentId.uuidString,
                        editText: $altitudeEditText,
                        onUpdate: { newAlt in
                            updateSegmentAltitude(edgeId: edgeId, segmentId: segmentId, newAltitude: newAlt)
                        },
                        onLongPress: {
                            altitudeEditText = "\(Int(segment.altitude ?? 0))"
                            altitudeEditNodeId = segmentId.uuidString
                        },
                        onCommitEdit: {
                            if let val = Double(altitudeEditText) {
                                updateSegmentAltitude(edgeId: edgeId, segmentId: segmentId, newAltitude: val)
                            }
                            altitudeEditNodeId = nil
                        },
                        onCancelEdit: {
                            altitudeEditNodeId = nil
                        },
                        onDelete: {
                            deleteIntermediatePoint(edgeId: edgeId, segmentId: segmentId)
                            altitudeEditNodeId = nil
                        }
                    )
                    .help("Punto intermedio: \(Int(segment.altitude ?? 0))m")
                }
            }
        }
        .frame(width: graphWidth, height: geo.size.height)
        .contentShape(Rectangle())
        .onTapGesture { location in
            // Handle clicks on the altitude profile
            handleGraphClick(at: location, pointsData: pointsData, stations: stations, geo: geo, minAlt: minAlt, altRange: altRange)
        }
    }
    

    // Smart leveling: if slope exceeds technical limits, propagate to neighbors
    private func smartUpdateNodeAltitude(stationId: String, newAltitude: Double, chain: [RailwayNode]) {
        guard let idx = chain.firstIndex(where: { $0.id == stationId }) else { return }
        
        appState.railroad.network.createCheckpoint()
        updateNode(stationId, alt: newAltitude)
        
        // Use InfrastructureService for distance calculations
        let service = InfrastructureService(network: appState.railroad.network)
        
        // Max technical slope (e.g., 35 permille)
        let limit: Double = 35.0
        
        // Propagation Forward
        var currentIdx = idx
        while currentIdx < chain.count - 1 {
            let n1 = appState.railroad.network.nodes.first { $0.id == chain[currentIdx].id }!
            let n2 = appState.railroad.network.nodes.first { $0.id == chain[currentIdx+1].id }!
            
            let slope = calculateSlope(from: n1, to: n2)
            if abs(slope) > limit {
                if !lockedNodeIds.contains(n2.id) {
                    // Use InfrastructureService to find distance (handles junction nodes)
                    guard let distance = service.calculateDistance(from: n1.id, to: n2.id) else {
                        break
                    }
                    let neededDeltaH = (limit / 1000.0) * (distance * 1000.0)
                    let sign: Double = slope > 0 ? 1 : -1
                    let newN2Alt = (n1.altitude ?? 0) + (sign * neededDeltaH)
                    updateNode(n2.id, alt: newN2Alt)
                    currentIdx += 1
                } else {
                    break // Stop propagation if next is locked
                }
            } else {
                break // Limit not exceeded
            }
        }
        
        // Propagation Backward
        currentIdx = idx
        while currentIdx > 0 {
            let n2 = appState.railroad.network.nodes.first { $0.id == chain[currentIdx].id }!
            let n1 = appState.railroad.network.nodes.first { $0.id == chain[currentIdx-1].id }!
            
            let slope = calculateSlope(from: n1, to: n2)
            if abs(slope) > limit {
                if !lockedNodeIds.contains(n1.id) {
                    // Use InfrastructureService to find distance (handles junction nodes)
                    guard let distance = service.calculateDistance(from: n1.id, to: n2.id) else {
                        break
                    }
                    let neededDeltaH = (limit / 1000.0) * (distance * 1000.0)
                    let sign: Double = slope > 0 ? -1 : 1
                    let newN1Alt = (n2.altitude ?? 0) + (sign * neededDeltaH)
                    updateNode(n1.id, alt: newN1Alt)
                    currentIdx -= 1
                } else {
                    break
                }
            } else {
                break
            }
        }
    }
    
    // Update altitude for an intermediate segment point
    private func updateSegmentAltitude(edgeId: UUID, segmentId: UUID, newAltitude: Double) {
        appState.railroad.network.createCheckpoint()
        
        if let edgeIdx = appState.railroad.network.edges.firstIndex(where: { $0.id == edgeId }),
           let segmentIdx = appState.railroad.network.edges[edgeIdx].segments.firstIndex(where: { $0.id == segmentId }) {
            appState.railroad.network.edges[edgeIdx].segments[segmentIdx].altitude = newAltitude
            appState.objectWillChange.send()
        }
    }
    
    // Delete an intermediate point by removing its altitude
    private func deleteIntermediatePoint(edgeId: UUID, segmentId: UUID) {
        appState.railroad.network.createCheckpoint()
        
        if let edgeIdx = appState.railroad.network.edges.firstIndex(where: { $0.id == edgeId }),
           let segmentIdx = appState.railroad.network.edges[edgeIdx].segments.firstIndex(where: { $0.id == segmentId }) {
            appState.railroad.network.edges[edgeIdx].segments[segmentIdx].altitude = nil
            appState.objectWillChange.send()
        }
    }
    
    // Get altitude for a point (station or segment)
    private func getAltitudeForPoint(_ point: PointData) -> Double {
        if let nodeId = point.nodeId,
           let node = appState.railroad.network.nodes.first(where: { $0.id == nodeId }) {
            return node.altitude ?? 0
        } else if let segmentId = point.segmentId, let edgeId = point.edgeId,
                  let edge = appState.railroad.network.edges.first(where: { $0.id == edgeId }),
                  let segment = edge.segments.first(where: { $0.id == segmentId }) {
            return segment.altitude ?? 0
        }
        return 0
    }
    
    // Handle tap on a segment to create/move a junction point
    private func handleSegmentTap(p1: PointData, p2: PointData, location: CGPoint, geo: GeometryProxy, minAlt: Double, altRange: Double) {
        // Allow creating junctions between ANY consecutive nodes (stations or junctions)
        guard let nodeId1 = p1.nodeId,
              let nodeId2 = p2.nodeId,
              let node1 = appState.railroad.network.nodes.first(where: { $0.id == nodeId1 }),
              let node2 = appState.railroad.network.nodes.first(where: { $0.id == nodeId2 }) else {
            return
        }
        
        // Use InfrastructureService to find edge (handles bidirectional)
        let service = InfrastructureService(network: appState.railroad.network)
        guard let edgeDistance = service.calculateDistance(from: nodeId1, to: nodeId2) else {
            return
        }
        
        // Find the actual edge (try both directions)
        var edge: Edge?
        if let e = appState.railroad.network.findEdge(from: nodeId1, to: nodeId2) {
            edge = e
        } else if let e = appState.railroad.network.findEdge(from: nodeId2, to: nodeId1) {
            edge = e
        }
        
        guard let edge = edge else {
            return
        }
        
        // Calculate the altitude at the tap location
        let effectiveH = geo.size.height * 0.8
        let normalizedAlt = (geo.size.height - location.y - geo.size.height * 0.1) / effectiveH
        let clampedNorm = max(0, min(1, normalizedAlt))
        let newAlt = minAlt + Double(clampedNorm) * altRange
        
        // Calculate the position along the edge based on cumulative distance
        // This ensures junction is placed at the correct km position
        let junctionCumulativeDistance = p1.cumulativeDistance + (p2.cumulativeDistance - p1.cumulativeDistance) * Double((location.x - p1.point.x) / (p2.point.x - p1.point.x))
        
        // Calculate how far the junction is from node1 and node2
        let distFromNode1 = junctionCumulativeDistance - p1.cumulativeDistance
        let distFromNode2 = p2.cumulativeDistance - junctionCumulativeDistance
        
        // Calculate relative position for geographic interpolation (0 to 1)
        let relativePosition = distFromNode1 / edgeDistance
        
        // Calculate geographic position (interpolate based on actual distance ratio)
        let lat1 = node1.latitude ?? 0
        let lon1 = node1.longitude ?? 0
        let lat2 = node2.latitude ?? 0
        let lon2 = node2.longitude ?? 0
        
        let junctionLat = lat1 + (lat2 - lat1) * relativePosition
        let junctionLon = lon1 + (lon2 - lon1) * relativePosition
        
        appState.railroad.network.createCheckpoint()
        
        // Create and add junction node
        let junctionNode = RailwayNode(
            id: UUID().uuidString,
            name: "",
            type: .junction,
            latitude: junctionLat,
            longitude: junctionLon,
            altitude: newAlt
        )
        appState.railroad.network.nodes.append(junctionNode)
        
        // Find existing edges to replicate their directionality
        let edgesForward = appState.railroad.network.edges.filter { $0.from == nodeId1 && $0.to == nodeId2 }
        let edgesBackward = appState.railroad.network.edges.filter { $0.from == nodeId2 && $0.to == nodeId1 }
        
        // Remove old edges
        appState.railroad.network.edges.removeAll { $0.from == nodeId1 && $0.to == nodeId2 }
        appState.railroad.network.edges.removeAll { $0.from == nodeId2 && $0.to == nodeId1 }
        
        // Rebuild segments only for existing directions
        for oldEdge in edgesForward {
            let edgeAJ = RailwayEdge(from: nodeId1, to: junctionNode.id, distance: distFromNode1, trackType: oldEdge.trackType, maxSpeed: oldEdge.maxSpeed)
            let edgeJB = RailwayEdge(from: junctionNode.id, to: nodeId2, distance: distFromNode2, trackType: oldEdge.trackType, maxSpeed: oldEdge.maxSpeed)
            appState.railroad.network.addEdge(edgeAJ)
            appState.railroad.network.addEdge(edgeJB)
        }
        
        for oldEdge in edgesBackward {
            let edgeBJ = RailwayEdge(from: nodeId2, to: junctionNode.id, distance: distFromNode2, trackType: oldEdge.trackType, maxSpeed: oldEdge.maxSpeed)
            let edgeJA = RailwayEdge(from: junctionNode.id, to: nodeId1, distance: distFromNode1, trackType: oldEdge.trackType, maxSpeed: oldEdge.maxSpeed)
            appState.railroad.network.addEdge(edgeBJ)
            appState.railroad.network.addEdge(edgeJA)
        }
        
        appState.objectWillChange.send()
    }
    
    private func handleGraphClick(at location: CGPoint, pointsData: [PointData], stations: [RailwayNode], geo: GeometryProxy, minAlt: Double, altRange: Double) {
        guard !pointsData.isEmpty else { return }
        // Skip if we are currently manually editing a node via popover
        guard altitudeEditNodeId == nil else { return }
        
        // Convert Y click position to altitude
        let effectiveH = geo.size.height * 0.8
        let normalizedAlt = (geo.size.height - location.y - geo.size.height * 0.1) / effectiveH
        let clampedNorm = max(0, min(1, normalizedAlt))
        let newAlt = minAlt + Double(clampedNorm) * altRange
        
        // Find the nearest node by horizontal distance
        var nearestIdx = 0
        var nearestDist: CGFloat = .infinity
        
        for (i, p) in pointsData.enumerated() {
            // Consider all nodes (stations AND junctions)
            if let _ = p.nodeId {
                let dist = abs(p.point.x - location.x)
                if dist < nearestDist {
                    nearestDist = dist
                    nearestIdx = i
                }
            }
        }
        
        // Threshold: if click is within 20 pixels of a node, modify its altitude
        let clickThreshold: CGFloat = 20
        
        if nearestDist < clickThreshold {
            // Close to a node → modify its altitude
            guard let nodeId = pointsData[nearestIdx].nodeId else { return }
            
            // Skip locked nodes
            guard !lockedNodeIds.contains(nodeId) else { return }
            
            updateNode(nodeId, alt: newAlt)
            appState.selectedNodeId = nodeId
            
        } else {
            // Far from stations → create junction at clicked position
            // Find which segment the click falls into
            var segmentIdx = -1
            for i in 0..<pointsData.count - 1 {
                let p1 = pointsData[i]
                let p2 = pointsData[i + 1]
                
                // Check if click X is between p1 and p2
                if location.x >= min(p1.point.x, p2.point.x) && 
                   location.x <= max(p1.point.x, p2.point.x) {
                    segmentIdx = i
                    break
                }
            }
            
            guard segmentIdx >= 0 && segmentIdx < pointsData.count - 1 else { return }
            
            let p1 = pointsData[segmentIdx]
            let p2 = pointsData[segmentIdx + 1]
            
            // Delegate to handleSegmentTap which creates the junction with proper interpolation
            handleSegmentTap(p1: p1, p2: p2, location: location, geo: geo, minAlt: minAlt, altRange: altRange)
        }
    }
    
    func calculateSlope(from: RailwayNode, to: RailwayNode) -> Double {
        guard let alt1 = from.altitude, let alt2 = to.altitude else { return 0 }
        let l1 = CLLocation(latitude: from.latitude ?? 0, longitude: from.longitude ?? 0)
        let l2 = CLLocation(latitude: to.latitude ?? 0, longitude: to.longitude ?? 0)
        
        let distKm: Double
        if let edge = appState.railroad.network.findEdge(from: from.id, to: to.id) {
             distKm = edge.distance
        } else {
             distKm = l1.distance(from: l2) / 1000.0
        }
        guard distKm > 0 else { return 0 }
        let deltaH = alt2 - alt1
        return (deltaH / (distKm * 1000.0)) * 1000.0
    }

    // MARK: - Helpers
    private func slopeColor(_ slope: Double) -> Color {
        let absSlope = abs(slope)
        if absSlope < 12 { return .green }
        if absSlope < 20 { return .yellow }
        if absSlope < 35 { return .orange }
        return .red
    }
    
    private struct PointData: Identifiable {
        let id: String  // nodeId or segmentId
        let index: Int
        let point: CGPoint
        let nodeId: String?
        let segmentId: UUID?
        let edgeId: UUID?
        let isStation: Bool
        let cumulativeDistance: Double  // Distance from start of ferrovia in km
        
        init(index: Int, point: CGPoint, nodeId: String, isStation: Bool = true, cumulativeDistance: Double = 0) {
            self.id = nodeId
            self.index = index
            self.point = point
            self.nodeId = nodeId
            self.segmentId = nil
            self.edgeId = nil
            self.isStation = isStation
            self.cumulativeDistance = cumulativeDistance
        }
        
        init(index: Int, point: CGPoint, segmentId: UUID, edgeId: UUID, cumulativeDistance: Double = 0) {
            self.id = segmentId.uuidString
            self.index = index
            self.point = point
            self.nodeId = nil
            self.segmentId = segmentId
            self.edgeId = edgeId
            self.isStation = false
            self.cumulativeDistance = cumulativeDistance
        }
    }
    
    private func calculatePoints(stations: [RailwayNode], graphWidth: CGFloat, geoHeight: CGFloat, minAlt: Double, altRange: Double, baseAltRange: Double, pixelsPerKm: CGFloat) -> [PointData] {
        var points: [PointData] = []
        guard stations.count >= 2 else { return [] }
        
        // Use InfrastructureService for unified path finding
        let service = InfrastructureService(network: appState.railroad.network)
        
        // Build complete path including ALL nodes (stations AND junctions)
        var completePath: [RailwayNode] = []
        var cumulativeDistances: [Double] = []
        var currentDistance: Double = 0.0
        
        for i in 0..<stations.count {
            let station = stations[i]
            
            if i == 0 {
                // First station
                completePath.append(station)
                cumulativeDistances.append(currentDistance)
            } else {
                // Find path from previous station to this one (includes junctions)
                let prevStation = stations[i - 1]
                guard let pathResult = service.findPath(from: prevStation.id, to: station.id) else {
                    continue
                }
                
                // Add all intermediate nodes (skip first node as it's already in completePath)
                // and calculate their cumulative distances from the start of the entire path
                for (nodeIndex, node) in pathResult.nodes.enumerated() {
                    if nodeIndex == 0 { continue } // Skip first node (previous station)
                    
                    // Calculate distance from the start of this segment to this node
                    // by summing segments from the start of pathResult to this node
                    var segmentDistance = 0.0
                    for segmentIndex in 0..<nodeIndex {
                        if segmentIndex < pathResult.segments.count {
                            segmentDistance += pathResult.segments[segmentIndex].distance
                        }
                    }
                    
                    // Add to the cumulative distance from the start of the entire railway
                    let totalDistance = currentDistance + segmentDistance
                    
                    completePath.append(node)
                    cumulativeDistances.append(totalDistance)
                }
                
                currentDistance += pathResult.totalDistance
            }
        }
        
        // Now create PointData for ALL nodes (treating junctions as special stations)
        for (index, node) in completePath.enumerated() {
            let altitude = node.altitude ?? 0
            let distance = cumulativeDistances[index]
            
            let x = 50 + CGFloat(distance) * pixelsPerKm
            let normalizedAlt = CGFloat(altitude - minAlt) / CGFloat(altRange)
            let y = geoHeight - (normalizedAlt * geoHeight * 0.8) - (geoHeight * 0.1)
            
            let isStation = node.type == .station || node.type == .interchange
            points.append(PointData(index: index, point: CGPoint(x: x, y: y), nodeId: node.id, isStation: isStation, cumulativeDistance: distance))
        }
        
        return points
    }
    
    private func attemptToChain(_ nodes: [Node]) -> [Node] {
        // Find end points (nodes with only 1 neighbor in the selection)
        var adj: [String: [String]] = [:]
        let ids = Set(nodes.map { $0.id })
        
        for n in nodes {
            let connected = appState.railroad.network.getConnectedNodeIds(for: n.id).filter { ids.contains($0) }
            adj[n.id] = connected
        }
        
        let ends = nodes.filter { (adj[$0.id]?.count ?? 0) == 1 }
        let startNode = ends.first ?? nodes.first!
        
        var chain: [Node] = []
        var current: Node? = startNode
        var visited = Set<String>()
        
        while let curr = current, !visited.contains(curr.id) {
            chain.append(curr)
            visited.insert(curr.id)
            let nextId = adj[curr.id]?.first { !visited.contains($0) }
            current = nodes.first { $0.id == nextId }
        }
        
        if chain.count < nodes.count {
            // Some nodes were not reachable in a single chain, add them at the end or fallback to longitude
            return nodes.sorted { ($0.longitude ?? 0) < ($1.longitude ?? 0) }
        }
        
        return chain
    }
    
    private func totalDistance(stations: [Node], network: NetworkModel) -> Double {
        // Use InfrastructureService for unified distance calculation
        let service = InfrastructureService(network: network)
        let stationIds = stations.map { $0.id }
        return service.calculateTotalDistance(path: stationIds)
    }
}

struct DraggablePointView: View {
    let point: CGPoint
    let station: Node
    let altRange: Double
    let geoHeight: Double
    var isLocked: Bool = false
    var isEditing: Bool = false
    @Binding var editText: String
    var onUpdate: (Double) -> Void
    var onLongPress: () -> Void
    var onCommitEdit: () -> Void
    var onCancelEdit: () -> Void
    var onToggleLock: () -> Void
    
    @State private var isDragging: Bool = false
    @State private var startAlt: Double = 0
    
    var body: some View {
        ZStack {
            // The draggable point
            Circle()
                .fill(isEditing ? Color.yellow : (isLocked ? Color.red : (station.type == .junction ? Color.black : Color.white)))
                .frame(width: station.type == .junction ? 10 : 16, height: station.type == .junction ? 10 : 16)
                .overlay(Circle().stroke(isEditing ? Color.orange : Color.blue, lineWidth: station.type == .junction ? 1 : 2))
                .overlay(
                    ZStack {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        }
                    }
                )
                .contentShape(Circle().inset(by: -10))
                .shadow(color: isEditing ? .orange.opacity(0.5) : .black.opacity(0.2), radius: isEditing ? 4 : 1)
                .position(point)
                .onTapGesture(count: 2) {
                    onLongPress()
                }
                .onLongPressGesture {
                    onLongPress()
                }
                .gesture(
                    isLocked ? nil : DragGesture(minimumDistance: 2)
                        .onChanged { val in
                            if !isDragging {
                                isDragging = true
                                startAlt = station.altitude ?? 0
                            }
                            
                            let effectiveH = geoHeight * 0.8
                            let deltaAlt = -(val.translation.height / effectiveH) * altRange
                            let newAlt = startAlt + deltaAlt
                            onUpdate(newAlt)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            
            // Altitude Editor Popover
            if isEditing {
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text(station.name.isEmpty ? (station.type == .junction ? "Bivio" : "Nodo") : station.name)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: onCancelEdit) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Altitude input
                    HStack(spacing: 4) {
                        TextField("Quota", text: $editText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Actions
                    HStack(spacing: 8) {
                        Button(action: onToggleLock) {
                            Label(
                                isLocked ? "Sblocca" : "Blocca",
                                systemImage: isLocked ? "lock.open.fill" : "lock.fill"
                            )
                            .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(isLocked ? .green : .orange)
                        
                        Spacer()
                        
                        Button(action: onCommitEdit) {
                            Text("Applica")
                                .font(.caption2.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                )
                .frame(width: 180)
                .position(x: point.x, y: point.y - 75)
            }
        }
    }
}

// MARK: - Multi-Selection Editor
struct MultiSelectionEditor: View {
    @EnvironmentObject var appState: AppState
    @Binding var lockedNodeIds: Set<String>
    
    // Local state for spring simulation parameters
    @State private var springStrength: Double = 0.5
    @State private var targetDistance: Double = 5.0 // km
    @State private var iterationCount: Int = 10
    
    var selectedNodes: [Node] {
        appState.railroad.network.nodes.filter { appState.selectedNodeIds.contains($0.id) }
            .sorted { ($0.longitude ?? 0) < ($1.longitude ?? 0) } // Default West->East sort
    }
    
    var body: some View {
        GroupBox(label: Label("Multi-Selezione (\(appState.selectedNodeIds.count))", systemImage: "square.dashed.inset.filled")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // --- Layout Operations ---
                    GroupBox("Layout") {
                        VStack(spacing: 8) {
                            Button("Allinea Latitudine (Y)") { alignLatitude() }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            
                            Button("Allinea Longitudine (X)") { alignLongitude() }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            
                            Divider()
                            
                            Text("Ottimizzazione Molle")
                                .font(.caption)
                            
                            HStack {
                                Text("Dist: \(Int(targetDistance))km")
                                Slider(value: $targetDistance, in: 1...50, step: 1)
                            }
                            
                            Button("Rilassa Layout") { relaxLayout() }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // --- Constructon Operations ---
                    GroupBox("Costruzione") {
                        Button("Crea Tracciato (O->E)") {
                            createLineFromSelection()
                        }
                        .buttonStyle(.bordered)
                        .help("Collega i nodi selezionati da Ovest a Est con doppi binari")
                    }
                    
                    // --- Altimetry Editor ---
                    GroupBox("Altimetria") {
                        ForEach(selectedNodes, id: \.id) { node in
                            HStack {
                                Text(node.name).font(.caption).lineLimit(1)
                                Spacer()
                                TextField("Alt", value: Binding(
                                    get: { node.altitude ?? 0 },
                                    set: { updateAltitude(node.id, alt: $0) }
                                ), format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                Text("m").font(.caption)
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
    }
    
    // MARK: - Logic
    
    private func alignLatitude() {
        let nodes = selectedNodes
        guard !nodes.isEmpty else { return }
        let avgLat = nodes.reduce(0.0) { $0 + ($1.latitude ?? 0) } / Double(nodes.count)
        
        appState.railroad.network.createCheckpoint()
        for node in nodes {
            updateNode(node.id, lat: avgLat)
        }
    }
    
    private func alignLongitude() {
        let nodes = selectedNodes
        guard !nodes.isEmpty else { return }
        let avgLon = nodes.reduce(0.0) { $0 + ($1.longitude ?? 0) } / Double(nodes.count)
        
        appState.railroad.network.createCheckpoint()
        for node in nodes {
            updateNode(node.id, lon: avgLon)
        }
    }
    
    private func relaxLayout() {
        // Simple Spring-Embedder 1D/2D
        guard selectedNodes.count > 1 else { return }
        
        appState.railroad.network.createCheckpoint()
        
        // Iterative relaxation
        for _ in 0..<iterationCount {
            let nodes = selectedNodes
            var newPositions: [String: (lat: Double, lon: Double)] = [:]
            
            
            for i in 0..<nodes.count {
                let node = nodes[i]
                if lockedNodeIds.contains(node.id) { continue }
                
                var forceLat = 0.0
                var forceLon = 0.0
                
                // Left neighbor
                if i > 0 {
                    let left = nodes[i-1]
                    let (fLat, fLon) = calculateSpringForce(target: left, current: node)
                    forceLat += fLat
                    forceLon += fLon
                }
                
                // Right neighbor
                if i < nodes.count - 1 {
                    let right = nodes[i+1]
                    let (fLat, fLon) = calculateSpringForce(target: right, current: node)
                    forceLat += fLat
                    forceLon += fLon
                }
                
                // Apply
                let currentLat = node.latitude ?? 0
                let currentLon = node.longitude ?? 0
                
                // Anchors (First and Last fixed)
                if i == 0 || i == nodes.count - 1 {
                    newPositions[node.id] = (currentLat, currentLon)
                } else {
                    newPositions[node.id] = (currentLat + forceLat * 0.1, currentLon + forceLon * 0.1)
                }
            }
            
            // Apply updates
            for (id, pos) in newPositions {
                updateNode(id, lat: pos.lat, lon: pos.lon)
            }
        }
    }
    
    private func calculateSpringForce(target: Node, current: Node) -> (Double, Double) {
        // Vector from current to target
        let tLat = target.latitude ?? 0
        let tLon = target.longitude ?? 0
        let cLat = current.latitude ?? 0
        let cLon = current.longitude ?? 0
        
        let dx = tLon - cLon
        let dy = tLat - cLat
        let distVal: Double = sqrt(dx*dx + dy*dy) // Renamed to avoid ambiguity
        
        guard distVal > 0 else { return (0, 0) }
        
        // Desired distance in degrees approx (very rough)
        // 1 deg ~ 111km. 1 unit ~ 100km simplificaton.
        let targetDeg = targetDistance / 100.0 
        
        let displacement = distVal - targetDeg
        
        // k * displacement * direction
        let k = springStrength
        let f = k * displacement // Double
        
        // Direction unit vector: (dy/dist, dx/dist)
        let dirY = dy / distVal
        let dirX = dx / distVal
        
        return (f * dirY, f * dirX)
    }
    
    func createLineFromSelection() {
        let nodes = selectedNodes
        guard nodes.count > 1 else { return }
        
        appState.railroad.network.createCheckpoint()
        
        for i in 0..<nodes.count - 1 {
            let n1 = nodes[i]
            let n2 = nodes[i+1]
            
            // distance
            let l1 = CLLocation(latitude: n1.latitude ?? 0, longitude: n1.longitude ?? 0)
            let l2 = CLLocation(latitude: n2.latitude ?? 0, longitude: n2.longitude ?? 0)
            let distKm = l1.distance(from: l2) / 1000.0
            
            // Check if edge exists (findEdge is bidirectional-aware)
            if appState.railroad.network.findEdge(from: n1.id, to: n2.id) == nil {
                let edge = Edge(from: n1.id, to: n2.id, distance: distKm, trackType: .double, maxSpeed: 160)
                appState.railroad.network.addEdge(edge)
            }
        }
    }
    
    private func updateNode(_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil) {
        appState.railroad.network.updateNode(id, lat: lat, lon: lon, alt: alt)
        appState.objectWillChange.send()
    }
    
    private func updateAltitude(_ id: String, alt: Double) {
        appState.railroad.network.createCheckpoint()
        updateNode(id, alt: alt)
    }
}

// MARK: - Intermediate Point View
/// Vista per modificare l'altitudine di punti intermedi (TrackSegment)
struct IntermediatePointView: View {
    let point: CGPoint
    let segment: TrackSegment
    let edge: Edge
    let altRange: Double
    let geoHeight: Double
    var isEditing: Bool = false
    @Binding var editText: String
    var onUpdate: (Double) -> Void
    var onLongPress: () -> Void
    var onCommitEdit: () -> Void
    var onCancelEdit: () -> Void
    var onDelete: () -> Void
    
    @State private var isDragging: Bool = false
    @State private var startAlt: Double = 0
    
    var body: some View {
        ZStack {
            // The draggable point - diamond shape for intermediate points
            Rectangle()
                .fill(isEditing ? Color.yellow : Color.green.opacity(0.8))
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .overlay(
                    Rectangle()
                        .stroke(isEditing ? Color.orange : Color.green, lineWidth: 2)
                        .rotationEffect(.degrees(45))
                )
                .shadow(color: isEditing ? .orange.opacity(0.5) : .black.opacity(0.3), radius: isEditing ? 4 : 2)
                .position(point)
                .onLongPressGesture {
                    onLongPress()
                }
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { val in
                            if !isDragging {
                                isDragging = true
                                startAlt = segment.altitude ?? 0
                            }
                            
                            let effectiveH = geoHeight * 0.8
                            let deltaAlt = -(val.translation.height / effectiveH) * altRange
                            let newAlt = startAlt + deltaAlt
                            onUpdate(newAlt)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            
            // Altitude Editor Popover
            if isEditing {
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text("Punto Intermedio")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: onCancelEdit) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Altitude input
                    HStack(spacing: 4) {
                        TextField("Quota", text: $editText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Actions
                    HStack(spacing: 8) {
                        Button(action: onCommitEdit) {
                            Label("Applica", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        
                        Button(action: onDelete) {
                            Label("Elimina", systemImage: "trash.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button(action: onCancelEdit) {
                            Label("Annulla", systemImage: "xmark.circle")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                .position(x: point.x, y: point.y - 60)
            }
        }
    }
}

struct FerrovieListPopover: View {
    @EnvironmentObject var appState: AppState
    var onSelect: (Ferrovia) -> Void
    var onCreate: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("Ferrovie")
                    .font(.headline)
                Spacer()
                Button(action: onCreate) {
                    Image(systemName: "plus")
                }
            }
            .padding()
            
            if appState.railroad.network.ferrovie.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Nessuna ferrovia")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Crea una ferrovia per definire un percorso fisico della rete")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(appState.railroad.network.ferrovie) { ferrovia in
                        Button(action: { onSelect(ferrovia) }) {
                           HStack {
                               Circle()
                                   .fill(ferrovia.uiColor)
                                   .frame(width: 8, height: 8)
                               Text(ferrovia.name)
                               Spacer()
                               Text("\(ferrovia.stationIds.count) staz.")
                                   .font(.caption)
                                   .foregroundColor(.secondary)
                           }
                           .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteFerrovia)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    func deleteFerrovia(at offsets: IndexSet) {
        offsets.forEach { index in
            let fer = appState.railroad.network.ferrovie[index]
            if appState.selectedFerroviaId == fer.id {
                appState.selectedFerroviaId = nil
            }
            appState.railroad.network.ferrovie.removeAll { $0.id == fer.id }
        }
    }
}
// MARK: - Ferrovia Inspector List
/// Lista ferrovie per il pannello inspector laterale
struct FerrovieInspectorList: View {
    @EnvironmentObject var appState: AppState
    var onSelect: (Ferrovia) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if appState.railroad.network.ferrovie.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("Nessuna ferrovia")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Seleziona 2 o più stazioni sulla mappa e usa l'icona 'F' per creare una ferrovia")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(appState.railroad.network.ferrovie) { ferrovia in
                            Button(action: {
                                onSelect(ferrovia)
                            }) {
                                HStack(spacing: 12) {
                                    // Color indicator
                                    Circle()
                                        .fill(ferrovia.uiColor)
                                        .frame(width: 12, height: 12)
                                    
                                    // Ferrovia info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ferrovia.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                        
                                        Text("\(ferrovia.stationIds.count) stazioni")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Arrow indicator
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemBackground))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.systemBackground))
    }
}

