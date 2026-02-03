import SwiftUI

struct InteractionIcon: View {
    var systemName: String
    var isActive: Bool
    var activeColor: Color = .blue
    var color: Color = .primary
    
    var body: some View {
        Image(systemName: systemName)
            .font(.title3)
            .padding(10)
            .background(isActive ? activeColor : Color.clear)
            .foregroundColor(isActive ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 🎨 **RailwaySharedVisualization**
/// Single source of truth for the vertical route diagrams, ensuring visual parity
/// between the "Lines" tab and the "Trains" tab.

/// A reusable station node symbol matching the screenshot (bold ring style).
struct StationNodeSymbol: View {
    let node: Node?
    let defaultColor: Color
    var size: CGFloat = 16
    var isTransit: Bool = false
    
    var body: some View {
        if let node = node {
            let color = Color(hex: node.customColor ?? node.defaultColor) ?? defaultColor
            
            ZStack {
                if isTransit {
                    // Transit: Smaller, hollow circle
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: size - 4, height: size - 4)
                        .background(Circle().fill(Color.black.opacity(0.8))) // Match sidebar bg
                } else {
                    // Normal Stop: Solid ring style
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: size, height: size)
                    
                    Circle()
                        .fill(color)
                        .frame(width: size - 6, height: size - 6)
                }
            }
        } else {
            Circle()
                .stroke(Color.gray, lineWidth: 2)
                .frame(width: size - 4, height: size - 4)
        }
    }
}

/// A reusable track segment that uses TrackGraphicView with consistent styling.
struct RouteTrackSegment: View {
    let trackType: Edge.TrackType
    let color: Color
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TrackGraphicView(trackType: trackType, color: color, width: appState.globalLineWidth)
    }
}

/// 🚄 **VerticalDiagramStep**
/// Represents ONE complete step in the diagram: the station AND the following segment.
struct VerticalDiagramStep<ExtraInfo: View, SegmentInfo: View>: View {
    let stationId: String
    let isLast: Bool
    let nextStationId: String?
    let network: RailwayNetwork
    let lineColor: Color
    var isTransit: Bool = false
    let isEditing: Bool
    let extraInfo: ExtraInfo
    let segmentMetadata: SegmentInfo
    
    // Inline editing actions
    var onDelete: (() -> Void)? = nil
    var onInsertBefore: (() -> Void)? = nil
    var onInsertAfter: (() -> Void)? = nil
    var onStationTap: (() -> Void)? = nil
    var onSegmentTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil
    
    private var node: Node? { network.nodes.first(where: { $0.id == stationId }) }
    
