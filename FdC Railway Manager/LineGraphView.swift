import SwiftUI
import Combine

struct LineGraphView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState // Added for theme access
    let line: RailwayLine
    
    // Data passed from parent
    let orderedStations: [Node]
    let stationDistances: [Double]
    let maxDistance: Double
    
    // Zoom/Pan State
    @State private var timeScale: CGFloat = 60.0 // Pixels per hour
    @State private var pixelsPerKm: CGFloat = 5.0 // Vertical Scale (Zoom)
    @State private var lastScale: CGFloat = 1.0 // For magnification
    @State private var redrawTrigger = UUID() // To force redraws
    
    // Selection Wrapper
    @Binding var selectedStation: LineScheduleView.StationSelection?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { verticalProxy in
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        // 1. Station Names Column
                        StationLabelsView(
                            stations: orderedStations,
                            distances: stationDistances,
                            pixelsPerKm: pixelsPerKm,
                            selectedStation: $selectedStation
                        )
                        .frame(width: 140)
                        .background(.ultraThinMaterial)
                        .zIndex(10)
                        
                        // 2. The Graph
                        graphContent(geometry: geometry, verticalProxy: verticalProxy)
                    }
                }
            }
        }
        .background(appState.theme.background)
        .toolbar { toolbarContent }
        .onReceive(manager.objectWillChange) { _ in
            self.redrawTrigger = UUID()
        }
        .id(redrawTrigger)
    }
    
    // MARK: - Subviews
    
    private func graphContent(geometry: GeometryProxy, verticalProxy: ScrollViewProxy) -> some View {
        ScrollViewReader { horizontalProxy in
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Dimensions
                    let graphHeight = max(geometry.size.height, maxDistance * pixelsPerKm + 100)
                    let graphWidth = 24 * timeScale
                    
                    // Background
                    Rectangle()
                        .fill(Color(white: 0.95))
                        .frame(width: graphWidth, height: graphHeight)
                        .border(appState.theme.dark, width: 1)
                    
                    // Layers
                    GridLayer(
                        width: graphWidth,
                        height: graphHeight,
                        timeScale: timeScale,
                        pixelsPerKm: pixelsPerKm,
                        orderedStations: orderedStations,
                        stationDistances: stationDistances
                    )
                    
                    TrainLayer(
                        width: graphWidth,
                        height: graphHeight,
                        timeScale: timeScale,
                        pixelsPerKm: pixelsPerKm,
                        orderedStations: orderedStations,
                        stationDistances: stationDistances,
                        manager: manager,
                        appState: appState
                    )
                    
                    ConflictLayer(
                        width: graphWidth,
                        height: graphHeight,
                        timeScale: timeScale,
                        pixelsPerKm: pixelsPerKm,
                        orderedStations: orderedStations,
                        stationDistances: stationDistances,
                        manager: manager
                    )
                }
                .onTapGesture { location in
                   findTrainAtLocation(location)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            
                            // Calculate provisional new values
                            let provTimeScale = timeScale * delta
                            let provPixelsPerKm = pixelsPerKm * delta
                            
                            // Determine effective realizable delta for each dimension given limits
                            // timeScale: 20...300
                            let clampedTimeScale = min(max(20, provTimeScale), 300)
                            let realizedDeltaTime = clampedTimeScale / timeScale
                            
                            // pixelsPerKm: 1.0...50.0
                            let clampedPixelsPerKm = min(max(1.0, provPixelsPerKm), 50.0)
                            let realizedDeltaPixels = clampedPixelsPerKm / pixelsPerKm
                            
                            // Use the most restrictive delta to maintain aspect ratio
                            let finalDelta: CGFloat
                            if delta > 1 {
                                // Growing: limited by the smaller realization (one that hits max first)
                                finalDelta = min(realizedDeltaTime, realizedDeltaPixels)
                            } else {
                                // Shrinking: limited by the larger realization (one that hits min first, closest to 1)
                                finalDelta = max(realizedDeltaTime, realizedDeltaPixels)
                            }
                            
                            // Apply the synchronized delta
                            timeScale = timeScale * finalDelta
                            pixelsPerKm = pixelsPerKm * finalDelta
                            
                            lastScale = value
                        }
                        .onEnded { _ in lastScale = 1.0 }
                )
                .onChange(of: appState.selectedTrainIds) { ids in
                    if let trainId = ids.first,
                       let train = manager.trains.first(where: { $0.id == trainId }),
                       let firstStop = train.stops.first(where: { stop in orderedStations.contains(where: { $0.id == stop.stationId }) }) {
                        
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: firstStop.departure ?? firstStop.arrival ?? Date())
                        
                        withAnimation(.easeInOut(duration: 0.8)) {
                            horizontalProxy.scrollTo(Double(hour) * timeScale, anchor: .center)
                            verticalProxy.scrollTo(firstStop.stationId, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack {
                Menu {
                    Button("Molto Compatta (2 px/km)") { pixelsPerKm = 2.0 }
                    Button("Compatta (5 px/km)") { pixelsPerKm = 5.0 }
                    Button("Normale (10 px/km)") { pixelsPerKm = 10.0 }
                    Button("Dettagliata (20 px/km)") { pixelsPerKm = 20.0 }
                } label: {
                    Label("Scala Vert.", systemImage: "arrow.up.and.down.square")
                }
                
                Divider()
                
                Button(action: { timeScale = max(20, timeScale - 10) }) { Image(systemName: "minus.magnifyingglass") }
                Button(action: { timeScale = min(200, timeScale + 10) }) { Image(systemName: "plus.magnifyingglass") }
            }
        }
    }
    
    // MARK: - Logic
    
    private func findTrainAtLocation(_ location: CGPoint) {
        let lineStationIds = Set(orderedStations.map { $0.id })
        let trains = manager.trains.filter { train in
            train.stops.contains { lineStationIds.contains($0.stationId) }
        }
        
        var bestTrain: Train? = nil
        var minDistance: CGFloat = 20.0
        
        for train in trains {
            var points: [CGPoint] = []
            for stop in train.stops {
                if let idx = orderedStations.firstIndex(where: { $0.id == stop.stationId }) {
                    let y = CGFloat(stationDistances[idx]) * pixelsPerKm + 50.0
                    if let arrival = stop.arrival { points.append(CGPoint(x: timeToX(arrival), y: y)) }
                    if let departure = stop.departure { points.append(CGPoint(x: timeToX(departure), y: y)) }
                } else {
                    if points.count >= 2 { checkSegments(points, for: train, at: location, minDist: &minDistance, best: &bestTrain) }
                    points = []
                }
            }
            if points.count >= 2 { checkSegments(points, for: train, at: location, minDist: &minDistance, best: &bestTrain) }
        }
        
        if let found = bestTrain {
            appState.selectTrain(found.id)
        }
    }
    
    private func timeToX(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        let s = calendar.component(.second, from: date)
        return (CGFloat(h) + CGFloat(m)/60.0 + CGFloat(s)/3600.0) * timeScale
    }

    private func checkSegments(_ points: [CGPoint], for train: Train, at location: CGPoint, minDist: inout CGFloat, best: inout Train?) {
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i+1]
            let d = distanceToSegment(p: location, a: p1, b: p2)
            if d < minDist {
                minDist = d
                best = train
            }
        }
    }
    
    private func distanceToSegment(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let l2 = pow(a.x - b.x, 2) + pow(a.y - b.y, 2)
        if l2 == 0 { return sqrt(pow(p.x - a.x, 2) + pow(p.y - a.y, 2)) }
        var t = ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / l2
        t = max(0, min(1, t))
        let proj = CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
        return sqrt(pow(p.x - proj.x, 2) + pow(p.y - proj.y, 2))
    }
}

