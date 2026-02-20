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
    
    @State private var showLineList = false
    @State private var lockedNodeIds: Set<String> = []
    @State private var isShowingLineCreation = false
    @State private var editingLineId: String? = nil
    
    // Altimetry State
    // REMOVED local isCreatingTrackMode to sync with appState
    
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                // Main Content + Bottom Panel
                VStack(spacing: 0) {
// Main Map Area with Toolbar
                    ZStack(alignment: .topTrailing) {
                        // Main Map
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
                        .overlay(alignment: .top) {
                            editorToolbar
                                .padding(.top, 16)
                        }
                        .overlay(alignment: .leading) {
                            verticalToolbox
                                .padding(.leading, 16)
                        }
                    }
                    
                    // Bottom Panel: Altimetric Profile
                    let showProfile = (appState.selectedLineId != nil) || (appState.selectedEdgeId != nil) || (appState.selectedNodeId != nil) || (appState.selectedNodeIds.count > 1)
                    FdCBottomPanel(
                        isPresented: .constant(showProfile),
                        title: "Profilo Altimetrico",
                        preferredHeight: 300
                    ) {
                        AltimetricProfileView(lockedNodeIds: $lockedNodeIds)
                    }
                }
                
                // Inspector Panel (right side)
                if appState.selectedNodeId != nil || appState.selectedEdgeId != nil || appState.selectedLineId != nil || appState.selectedFerroviaId != nil {
                    FdCInspectorPanel(
                        title: inspectorTitle,
                        onClose: {
                            appState.selectedNodeId = nil
                            appState.selectedEdgeId = nil
                            appState.selectedLineId = nil
                            selectedFerroviaId = nil
                        }
                    ) {
                        StationPropertyEditor(editingLineId: $editingLineId)
                    }
                    .frame(width: 320)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            #if os(macOS)
            .onDeleteCommand {
                deleteSelectedItems()
            }
            #endif
        }
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
        .onDisappear {
            loader.saveCurrentState()
        }
    }
    
    // MARK: - Inspector Title
    
    private var inspectorTitle: String {
        if let node = appState.selectedNode {
            return node.name ?? "Stazione"
        } else if let fId = selectedFerroviaId,
                  let ferrovia = appState.railroad.network.ferrovie.first(where: { $0.id == fId }) {
            return ferrovia.name
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
        var items: [FdCToolbarItem] = [
            .custom(id: "ferrovie-list", content: AnyView(
                Button(action: { showLineList.toggle() }) {
                    Label("Gestisci Ferrovie", systemImage: "tray.full.fill")
                        .font(.headline)
                }
                .popover(isPresented: $showLineList) {
                    FerrovieListPopover(onSelect: { ferrovia in
                        withAnimation(.spring()) {
                            appState.selectedFerroviaId = ferrovia.id
                            appState.selectedLineId = nil
                            appState.selectedNodeId = nil
                            appState.selectedEdgeId = nil
                            appState.selectedNodeIds = Set(ferrovia.stationIds)
                            showLineList = false
                        }
                    }, onCreate: {
                        createNewFerrovia()
                    })
                    .frame(minWidth: 320, minHeight: 400)
                }
            )),
            .divider,
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
            
            if appState.railroad.network.findEdge(from: n2.id, to: n1.id) == nil {
                let edgeRev = Edge(from: n2.id, to: n1.id, distance: distKm, trackType: .double, maxSpeed: 160)
                appState.railroad.network.addEdge(edgeRev)
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
        let newFerrovia = Ferrovia(
            name: "Ferrovia \(count)",
            color: ["#3498db", "#e74c3c", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c"][count % 6],
            stationIds: stations
        )
        appState.railroad.network.ferrovie.append(newFerrovia)
        appState.selectedFerroviaId = newFerrovia.id
        appState.selectedNodeIds = Set(newFerrovia.stationIds)
        appState.selectedNodeIdsOrder = Array(newFerrovia.stationIds)
        appState.showPanel(.inspector)
        appState.objectWillChange.send()
    }
    
    private func createStation() {
        let id = "ST-\(Int.random(in: 1000...9999))"
        // Center of the current bounds or a default location
        // Roughly center of Italy as default if no context
        // Add slight random offset to avoid exact overlap
        let latOffset = Double.random(in: -0.02...0.02)
        let lonOffset = Double.random(in: -0.02...0.02)
        
        let newStation = Node(
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
    
    private func handleNodeSelection(_ node: Node?) {
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
        var newEdge = Edge(from: from, to: to, distance: distance, trackType: .regional, maxSpeed: 140)
        
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

struct StationPropertyEditor: View {
    @EnvironmentObject var appState: AppState
    @Binding var editingLineId: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let node = appState.selectedNode {
                    stationEditor(node: node)
                } else if let edgeId = appState.selectedEdgeId,
                          let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }) {
                    edgeEditor(edge: edge)
                } else if let ferroviaId = appState.selectedFerroviaId,
                          let ferrovia = appState.railroad.network.ferrovie.first(where: { $0.id == ferroviaId }) {
                    ferroviaEditor(ferrovia: ferrovia)
                } else {
                    Text("Seleziona una ferrovia, stazione o binario per modificare le proprietà fisiche.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func stationEditor(node: Node) -> some View {
        GroupBox(label: Label("Posizione", systemImage: "location.circle")) {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Text("Latitudine")
                        TextField("0.0", value: Binding(
                            get: { node.latitude ?? 0.0 },
                            set: { appState.railroad.network.updateNode(node.id, lat: $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Longitudine")
                        TextField("0.0", value: Binding(
                            get: { node.longitude ?? 0.0 },
                            set: { appState.railroad.network.updateNode(node.id, lon: $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Altitudine (m)")
                        TextField("0.0", value: Binding(
                            get: { node.altitude ?? 0.0 },
                            set: { appState.railroad.network.updateNode(node.id, alt: $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(8)
        }
        
        GroupBox(label: Label("Configurazione", systemImage: "gearshape")) {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Text("Nome")
                        TextField("Nome Stazione", text: Binding(
                            get: { node.name },
                            set: { newName in
                                if let idx = appState.railroad.network.nodes.firstIndex(where: { $0.id == node.id }) {
                                    appState.railroad.network.nodes[idx].name = newName
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Binari")
                        TextField("2", value: Binding(
                            get: { node.platforms ?? 2 },
                            set: { 
                                if let idx = appState.railroad.network.nodes.firstIndex(where: { $0.id == node.id }) {
                                    appState.railroad.network.nodes[idx].platforms = $0 
                                }
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(8)
        }
        
        // Only show service line associations if NOT in infrastructure editor mode
        if appState.currentMode != .editor && appState.currentMode != .design {
            if let lineId = appState.selectedLineId, let line = appState.railroad.lines.findLine(id: lineId) {
                Divider()
                GroupBox("Linea: \(line.name)") {
                    Button(action: {
                        addStationToLine(node: node, line: line)
                    }) {
                        Label("Aggiungi a Linea", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(line.stations.contains(node.id))
                }
                .padding(8)
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            appState.railroad.network.removeNode(node.id)
            appState.selectedNodeId = nil
            appState.selectedNodeIds.remove(node.id)
        } label: {
            Label("Elimina Stazione", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private func ferroviaEditor(ferrovia: Ferrovia) -> some View {
        GroupBox(label: Label("Dettagli Ferrovia", systemImage: "map")) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Nome Ferrovia", text: Binding(
                    get: { ferrovia.name },
                    set: { newName in
                        if let idx = appState.railroad.network.ferrovie.firstIndex(where: { $0.id == ferrovia.id }) {
                            appState.railroad.network.ferrovie[idx].name = newName
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.headline)
                
                ColorPicker("Colore", selection: Binding(
                    get: { Color(hex: ferrovia.color ?? "#000000") ?? .blue },
                    set: { newColor in
                        if let idx = appState.railroad.network.ferrovie.firstIndex(where: { $0.id == ferrovia.id }) {
                            appState.railroad.network.ferrovie[idx].color = newColor.toHex()
                        }
                    }
                ))
                
                Divider()
                
                Text("Percorso (\(ferrovia.stationIds.count) stazioni)")
                    .font(.caption.bold())
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ferrovia.stationIds, id: \.self) { sid in
                        Text("• \(getNodeName(sid))")
                            .font(.caption)
                    }
                }
            }
            .padding(8)
        }
        
        Button(role: .destructive) {
            appState.railroad.network.ferrovie.removeAll(where: { $0.id == ferrovia.id })
            appState.selectedFerroviaId = nil
        } label: {
            Label("Elimina Ferrovia", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 10)
    }
    
    private func addStationToLine(node: Node, line: RailwayLine) {
        appState.railroad.network.createCheckpoint()
        var updatedLine = line
        let newStop = RelationStop(stationId: node.id, minDwellTime: 1, track: "1")
        updatedLine.stops.append(newStop)
        
        if let idx = appState.railroad.lines.lines.firstIndex(where: { $0.id == line.id }) {
            appState.railroad.lines.lines[idx] = updatedLine
        }
    }

    
    @ViewBuilder
    private func edgeEditor(edge: Edge) -> some View {
        GroupBox(label: Label("Tratta", systemImage: "tram")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Da: \(getNodeName(edge.from))")
                Text("A: \(getNodeName(edge.to))")
                
                Divider()
                
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Text("Lunghezza (km)")
                        TextField("0", value: Binding(
                            get: { edge.distance },
                            set: { appState.railroad.network.updateEdge(edge.id, distance: $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        Text("km")
                        
                        Spacer()
                        
                        Button(action: { appState.railroad.network.generateSegments(for: edge) }) {
                            Label("Rigenera Tratte", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Velocità Max").font(.caption.bold())
                        TextField("0", value: Binding(
                            get: { edge.maxSpeed },
                            set: { appState.railroad.network.updateEdge(edge.id, speed: $0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        Text("km/h")
                        
                        Spacer()
                        
                        Button(role: .destructive, action: { appState.railroad.network.splitEdge(edge) }) {
                            Label("Spezza Binario", systemImage: "scissors")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(8)
        }
        
        // Physical segments editor placeholder
        GroupBox(label: Label("Segmenti Fisici", systemImage: "ruler")) {
             VStack(alignment: .leading, spacing: 8) {
                 Button(action: { appState.railroad.network.splitEdge(edge) }) {
                     Label("Dividi Tratta (Agg. Nodo)", systemImage: "scissors")
                         .frame(maxWidth: .infinity)
                 }
                 .buttonStyle(.borderedProminent)
                 .help("Inserisci un nodo intermedio per modificare l'altimetria puntuale")
                 
                 Divider()
                 
                 if edge.segments.isEmpty {
                     Text("Nessun segmento di velocità definito.")
                         .font(.caption)
                         .foregroundColor(.secondary)
                     Button("Genera Segmenti (2km)") {
                         appState.railroad.network.generateSegments(for: edge)
                     }
                     .buttonStyle(.bordered)
                 } else {
                     ForEach(edge.segments.indices, id: \.self) { i in
                         let seg = edge.segments[i]
                         HStack {
                             Text("Seg \(i+1)")
                                 .font(.caption)
                             Spacer()
                             Text("\(String(format: "%.1f", seg.length)) km")
                                 .font(.caption.monospacedDigit())
                             TextField("Vel", value: Binding(
                                 get: { Double(seg.speedLimit ?? 0) },
                                 set: { appState.railroad.network.updateSegment(edge.id, index: i, speed: $0) }
                             ), format: .number)
                             .frame(width: 50)
                             .textFieldStyle(.roundedBorder)
                             .font(.caption)
                         }
                     }
                 }
             }
             .padding(8)
        }
        
        Divider()
        
        Button(role: .destructive) {
            appState.railroad.network.removeEdge(edge.id)
            appState.selectedEdgeId = nil
        } label: {
            Label("Elimina Binario", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 10)
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
    
    private func calculateSlope(from: Node, to: Node) -> Double {
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
    
    private var selectedFerroviaId: String? {
        get { appState.selectedFerroviaId }
        nonmutating set { appState.selectedFerroviaId = newValue }
    }
    
    private func updateNode(_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil) {
        appState.railroad.network.updateNode(id, lat: lat, lon: lon, alt: alt)
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
        .background(Color.white) // Safe background
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
                    } else {
                        Text("Profilo Altimetrico")
                            .font(.caption.bold())
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
            }
            .menuStyle(.borderlessButton)
            
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
        .background(Color.gray.opacity(0.1))
    }
    
    @ViewBuilder
    private func contentView(geo: GeometryProxy) -> some View {
        if let fId = selectedFerroviaId,
           let ferrovia = appState.railroad.network.ferrovie.first(where: { $0.id == fId }) {
            
            let stations = ferrovia.stationIds.compactMap { sid in
                appState.railroad.network.nodes.first(where: { $0.id == sid })
            }
            profileGraph(stations: stations, geo: geo)
            
        } else if let lineId = appState.selectedLineId,
                  let line = appState.railroad.lines.findLine(id: lineId) {
            
            let stations = line.stops.compactMap { stop in
                appState.railroad.network.nodes.first(where: { $0.id == stop.stationId })
            }
            profileGraph(stations: stations, line: line, geo: geo)
            
        } else if appState.selectedNodeIds.count > 1 {
            // If a ferrovia is selected, preserve its station order
            let currentFerroviaId = selectedFerroviaId
            let stations: [Node] = {
                if let fId = currentFerroviaId,
                   let fer = appState.railroad.network.ferrovie.first(where: { $0.id == fId }) {
                    return fer.stationIds.compactMap { sid in
                        appState.railroad.network.nodes.first(where: { $0.id == sid })
                    }
                }
                return appState.railroad.network.nodes
                    .filter { appState.selectedNodeIds.contains($0.id) }
                    .sorted { ($0.longitude ?? 0) < ($1.longitude ?? 0) }
            }()
            profileGraph(stations: stations, geo: geo)
            
        } else if let edgeId = appState.selectedEdgeId,
                  let edge = appState.railroad.network.edges.first(where: { $0.id.uuidString == edgeId }),
                  let n1 = appState.railroad.network.nodes.first(where: { $0.id == edge.from }),
                  let n2 = appState.railroad.network.nodes.first(where: { $0.id == edge.to }) {
            profileGraph(stations: [n1, n2], geo: geo)
            
        } else if let nodeId = appState.selectedNodeId,
                  let node = appState.railroad.network.nodes.first(where: { $0.id == nodeId }) {
             // Single node logic
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
    
    @ViewBuilder
    private func profileGraph(stations: [Node], line: RailwayLine? = nil, geo: GeometryProxy) -> some View {
        if stations.count < 2 {
             Text("Servono almeno 2 stazioni per il grafico.")
                 .foregroundColor(.secondary)
                 .position(x: geo.size.width/2, y: geo.size.height/2)
        } else {
            // ENHANCED: Try to find a logical chain if it's a multi-selection
            let orderedStations = (line == nil) ? attemptToChain(stations) : stations
            
            let alts = orderedStations.compactMap { $0.altitude }
            let minAlt = alts.min() ?? 0
            let maxAlt = alts.max() ?? 100
            let altRange = max(100, maxAlt - minAlt)
            
            let pointsData = calculatePoints(stations: orderedStations, line: line, geo: geo, minAlt: minAlt, altRange: altRange)
            
            ZStack {
                // Grid with altitude labels
                ForEach(0...4, id: \.self) { i in
                    let y = geo.size.height * 0.1 + CGFloat(i) * (geo.size.height * 0.8 / 4)
                    let altValue = maxAlt - (Double(i) / 4.0) * altRange
                    
                    // Grid line
                    Path { path in
                        path.move(to: CGPoint(x: 40, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    
                    // Altitude label on left
                    Text("\(Int(altValue))m")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .position(x: 20, y: y)
                }
                
                // Segments
                if pointsData.count > 1 {
                    ForEach(0..<pointsData.count - 1, id: \.self) { i in
                        let p1 = pointsData[i]
                        let p2 = pointsData[i+1]
                        let slope = calculateSlope(from: orderedStations[i], to: orderedStations[i+1])
                        
                        Path { path in
                            path.move(to: p1.point)
                            path.addLine(to: p2.point)
                        }
                        .stroke(slopeColor(slope), lineWidth: 3)
                        
                        // Label
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
                
                // Draggable Points
                ForEach(pointsData.indices, id: \.self) { i in
                    let p = pointsData[i]
                    let station = orderedStations[i]
                    
                     DraggablePointView(
                         point: p.point,
                         station: station,
                         altRange: altRange,
                         geoHeight: geo.size.height,
                         isLocked: lockedNodeIds.contains(station.id),
                         isEditing: altitudeEditNodeId == station.id,
                         editText: $altitudeEditText,
                         onUpdate: { newAlt in
                             if !lockedNodeIds.contains(station.id) {
                                 updateNode(station.id, alt: newAlt)
                             }
                         },
                         onLongPress: {
                             altitudeEditText = "\(Int(station.altitude ?? 0))"
                             altitudeEditNodeId = station.id
                         },
                         onCommitEdit: {
                             if let val = Double(altitudeEditText) {
                                 updateNode(station.id, alt: val)
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
                    .help("\(station.name): \(Int(station.altitude ?? 0))m")
                }
                // Click Interaction (Insert Node)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let loc = value.location
                                handleGraphClick(at: loc, pointsData: pointsData, stations: orderedStations, geo: geo, minAlt: minAlt, altRange: altRange)
                            }
                    )
            }
            .padding()
        }
    }
    
    private func handleGraphClick(at location: CGPoint, pointsData: [PointData], stations: [Node], geo: GeometryProxy, minAlt: Double, altRange: Double) {
        guard !pointsData.isEmpty else { return }
        
        // Find the nearest node by horizontal distance
        var bestIdx = 0
        var bestDist: CGFloat = .infinity
        for (i, p) in pointsData.enumerated() {
            let dist = abs(p.point.x - location.x)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }
        
        let station = stations[bestIdx]
        
        // Skip locked nodes
        guard !lockedNodeIds.contains(station.id) else { return }
        
        // Convert Y click position to altitude
        // Formula inverse of: y = geoHeight - (normalizedAlt * geoHeight * 0.8) - (geoHeight * 0.1)
        // normalizedAlt = (geoHeight - y - geoHeight * 0.1) / (geoHeight * 0.8)
        // alt = minAlt + normalizedAlt * altRange
        let effectiveH = geo.size.height * 0.8
        let normalizedAlt = (geo.size.height - location.y - geo.size.height * 0.1) / effectiveH
        let clampedNorm = max(0, min(1, normalizedAlt))
        let newAlt = minAlt + Double(clampedNorm) * altRange
        
        updateNode(station.id, alt: newAlt)
        appState.selectedNodeId = station.id
    }
    
    func splitEdgeAt(_ edge: Edge, ratio: Double) {
        appState.railroad.network.createCheckpoint()
        
        guard let n1 = appState.railroad.network.nodes.first(where: { $0.id == edge.from }),
              let n2 = appState.railroad.network.nodes.first(where: { $0.id == edge.to }) else { return }
        
        // Midpoint (interpolated)
        let lat1 = n1.latitude ?? 0
        let lon1 = n1.longitude ?? 0
        let lat2 = n2.latitude ?? 0
        let lon2 = n2.longitude ?? 0
        
        let newLat = lat1 + (lat2 - lat1) * ratio
        let newLon = lon1 + (lon2 - lon1) * ratio
        
        let alt1 = n1.altitude ?? 0
        let alt2 = n2.altitude ?? 0
        let newAlt = alt1 + (alt2 - alt1) * ratio
        
        let newNodeId = "N-\(Int.random(in: 10000...99999))"
        // name: "" hides it on map (if map respects empty name)
        let newNode = Node(id: newNodeId, name: "", latitude: newLat, longitude: newLon, altitude: newAlt)
        
        // Edges
        let d1 = edge.distance * ratio
        let d2 = edge.distance * (1 - ratio)
        
        let e1 = Edge(from: n1.id, to: newNode.id, distance: d1, trackType: edge.trackType, maxSpeed: edge.maxSpeed)
        let e2 = Edge(from: newNode.id, to: n2.id, distance: d2, trackType: edge.trackType, maxSpeed: edge.maxSpeed)
        
        appState.railroad.network.removeEdge(edge.id)
        appState.railroad.network.nodes.append(newNode)
        appState.railroad.network.edges.append(e1)
        appState.railroad.network.edges.append(e2)
        
        // Select new node so user can edit altitude immediately
        appState.selectedNodeId = newNodeId
        appState.selectedEdgeId = nil
    }
    


    
    // Helpers Wrapper (calling global ones)
    func calculateSlope(from: Node, to: Node) -> Double {
        // We used appState based global one, but need logic here or call global.
        // I'll reimplement briefly to avoid scope issues if global is private.
        guard let alt1 = from.altitude, let alt2 = to.altitude else { return 0 }
        // Distance fallback
        let l1 = CLLocation(latitude: from.latitude ?? 0, longitude: from.longitude ?? 0)
        let l2 = CLLocation(latitude: to.latitude ?? 0, longitude: to.longitude ?? 0)
        // Try find edge
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
    
    private struct PointData {
        let index: Int
        let point: CGPoint
        let nodeId: String
    }
    
    private func calculatePoints(stations: [Node], line: RailwayLine?, geo: GeometryProxy, minAlt: Double, altRange: Double) -> [PointData] {
        var points: [PointData] = []
        guard stations.count >= 2 else { return [] }
        
        var currentDist: Double = 0
        let totalDist = totalDistance(stations: stations, network: appState.railroad.network)
        
        guard totalDist > 0 else { return [] }
        
        for (i, station) in stations.enumerated() {
            if i > 0 {
                let prev = stations[i-1]
                let dist = appState.railroad.network.findEdge(from: prev.id, to: station.id)?.distance ?? 0
                currentDist += dist
            }
            
            let alt = station.altitude ?? 0
            
            let x = (currentDist / totalDist) * geo.size.width
            let normalizedAlt = CGFloat(alt - minAlt) / CGFloat(altRange)
            let y = geo.size.height - (normalizedAlt * geo.size.height * 0.8) - (geo.size.height * 0.1)
            
            points.append(PointData(index: i, point: CGPoint(x: x, y: y), nodeId: station.id))
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
        var dist = 0.0
        for i in 0..<stations.count - 1 {
            dist += network.findEdge(from: stations[i].id, to: stations[i+1].id)?.distance ?? 0
        }
        return dist
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
                .fill(isLocked ? Color.red : (isEditing ? Color.yellow : Color.white))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(isEditing ? Color.orange : Color.blue, lineWidth: 2))
                .overlay(
                    ZStack {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        }
                    }
                )
                .shadow(color: isEditing ? .orange.opacity(0.5) : .black.opacity(0.2), radius: isEditing ? 4 : 1)
                .position(point)
                .gesture(
                    isLocked ? nil : DragGesture()
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
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            onLongPress()
                        }
                )
            
            // Altitude Editor Popover
            if isEditing {
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text(station.name.isEmpty ? "Nodo" : station.name)
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
            
            // Check if edges exist
            let edgeForward = appState.railroad.network.findEdge(from: n1.id, to: n2.id)
            if edgeForward == nil {
                let edge = Edge(from: n1.id, to: n2.id, distance: distKm, trackType: .double, maxSpeed: 160)
                appState.railroad.network.addEdge(edge)
            }
            
             if appState.railroad.network.findEdge(from: n2.id, to: n1.id) == nil {
                 let edgeRev = Edge(from: n2.id, to: n1.id, distance: distKm, trackType: .double, maxSpeed: 160)
                 appState.railroad.network.addEdge(edgeRev)
             }
        }
    }
    
    private func updateNode(_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil) {
        if let idx = appState.railroad.network.nodes.firstIndex(where: { $0.id == id }) {
            var node = appState.railroad.network.nodes[idx]
            if let lat = lat { node.latitude = lat }
            if let lon = lon { node.longitude = lon }
            if let alt = alt { node.altitude = alt }
            appState.railroad.network.nodes[idx] = node
        }
    }
    
    private func updateAltitude(_ id: String, alt: Double) {
        appState.railroad.network.createCheckpoint()
        updateNode(id, alt: alt)
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
            }
        }
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