    init(
        stationId: String,
        network: RailwayNetwork,
        isLast: Bool,
        nextStationId: String? = nil,
        lineColor: Color = .green,
        isTransit: Bool = false,
        isEditing: Bool = false,
        onDelete: (() -> Void)? = nil,
        onInsertBefore: (() -> Void)? = nil,
        onInsertAfter: (() -> Void)? = nil,
        onStationTap: (() -> Void)? = nil,
        onSegmentTap: (() -> Void)? = nil,
        @ViewBuilder extraInfo: () -> ExtraInfo = { EmptyView() },
        @ViewBuilder segmentMetadata: () -> SegmentInfo = { EmptyView() }
    ) {
        self.stationId = stationId
        self.isLast = isLast
        self.nextStationId = nextStationId
        self.network = network
        self.lineColor = lineColor
        self.isTransit = isTransit
        self.isEditing = isEditing
        self.onDelete = onDelete
        self.onInsertBefore = onInsertBefore
        self.onInsertAfter = onInsertAfter
        self.onStationTap = onStationTap
        self.onSegmentTap = onSegmentTap
        self.extraInfo = extraInfo()
        self.segmentMetadata = segmentMetadata()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 0. INSERT BEFORE (Conditional, e.g. for first station)
            if let onInsertBefore = onInsertBefore {
                HStack(alignment: .center, spacing: 12) {
                    if isEditing {
                        Spacer().frame(width: 30)
                    }
                    
                    ZStack {
                        Rectangle()
                            .fill(lineColor.opacity(0.3))
                            .frame(width: 4, height: 30)
                        
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onInsertBefore()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .background(Circle().fill(Color.black))
                                .font(.system(size: 24))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 40)
                    
                    Text("add_station_upstream".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green.opacity(0.8))
                    
                    Spacer()
                }
                .frame(height: 40)
            }

            // 1. STATION ROW
            HStack(alignment: .center, spacing: 12) {
                // Column 0: Delete Button Slot
                if isEditing {
                    ZStack {
                        if let onDelete = onDelete {
                            Button(action: {
                                print("🔴 [UI] Delete button TAPPED for station: \(stationId)")
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                print("🔴 [UI] Calling onDelete callback...")
                                onDelete()
                                print("🔴 [UI] onDelete callback completed")
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 26))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 40)
                }
                
                // Column 1 & 2: Station Symbol & Info (Tappable for selection)
                Button(action: {
                    print("🚉 [UI] Station TAPPED: \(stationId)")
                    onStationTap?()
                }) {
                    HStack(alignment: .center, spacing: 20) {
                        ZStack {
                            StationNodeSymbol(node: node, defaultColor: lineColor, size: 20, isTransit: isTransit)
                        }
                        .frame(width: 30) // Fixed width for alignment
                        
                        Text(node?.name ?? stationId)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        extraInfo
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 40)
            
            // 2. SEGMENT ROW (Only if not last OR if onInsertAfter is present)
            if !isLast || onInsertAfter != nil {
                HStack(alignment: .center, spacing: 12) {
                    // Column 0: Alignment Slot for delete button
                    if isEditing {
                        Spacer().frame(width: 30)
                    }
                    
                    // Column 1: Track Line
                    Button(action: {
                        print("🛤️ [UI] Segment TAPPED for station: \(stationId)")
                        onSegmentTap?()
                    }) {
                        ZStack {
                            if let nextId = nextStationId {
                                ConnectionLineView(from: stationId, to: nextId, network: network, color: lineColor)
                                    .frame(width: 30)
                            } else {
                                Rectangle()
                                    .fill(lineColor.opacity(0.3))
                                    .frame(width: 4)
                                    .frame(width: 30)
                            }
                            
                            // Insert Button Overlay
                            if let onInsert = onInsertAfter {
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    onInsert()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(isLast ? .green : .blue)
                                        .background(Circle().fill(Color.black))
                                        .font(.system(size: 24))
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Column 2: Custom Metadata Slot
                    if let nextId = nextStationId {
                        if segmentMetadata is EmptyView {
                            // Default: Line-style metadata (speed + distance)
                            LineSegmentMetadataView(from: stationId, to: nextId, network: network)
                        } else {
                            segmentMetadata
                        }
                    } else if onInsertAfter != nil {
                        Text("add_station_downstream".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .frame(height: isLast ? 60 : 100)
            }
        }
    }
}

/// Line-style metadata: Speed + Distance + Track Type Badge
struct LineSegmentMetadataView: View {
    let from: String
    let to: String
    let network: RailwayNetwork
    
    var body: some View {
        if let edge = network.edges.first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    // Distance Stack (Blue)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(format: "%.1f", edge.distance))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                        Text("km")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                    }
                    
                    // Speed Stack (Gray + Icon)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 12))
                            Text("\(edge.maxSpeed)")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text("km/h")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.leading, 18)
                    }
                    .foregroundColor(.gray)
                }
                
                // Track Badge (Black Box)
                let trackTypeLabel: String = {
                    switch edge.trackType {
                    case .single: return "track_single".localized.uppercased()
                    case .double: return "track_double".localized.uppercased()
                    case .regional: return "track_regional".localized.uppercased()
                    case .highSpeed: return "track_highspeed".localized.uppercased()
                    }
                }()
                
                Text(trackTypeLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
    }
}

/// Train-style metadata: Arrival/Departure Times + Segment Length
struct TrainSegmentMetadataView: View {
    let arrivalTime: Date?
    let departureTime: Date?
    let segmentDistance: Double
    var isOrigin: Bool = false
    var isTerminus: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                // Times Stack (White)
                VStack(alignment: .leading, spacing: 4) {
                    if let arr = arrivalTime, !isOrigin {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 10))
                            Text(formatTime(arr))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                    }
                    if let dep = departureTime, !isTerminus {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 10))
                            Text(formatTime(dep))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.green)
                    }
                }
                
                // Distance Stack (Blue)
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(format: "%.1f", segmentDistance))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                    Text("km")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

/// Internal helper for the connection line
private struct ConnectionLineView: View {
    let from: String
    let to: String
    let network: RailwayNetwork
    let color: Color
    
    
    private var edge: Edge? {
        network.edges.first(where: { edge in
            (edge.from == from && edge.to == to) || (edge.from == to && edge.to == from)
        })
    }
    
    var body: some View {
        if let edge = edge {
            RouteTrackSegment(trackType: edge.trackType, color: color)
        } else {
            // Missing edge: show a VERY BOLD dashed line
            DashedLine()
                .stroke(style: StrokeStyle(lineWidth: 8, dash: [10, 5]))
                .foregroundColor(.white)
                .frame(width: 8)
        }
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