// MARK: - Layer Components

struct GridLayer: View {
    let width: CGFloat
    let height: CGFloat
    let timeScale: CGFloat
    let pixelsPerKm: CGFloat
    let orderedStations: [Node]
    let stationDistances: [Double]
    
    var body: some View {
        Canvas { context, size in
            // Time Grid
            for hour in 0...24 {
                let x = CGFloat(hour) * timeScale
                let path = Path {
                    $0.move(to: CGPoint(x: x, y: 0))
                    $0.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 1)
                context.draw(Text(hour == 24 ? "0:00" : "\(hour):00").font(.caption).foregroundColor(.secondary), at: CGPoint(x: x + 5, y: 5))
            }
            // Station Grid
            for (index, _) in orderedStations.enumerated() {
                guard index < stationDistances.count else { continue }
                let y = stationDistances[index] * pixelsPerKm + 50
                let path = Path {
                    $0.move(to: CGPoint(x: 0, y: y))
                    $0.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.primary.opacity(0.1)), lineWidth: 1)
            }
        }
        .frame(width: width, height: height)
    }
}

struct TrainLayer: View {
    let width: CGFloat
    let height: CGFloat
    let timeScale: CGFloat
    let pixelsPerKm: CGFloat
    let orderedStations: [Node]
    let stationDistances: [Double]
    let manager: TrainManager
    @ObservedObject var appState: AppState
    
