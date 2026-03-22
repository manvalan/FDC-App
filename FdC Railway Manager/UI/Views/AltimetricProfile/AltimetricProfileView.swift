import Foundation
import Combine
import SwiftUI
import MapKit
import CoreLocation

struct AltimetricProfileView: View {
    @EnvironmentObject var appState: AppState
 
    /// Vista del profilo altimetrico.
    /// Permette di visualizzare e modificare le quote dei nodi lungo un percorso.

    @Binding var lockedNodeIds: Set<String>
    
    @State private var altitudeEditNodeId: String? = nil
    @State private var altitudeEditText: String = ""
    @State private var horizontalScale: CGFloat = 0.5  // Start with compact scale to show entire line
    @State private var verticalScale: CGFloat = 1.0    // Scale for vertical zoom (altitude)
    
    private let renderer = RailwayRenderer()
    
    private var selectedFerroviaId: String? {
        get { appState.selectedInfraLineId }
        nonmutating set { appState.selectedInfraLineId = newValue }
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
        
        static func from(_ route: TrainRoute) -> SlopeLimit {
            let name = route.name.lowercased()
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
                ForEach(appState.railroad.network.lines) { ferrovia in
                    Button(ferrovia.name) {
                        selectedFerroviaId = ferrovia.id
                        appState.selectedRouteId = nil
                        appState.selectedNodeId = nil
                        appState.selectedEdgeId = nil
                        appState.selectedNodeIds = Set(ferrovia.nodeIds)
                    }
                }
            } label: {
                HStack {
                    if let fId = selectedFerroviaId, let f = appState.railroad.network.lines.first(where: { $0.id == fId }) {
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
            
            if let routeId = appState.selectedRouteId,
               let route = appState.railroad.lines.findRoute(id: routeId) {
                let limit = SlopeLimit.from(route)
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
        let fId = appState.selectedInfraLineId
        let routeId = appState.selectedRouteId
        let selectedNodeIds = appState.selectedNodeIds
        let edgeId = appState.selectedEdgeId
        
        let stations: [RailwayNode] = {
            if let fId = fId, let fer = appState.railroad.network.lines.first(where: { $0.id == fId }) {
                // For infrastructure lines, rebuild complete path including junction nodes
                let service = InfrastructureService(network: appState.railroad.network)
                var completePath: [RailwayNode] = []
                
                for i in 0..<fer.nodeIds.count {
                    let nodeId = fer.nodeIds[i]
                    guard let station = appState.railroad.network.nodes.first(where: { $0.id == nodeId }) else {
                        continue
                    }
                    
                    if i == 0 {
                        // First station
                        completePath.append(station)
                    } else {
                        // Find path from previous station to this one (includes junctions)
                        let prevNodeId = fer.nodeIds[i - 1]
                        
                        if let pathResult = service.findPath(from: prevNodeId, to: nodeId) {
                            // Add all nodes from path except the first (already in completePath)
                            completePath.append(contentsOf: pathResult.nodes.dropFirst())
                        } else {
                            // No path found, just add the station anyway
                            completePath.append(station)
                        }
                    }
                }
                
                return completePath
            } else if let rId = routeId, let route = appState.railroad.lines.findRoute(id: rId) {
                return route.stationIds.compactMap { stationId in appState.railroad.network.nodes.first(where: { $0.id == stationId }) }
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
    
    // MARK: - Grafico del Profilo
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
        
        let altitudePoints = pointsData.compactMap { pd -> AltitudePoint? in
            guard let nodeId = pd.nodeId,
                  let node = appState.railroad.network.nodes.first(where: { $0.id == nodeId }) else {
                return nil
            }
            return AltitudePoint(
                id: nodeId,
                nodeId: nodeId,
                distance: pd.cumulativeDistance,
                altitude: getAltitudeForPoint(pd),
                isStation: pd.isStation,
                node: node
            )
        }
        
        ZStack {
            // Background
            Color.white
                .frame(width: graphWidth, height: geo.size.height)
            
            // Grid background from renderer
            renderer.renderAltimetricProfile(
                points: altitudePoints,
                in: geo,
                style: .default,
                pixelsPerKm: scaledPixelsPerKm,
                minAltitude: minAlt,
                altitudeRange: altRange
            )
            .frame(width: graphWidth)
            
            // Custom label overlays (since renderer's ones might be too simple)
            ForEach(0..<pointsData.count - 1, id: \.self) { i in
                let p1 = pointsData[i]
                let p2 = pointsData[i+1]
                let alt1 = getAltitudeForPoint(p1)
                let alt2 = getAltitudeForPoint(p2)
                let distKm = abs(p2.cumulativeDistance - p1.cumulativeDistance)
                let slope = distKm > 0 ? (alt2 - alt1) / distKm : 0
                
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
            appState.railroad.addEdge(edgeAJ)
            appState.railroad.addEdge(edgeJB)
        }
        
        for oldEdge in edgesBackward {
            let edgeBJ = RailwayEdge(from: nodeId2, to: junctionNode.id, distance: distFromNode2, trackType: oldEdge.trackType, maxSpeed: oldEdge.maxSpeed)
            let edgeJA = RailwayEdge(from: junctionNode.id, to: nodeId1, distance: distFromNode1, trackType: oldEdge.trackType, maxSpeed: oldEdge.maxSpeed)
            appState.railroad.addEdge(edgeBJ)
            appState.railroad.addEdge(edgeJA)
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
