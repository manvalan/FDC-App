import SwiftUI
import Combine

struct VerticalTrackDiagramView: View {
    @EnvironmentObject var appState: AppState
    @Binding var line: TrainRoute
    @ObservedObject var network: RailwayNetwork
    @Binding var isMoveModeEnabled: Bool
    
    @Binding var externalSelectedStationID: String?
    @Binding var externalSelectedEdgeID: String?

    // State for local sheets (fallback)
    @State private var internalSelectedStationID: String? = nil
    @State private var internalSelectedEdgeID: IdentifiableUUID? = nil
    
    @Binding var isSidebarEditMode: Bool
    @State private var stationToLinkTo: String? = nil
    @State private var isLinkingBefore: Bool = false
    @State private var showStationPicker: Bool = false
    
    // Export State
    @State private var isExporting: Bool = false
    @State private var exportFormat: ExportFormat = .jpeg
    
    // For auto-scrolling
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    // For inserting intermediate stations
    @State private var isInsertingIntermediate: Bool = false
    @State private var insertAfterStationId: String? = nil
    @State private var intermediatePath: [String] = [] // Path being built
    @State private var showIntermediateStationPicker: Bool = false
    
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                diagramContent
            }
            .overlay(alignment: .topTrailing) {
                HStack(alignment: .top) {
                    editOverlay
                    sideToolbar
                }
                .padding()
            }
            .sheet(isPresented: $showStationPicker) {
                stationPickerSheetContent
            }
            .sheet(isPresented: $showIntermediateStationPicker) {
                intermediateStationPickerContent
            }
            .onChange(of: line.id) { _ in
                // Exit edit mode and clear link state when switching lines
                isSidebarEditMode = false
                stationToLinkTo = nil
            }
        }
    }
    
    @ViewBuilder
    private var diagramContent: some View {
        let lineColor = Color(hex: line.color ?? "") ?? .black
        
        ScrollView(.vertical, showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Use stops with unique IDs to avoid ForEach identity issues
                    ForEach(Array(line.stationIds.enumerated()), id: \.offset) { index, stationId in
                        stationStep(stationId: stationId, index: index, lineColor: lineColor)
                            .id("station-\(stationId)")
                    }
                }
                .padding()
                .contentShape(Rectangle()) // Make entire area tappable
                .onLongPressGesture {
                    print("✏️ [EDIT] Long press detected on diagram")
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation(.spring()) {
                        isSidebarEditMode.toggle()
                    }
                    print("✏️ [EDIT] Edit mode now: \(isSidebarEditMode)")
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
        .background(appState.theme.background)
        .onChange(of: externalSelectedStationID) { newStationId in
            if let stationId = newStationId, let proxy = scrollProxy {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("station-\(stationId)", anchor: .center)
                    }
                }
            }
        }
        .onChange(of: externalSelectedEdgeID) { newEdgeId in
            if let edgeId = newEdgeId,
               let edge = network.edges.first(where: { $0.id.uuidString == edgeId }),
               let proxy = scrollProxy {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("station-\(edge.from)", anchor: .center)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func stationStep(stationId: String, index: Int, lineColor: Color) -> some View {
        let isFirst = index == 0
        let isLast = index == line.stationIds.count - 1
        let isExtremity = isFirst || isLast
        let nextId = isLast ? nil : line.stationIds[index + 1]
        
        // In TrainRoute we don't store dwell, we assume 0 is transit for diagram purposes? 
        // Or we just don't show transit style for now.
        let isTransit = false 
        
        // Only allow deleting extremity stations (first or last)
        let onDeleteAction: (() -> Void)? = (isSidebarEditMode && isExtremity) ? { 
            print("🔴 [ACTION] Delete action triggered for station: \(stationId)")
            removeStation(at: index) 
        } : nil
        let onInsertBeforeAction: (() -> Void)? = (isSidebarEditMode && isFirst) ? { prepareInsert(stationId, before: true) } : nil
        let onInsertAfterAction: (() -> Void)? = (isSidebarEditMode && isLast) ? { prepareInsert(stationId, before: false) } : nil

        return ZStack(alignment: .leading) {
            VerticalDiagramStep(
                stationId: stationId,
                network: network,
                isLast: isLast,
                nextStationId: nextId,
                lineColor: lineColor,
                isTransit: isTransit,
                isEditing: isSidebarEditMode,
                onDelete: onDeleteAction,
                onInsertBefore: onInsertBeforeAction,
                onInsertAfter: onInsertAfterAction,
                onStationTap: {
                    print("🔘 [UI] VerticalTrackDiagramView: Station tapped -> \(stationId)")
                    externalSelectedStationID = stationId
                },
                onSegmentTap: {
                    if let nextId = nextId, let edge = findEdge(from: stationId, to: nextId) {
                        print("🔘 [UI] VerticalTrackDiagramView: Segment tapped -> \(edge.id)")
                        externalSelectedEdgeID = edge.id.uuidString
                    } else {
                        print("🔘 [UI] VerticalTrackDiagramView: Segment tapped but NO EDGE found from \(stationId) to \(nextId ?? "nil")")
                    }
                },
                leadingInfo: { EmptyView() }
            )
                
                // Add intermediate station insertion button
                if isSidebarEditMode && !isLast {
                    Button(action: {
                        startIntermediateInsertion(afterStation: stationId)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .background(Circle().fill(Color(UIColor.systemGray5)))
                    }
                    .padding(.leading, 8)
                    .offset(y: 40) // Position on the track segment
                }
        }
    }
    
    @ViewBuilder
    private var editOverlay: some View {
        if isSidebarEditMode {
            editModeDoneButton
                .padding()
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    
    @ViewBuilder
    private var sideToolbar: some View {
        VStack(spacing: 8) {
            // Export Buttons
            Button(action: { exportDiagram(as: .jpeg) }) {
                RailwayInteractionIcon(systemName: "photo", isActive: false, color: .white)
            }
            Button(action: { exportDiagram(as: .pdf) }) {
                RailwayInteractionIcon(systemName: "doc.text", isActive: false, color: .white)
            }
            Button(action: { printDiagram() }) {
                RailwayInteractionIcon(systemName: "printer", isActive: false, color: .white)
            }
        }
        .padding(6)
        .background(Color.gray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var editModeDoneButton: some View {
        Button(action: { withAnimation { isSidebarEditMode = false } }) {
            Text("done".localized)
                .bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    // MARK: - Export Logic
    
    @MainActor
    private func exportDiagram(as format: ExportFormat) {
        let snapshot = diagramSnapshot.environmentObject(appState).environmentObject(network).padding(40).background(Color.white)
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 3.0
        
        if format == .jpeg {
            if let image = renderer.uiImage {
                shareItem(image)
            }
        } else {
            let pdfUrl = FileManager.default.temporaryDirectory.appendingPathComponent("Diagramma_\(line.name).pdf")
            renderer.render { size, context in
                var box = CGRect(origin: .zero, size: size)
                guard let consumer = CGDataConsumer(url: pdfUrl as CFURL),
                      let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
                pdfContext.beginPDFPage(nil)
                context(pdfContext)
                pdfContext.endPDFPage()
                pdfContext.closePDF()
            }
            shareItem(pdfUrl)
        }
    }
    
    @MainActor
    private func printDiagram() {
        let snapshot = diagramSnapshot.environmentObject(appState).environmentObject(network).padding(40).background(Color.white)
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 2.0
        if let image = renderer.uiImage {
             let printInfo = UIPrintInfo(dictionary: nil)
             printInfo.outputType = .general
             printInfo.jobName = "Diagramma \(line.name)"
             
             let controller = UIPrintInteractionController.shared
             controller.printInfo = printInfo
             controller.printingItem = image
             controller.present(animated: true, completionHandler: nil)
        }
    }
    
    private var diagramSnapshot: some View {
        let lineColor = Color(hex: line.color ?? "") ?? .black
        return VStack(spacing: 0) {
            ForEach(Array(line.stationIds.enumerated()), id: \.offset) { index, stationId in
                stationStep(stationId: stationId, index: index, lineColor: lineColor)
            }
        }
        .padding()
        .background(Color.white) // Use white background for exports
        .environment(\.colorScheme, .light)
    }

    private func shareItem(_ item: Any) {
        let av = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            av.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            root.present(av, animated: true, completion: nil)
        }
    }
    
    // MARK: - Sheet Helpers
    
    private var stationIDBinding: Binding<IdentifiableString?> {
        Binding(
            get: { internalSelectedStationID.map { IdentifiableString(id: $0) } },
            set: { internalSelectedStationID = $0?.id }
        )
    }
    
    @ViewBuilder
    private func stationSheetContent(for id: String) -> some View {
        if let index = network.nodes.firstIndex(where: { $0.id == id }) {
            StationEditView(station: $network.nodes[index], isMoveModeEnabled: $isMoveModeEnabled)
        }
    }
    
    @ViewBuilder
    private var stationPickerSheetContent: some View {
        StationPickerView(
            selectedStationId: Binding(
                get: { "" },
                set: { newNodeId in
                    if !newNodeId.isEmpty {
                        if let linkId = stationToLinkTo {
                            insertStation(newNodeId, linkTo: linkId, before: isLinkingBefore)
                        }
                        showStationPicker = false
                    }
                }
            ),
            linkedToStationId: stationToLinkTo
        )
        .environmentObject(network)
    }
    
    @ViewBuilder
    private var intermediateStationPickerContent: some View {
        NavigationStack {
            VStack {
                // Show current path
                if !intermediatePath.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("current_path".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            ForEach(intermediatePath, id: \.self) { stationId in
                                if let node = network.nodes.first(where: { $0.id == stationId }) {
                                    Text(node.name)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                if stationId != intermediatePath.last {
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // List of connected stations
                if let lastStationId = intermediatePath.last {
                    List {
                        ForEach(getConnectedStations(from: lastStationId)) { station in
                            Button(action: {
                                selectIntermediateStation(station.id)
                            }) {
                                HStack {
                                    Text(station.name)
                                    Spacer()
                                    // Indicate if station is already in line
                                    if line.stationIds.contains(station.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("in_line".localized)
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("select_intermediate_station".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        cancelIntermediateInsertion()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func edgeSheetContent(for uuid: UUID) -> some View {
        if let idx = network.edges.firstIndex(where: { $0.id == uuid }) {
            NavigationStack {
                TrackEditView(
                    edge: $network.edges[idx],
                    onDelete: {
                        network.edges.remove(at: idx)
                        internalSelectedEdgeID = nil
                    },
                    onBack: {
                        internalSelectedEdgeID = nil
                    }
                )
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @ViewBuilder
    private func infoColumn(stationId: String, index: Int, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) { // Tighter spacing
            // Station Name
            if let node = network.nodes.first(where: { $0.id == stationId }) {
                Button(action: {
                    internalSelectedStationID = stationId
                }) {
                    Text(node.name)
                        .font(.system(size: 12, weight: .semibold)) 
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.primary)
                }
            } else {
                Text(stationId).font(.caption)
            }
            
            // Distance Info
            if !isLast {
                let nextId = line.stationIds[index + 1]
                if let edge = findEdge(from: stationId, to: nextId) {
                    Button(action: {
                        prepareEditEdge(edge)
                    }) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(String(format: "%.1f", edge.distance)) km")
                                .font(.caption) 
                                .foregroundColor(.blue)
                            HStack {
                                Image(systemName: "speedometer")
                                Text("\(edge.maxSpeed) km/h")
                            }
                            .font(.system(size: 9)) 
                            .foregroundColor(.secondary)
                            
                            let trackTypeText = edge.trackType.rawValue.capitalized
                            let _ = print("📝 [DISPLAY] Rendering track type text: '\(trackTypeText)' for edge \(edge.id)")
                            
                            Text(trackTypeText)
                                .font(.system(size: 10))
                                .padding(2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 8) 
                    }
                    .id(edge.id)  // Force SwiftUI to recreate when edge changes
                }
            }
        }
        .padding(.top, 0)
    }
    
    private func prepareEditEdge(_ edge: Edge) {
        internalSelectedEdgeID = IdentifiableUUID(id: edge.id)
    }
    
    @ViewBuilder
    private func stationNodeButton(id: String) -> some View {
        Button(action: {
            internalSelectedStationID = id
        }) {
            StationNodeSymbol(
                node: network.nodes.first(where: { $0.id == id }),
                defaultColor: .black,
                size: 10
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func trackSegmentButton(from: String, to: String, color: Color) -> some View {
        if let edge = findEdge(from: from, to: to) {
            Button(action: {
                prepareEditEdge(edge)
            }) {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Spacer()
                        RouteTrackSegment(trackType: edge.trackType, color: color)
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            // Missing edge fallback
            DashedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                .foregroundColor(color.opacity(0.3))
                .frame(width: 1)
        }
    }
    
    
    private func findEdge(from: String, to: String) -> Edge? {
        let allMatches = network.edges.filter { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }
        
        if allMatches.isEmpty {
            print("🟦 [EDGE] No edge found from '\(from)' to '\(to)'")
            return nil
        }
        
        if allMatches.count > 1 {
            print("⚠️ [EDGE] WARNING: Found \(allMatches.count) edges from '\(from)' to '\(to)':")
            for (idx, edge) in allMatches.enumerated() {
                print("⚠️ [EDGE]   [\(idx)]: type=\(edge.trackType.rawValue), distance=\(edge.distance)km, id=\(edge.id)")
            }
        }
        
        let edge = allMatches.first!
        print("🟦 [EDGE] Using edge from '\(from)' to '\(to)': type=\(edge.trackType.rawValue), distance=\(edge.distance)km")
        return edge
    }
    
    // MARK: - Inline Editing Logic
    
    private func removeStation(at index: Int) {
        guard index < line.stationIds.count else { return }
        withAnimation {
            line.stationIds.remove(at: index)
            
            // Update origin/destination if necessary
            if line.stationIds.isEmpty {
                 line.originStationId = ""
                 line.destinationStationId = ""
            } else {
                 line.originStationId = line.stationIds.first ?? ""
                 line.destinationStationId = line.stationIds.last ?? ""
            }
            network.objectWillChange.send()
        }
    }
    
    private func prepareInsert(_ stationId: String, before: Bool) {
        stationToLinkTo = stationId
        isLinkingBefore = before
        showStationPicker = true
    }
    
    private func insertStation(_ newStationId: String, linkTo stationId: String, before: Bool) {
        stationToLinkTo = nil
        showStationPicker = false
        
        withAnimation {
            if before {
                line.stationIds.insert(newStationId, at: 0)
            } else {
                line.stationIds.append(newStationId)
            }
            
            // Update origin/destination
            if let first = line.stationIds.first { line.originStationId = first }
            if let last = line.stationIds.last { line.destinationStationId = last }
            
            network.objectWillChange.send()
        }
    }
    
    // MARK: - Intermediate Station Insertion
    
    private func startIntermediateInsertion(afterStation stationId: String) {
        print("➕ [INTERMEDIATE] Starting insertion after: \(stationId)")
        insertAfterStationId = stationId
        intermediatePath = [stationId]
        isInsertingIntermediate = true
        showIntermediateStationPicker = true
    }
    
    private func getConnectedStations(from stationId: String) -> [Node] {
        let connectedEdges = network.edges.filter { $0.from == stationId || $0.to == stationId }
        let connectedStationIds = connectedEdges.flatMap { [$0.from, $0.to] }.filter { $0 != stationId }
        return network.nodes.filter { connectedStationIds.contains($0.id) }
    }
    
    private func selectIntermediateStation(_ stationId: String) {
        guard let _ = intermediatePath.last else { return }
        print("➕ [INTERMEDIATE] Selected: \(stationId), current path: \(intermediatePath)")
        
        if let targetIndex = line.stationIds.firstIndex(where: { $0 == stationId }),
           let startIndex = line.stationIds.firstIndex(where: { $0 == (insertAfterStationId ?? "") }),
           targetIndex != startIndex {
            completeIntermediateInsertion(targetStationId: stationId, targetIndex: targetIndex)
        } else {
            intermediatePath.append(stationId)
            showIntermediateStationPicker = true
        }
    }
    
    private func completeIntermediateInsertion(targetStationId: String, targetIndex: Int) {
        guard let startStationId = insertAfterStationId,
              let startIndex = line.stationIds.firstIndex(where: { $0 == startStationId }) else {
            print("❌ [INTERMEDIATE] Cannot find start station")
            cancelIntermediateInsertion()
            return
        }
        
        withAnimation {
            // Remove all stations between start and target (exclusive)
            let removeStart = min(startIndex, targetIndex) + 1
            let removeEnd = max(startIndex, targetIndex)
            
            if removeStart < removeEnd {
                line.stationIds.removeSubrange(removeStart..<removeEnd)
            }
            
            // Insert intermediate stations (excluding start and target station)
            let intermediateStations = Array(intermediatePath.dropFirst())
            
            var insertIndex = min(startIndex, targetIndex) + 1
            for stationId in intermediateStations {
                line.stationIds.insert(stationId, at: insertIndex)
                insertIndex += 1
            }
            
            // Update origin/destination
            if let first = line.stationIds.first { line.originStationId = first }
            if let last = line.stationIds.last { line.destinationStationId = last }
            
            network.objectWillChange.send()
        }
        
        cancelIntermediateInsertion()
    }
    
    private func cancelIntermediateInsertion() {
        isInsertingIntermediate = false
        insertAfterStationId = nil
        intermediatePath = []
        showIntermediateStationPicker = false
    }
}
