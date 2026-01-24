import SwiftUI

struct VerticalTrackDiagramView: View {
    let line: RailwayLine
    @ObservedObject var network: RailwayNetwork
    
    // State for sheet presentation
    @State private var selectedStationID: String? = nil
    @State private var selectedEdgeID: IdentifiableUUID? = nil
    
    var body: some View {
        let lineColor = Color(hex: line.color ?? "") ?? .black
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: -20) {
                ForEach(Array(line.stations.enumerated()), id: \.offset) { index, stationId in
                    let isLast = index == line.stations.count - 1
                    
                    HStack(alignment: .top, spacing: 20) {
                        // Left: Diagram Column
                        VStack(spacing: -20) {
                            // Station Node
                            stationNodeButton(id: stationId)
                                .zIndex(1)
                            
                            // Track Segment (if not last)
                            if !isLast {
                                let nextId = line.stations[index + 1]
                                trackSegmentButton(from: stationId, to: nextId, color: lineColor)
                                    .frame(height: 80) // Increased height for overlap
                            }
                        }
                        .frame(width: 60)
                        
                        // Right: Info Column
                        infoColumn(stationId: stationId, index: index, isLast: isLast)
                        
                        Spacer()
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .border(Color.gray.opacity(0.2), width: 1)
        // Helper extension to bind String? to Item
        .sheet(item: Binding(
            get: { selectedStationID.map { StringIdentifiable(id: $0) } },
            set: { selectedStationID = $0?.id }
        )) { item in
            if let index = network.nodes.firstIndex(where: { $0.id == item.id }) {
                   StationEditView(station: $network.nodes[index])
            }
        }
        .sheet(item: $selectedEdgeID) { wrapper in
             // Use ID to find edge.
             if let idx = network.edges.firstIndex(where: { $0.id == wrapper.id }) {
                TrackEditView(edge: $network.edges[idx]) {
                    network.edges.remove(at: idx)
                    selectedEdgeID = nil
                    // Note: Line geometry might need update if edge is critical, 
                    // but visual diagram will just show dashed line next update.
                }
             }
        }
    }
    
    @ViewBuilder
    private func infoColumn(stationId: String, index: Int, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) { // Tighter spacing
            // Station Name
            if let node = network.nodes.first(where: { $0.id == stationId }) {
                Button(action: {
                    selectedStationID = stationId
                }) {
                    Text(node.name)
                        .font(.system(size: 14, weight: .semibold)) // Reduced from 18 bold
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.primary)
                }
            } else {
                Text(stationId).font(.caption)
            }
            
            // Distance Info
            if !isLast {
                let nextId = line.stations[index + 1]
                if let edge = findEdge(from: stationId, to: nextId) {
                    Button(action: {
                        prepareEditEdge(edge)
                    }) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(String(format: "%.1f", edge.distance)) km")
                                .font(.subheadline) // Reduced from headline
                                .foregroundColor(.blue)
                            HStack {
                                Image(systemName: "speedometer")
                                Text("\(edge.maxSpeed) km/h")
                            }
                            .font(.caption2) // Reduced from caption
                            .foregroundColor(.secondary)
                            
                            Text(edge.trackType.rawValue.capitalized)
                                .font(.system(size: 10))
                                .padding(2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 8) 
                    }
                }
            }
        }
        .padding(.top, 0)
    }
    
    private func prepareEditEdge(_ edge: Edge) {
        selectedEdgeID = IdentifiableUUID(id: edge.id)
    }
    
    @ViewBuilder
    private func stationNodeButton(id: String) -> some View {
        Button(action: {
            selectedStationID = id
        }) {
            if let node = network.nodes.first(where: { $0.id == id }) {
                let color = Color(hex: node.customColor ?? "") ?? (node.type == .interchange ? .red : .black)
                let type = node.visualType ?? (node.type == .interchange ? .filledSquare : .filledCircle)
                
                ZStack {
                    Circle().fill(Color.white).frame(width: 24, height: 24) // Reduced from 40
                    symbolView(type: type, color: color)
                        .frame(width: 16, height: 16) // Reduced from 30
                }
            } else {
                Circle().fill(Color.gray).frame(width: 12, height: 12)
            }
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
                    HStack(spacing: 2) {
                        Spacer()
                        // Draw lines based on track type
                        if edge.trackType == .double || edge.trackType == .highSpeed {
                            Rectangle().fill(color).frame(width: 2) // Reduced from 4
                            Rectangle().fill(color).frame(width: 2)
                        } else {
                            Rectangle().fill(color).frame(width: 4) // Reduced from 8
                        }
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
    
    @ViewBuilder
    func symbolView(type: Node.StationVisualType, color: Color) -> some View {
        switch type {
        case .filledSquare:
            Image(systemName: "square.fill").resizable().foregroundStyle(color)
        case .emptySquare:
            Image(systemName: "square").resizable().foregroundStyle(color).fontWeight(.bold)
        case .filledCircle:
            Image(systemName: "circle.fill").resizable().foregroundStyle(color)
        case .emptyCircle:
            Image(systemName: "circle").resizable().foregroundStyle(color).fontWeight(.bold)
        case .filledStar:
            Image(systemName: "star.fill").resizable().foregroundStyle(color)
        }
    }
    
    private func findEdge(from: String, to: String) -> Edge? {
        return network.edges.first { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

struct StringIdentifiable: Identifiable {
    let id: String
}

struct IdentifiableUUID: Identifiable {
    let id: UUID
}
