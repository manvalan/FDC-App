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

}

// MARK: - Altimetric Profile View