    var body: some View {
        Canvas { context, size in
            let lineStationIds = Set(orderedStations.map { $0.id })
            let lineTrainIds = manager.trains.filter { train in
                train.stops.contains { lineStationIds.contains($0.stationId) }
            }
            
            for train in lineTrainIds {
                var points: [CGPoint] = []
                for stop in train.stops {
                    if let idx = orderedStations.firstIndex(where: { $0.id == stop.stationId }) {
                        let y = CGFloat(stationDistances[idx]) * pixelsPerKm + 50.0
                        if let arrival = stop.plannedArrival ?? stop.arrival {
                            points.append(CGPoint(x: timeToX(arrival), y: y))
                        }
                        if let departure = stop.plannedDeparture ?? stop.departure {
                            points.append(CGPoint(x: timeToX(departure), y: y))
                        }
                    } else {
                        if points.count >= 2 { drawTrainPath(points, for: train, in: context) }
                        points = []
                    }
                }
                if points.count >= 2 { drawTrainPath(points, for: train, in: context) }
            }
        }
        .frame(width: width, height: height)
    }
    
    private func timeToX(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0)/60.0 + CGFloat(components.second ?? 0)/3600.0) * timeScale
    }
    
    private func drawTrainPath(_ points: [CGPoint], for train: Train, in context: GraphicsContext) {
        let maxX = 24 * timeScale
        var currentPath = Path()
        var movedToStart = false
        
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i+1]
            
            if !movedToStart {
                currentPath.move(to: p1)
                movedToStart = true
            }
            
            if p2.x >= p1.x {
                currentPath.addLine(to: p2)
            } else {
                let distToMidnight = maxX - p1.x
                let totalDist = distToMidnight + p2.x
                let ratio = distToMidnight / totalDist
                let yMidnight = p1.y + (p2.y - p1.y) * ratio
                
                currentPath.addLine(to: CGPoint(x: maxX, y: yMidnight))
                strokePath(currentPath, for: train, in: context)
                
                currentPath = Path()
                currentPath.move(to: CGPoint(x: 0, y: yMidnight))
                currentPath.addLine(to: p2)
                movedToStart = true
            }
        }
        
        strokePath(currentPath, for: train, in: context)
        
        if let first = points.first {
            let color: Color = train.priority > 7 ? .red : .primary
            context.draw(Text(train.type + " " + train.name).font(.caption2).foregroundColor(color), at: CGPoint(x: first.x, y: first.y - 12))
        }
    }
    
    private func strokePath(_ path: Path, for train: Train, in context: GraphicsContext) {
        guard !path.isEmpty else { return }
        let isSelected = appState.selectedTrainIds.contains(train.id)
        let isEditing = isSelected && appState.isInspectorEditingMode
        let color: Color
        if isEditing { color = .yellow }
        else if isSelected { color = .cyan }
        else { color = train.priority > 7 ? .red : .white.opacity(0.6) }
        
        let lineWidth: CGFloat = isEditing ? 6 : (isSelected ? 4 : 2)
        context.drawLayer { subgroup in
            if isSelected { subgroup.addFilter(.shadow(color: color.opacity(0.8), radius: isEditing ? 12 : 6)) }
            subgroup.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

struct ConflictLayer: View {
    let width: CGFloat
    let height: CGFloat
    let timeScale: CGFloat
    let pixelsPerKm: CGFloat
    let orderedStations: [Node]
    let stationDistances: [Double]
    @ObservedObject var manager: TrainManager
    
    var body: some View {
        Canvas { context, size in
            for conflict in manager.conflictManager.conflicts {
                let resId = conflict.locationId
                var y: CGFloat? = nil
                
                if conflict.locationType == .station {
                   let stationId = resId.components(separatedBy: "::").first { id in orderedStations.contains { $0.id == id } } ?? ""
                   if let idx = orderedStations.firstIndex(where: { $0.id == stationId }) {
                       y = stationDistances[idx] * pixelsPerKm + 50
                   }
                }
                
                if let y = y {
                    drawMarker(at: CGPoint(x: timeToX(conflict.timeStart), y: y), icon: "exclamationmark.triangle.fill", in: context)
                } else if conflict.locationType == .line || resId.hasPrefix("SEGMENT") {
                    let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
                    let parts = content.components(separatedBy: "--")
                    if parts.count == 2,
                       let idx1 = orderedStations.firstIndex(where: { $0.id == parts[0] }),
                       let idx2 = orderedStations.firstIndex(where: { $0.id == parts[1] }) {
                        let yMid = (stationDistances[idx1] + stationDistances[idx2]) / 2.0 * pixelsPerKm + 50
                        drawMarker(at: CGPoint(x: timeToX(conflict.timeStart), y: yMid), icon: "bolt.fill", in: context)
                    }
                }
            }
        }
        .frame(width: width, height: height)
    }
    
    private func timeToX(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0)/60.0 + CGFloat(components.second ?? 0)/3600.0) * timeScale
    }
    
    private func drawMarker(at point: CGPoint, icon: String, in context: GraphicsContext) {
        let radius: CGFloat = 12
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(.red))
        context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1.5)
        context.draw(Image(systemName: icon), at: point)
    }
}

struct StationLabelsView: View {
    let stations: [Node]
    let distances: [Double]
    let pixelsPerKm: CGFloat
    @Binding var selectedStation: LineScheduleView.StationSelection? 
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            ForEach(stations.indices, id: \.self) { index in
                if index < distances.count {
                    let station = stations[index]
                    let dist = distances[index]
                    let y = dist * pixelsPerKm + 50
                    
                    Button(action: {
                        selectedStation = LineScheduleView.StationSelection(id: station.id)
                    }) {
                        Text(station.name)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.primary)
                            .padding(.trailing, 8)
                            .frame(height: 20)
                    }
                    .id(station.id)
                    .position(x: 70, y: y)
                }
            }
        }
        .frame(height: (distances.last ?? 0) * pixelsPerKm + 100)
    }
}

// Wrapper for identifying string in sheet
struct StationScheduleViewWrapper: View, Identifiable {
    let id = UUID()
    let stationId: String
    let network: RailwayNetwork
    let manager: TrainManager
    
    var body: some View {
        if let station = network.nodes.first(where: { $0.id == stationId }) {
            StationScheduleView(station: station)
                .environmentObject(network)
                .environmentObject(manager)
        } else {
            Text("Stazione non trovata")
        }
    }
}
