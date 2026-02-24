import SwiftUI
import Combine

struct LineGraphView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState // Added for theme access
    let line: RailwayLine
    
    // Data passed from parent
    let orderedStations: [RailwayNode]
    let stationDistances: [Double]
    let maxDistance: Double
    
    // Zoom/Pan State
    @State private var timeScale: CGFloat = 120.0 // Pixels per hour (increased for detail)
    @State private var pixelsPerKm: CGFloat = 10.0 // Vertical Scale (Zoom increased)
    @State private var lastScale: CGFloat = 1.0 // For magnification
    @State private var baseTimeScale: CGFloat = 120.0
    @State private var basePixelsPerKm: CGFloat = 10.0
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
                        .background(appState.theme.background)
                        .border(appState.theme.line.opacity(0.1), width: 1)
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
                    let graphHeight = max(200, maxDistance * pixelsPerKm + 100)
                    let graphWidth = 24 * timeScale
                    
                    // Background
                    Rectangle()
                        .fill(appState.theme.background.opacity(0.8))
                        .frame(width: graphWidth, height: graphHeight)
                        .border(appState.theme.line.opacity(0.2), width: 1)
                    
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
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            // value is the magnification factor since gesture start
                            let delta = value / lastScale
                            lastScale = value
                            
                            // Proportional scaling
                            let newTimeScale = timeScale * delta
                            let newPixelsPerKm = pixelsPerKm * delta
                            
                            timeScale = min(max(20, newTimeScale), 400)
                            pixelsPerKm = min(max(2.0, newPixelsPerKm), 100)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                        }
                )
                .onChange(of: appState.selectedTrainIds) { ids in
                    if let trainId = ids.first,
                       let train = manager.trains.first(where: { $0.id == trainId }),
                       let firstStop = train.stops.first(where: { stop in orderedStations.contains(where: { $0.id == stop.stationId }) }) {
                        
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: firstStop.departure ?? firstStop.arrival ?? Date())
                        
                        withAnimation(.easeInOut(duration: 0.8)) {
                            horizontalProxy.scrollTo("hour_\(hour)", anchor: .center)
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
                    Button("Zoom 1x") { timeScale = 120; pixelsPerKm = 10 }
                    Button("Zoom 2x") { timeScale = 240; pixelsPerKm = 20 }
                    Button("Zoom 0.5x") { timeScale = 60; pixelsPerKm = 5 }
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                }
                
                Divider()
                
                VStack(spacing: 0) {
                    Slider(value: $timeScale, in: 20...400)
                        .frame(width: 100)
                    Text("Tempo").font(.system(size: 8))
                }
                
                VStack(spacing: 0) {
                    Slider(value: $pixelsPerKm, in: 2...100)
                        .frame(width: 100)
                    Text("Spazio").font(.system(size: 8))
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func findTrainAtLocation(_ location: CGPoint) {
        let lineStationIds = Set(orderedStations.map { $0.id })
        let trains = manager.trains.filter { train in
            train.stops.contains { lineStationIds.contains($0.stationId) }
        }
        
        var bestTrain: RailwayTrain? = nil
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

    private func checkSegments(_ points: [CGPoint], for train: RailwayTrain, at location: CGPoint, minDist: inout CGFloat, best: inout RailwayTrain?) {
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
    let orderedStations: [RailwayNode]
    let stationDistances: [Double]
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Invisible anchors for horizontal scrolling
            HStack(spacing: 0) {
                ForEach(0...24, id: \.self) { hour in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id("hour_\(hour)")
                    if hour < 24 {
                        Spacer().frame(width: timeScale - 1)
                    }
                }
            }
            .frame(width: width, height: 1)

            Canvas { context, size in
                // Time Grid
                for hour in 0...24 {
                    let x = CGFloat(hour) * timeScale
                    let path = Path {
                        $0.move(to: CGPoint(x: x, y: 0))
                        $0.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(path, with: .color(appState.theme.line.opacity(0.4)), lineWidth: 1)
                    context.draw(Text(hour == 24 ? "0:00" : "\(hour):00").font(.caption.bold()).foregroundColor(appState.theme.dark), at: CGPoint(x: x + 5, y: 5))
                }
                
                // Station Grid + KM Labels
                for (index, _) in orderedStations.enumerated() {
                    guard index < stationDistances.count else { continue }
                    let y = stationDistances[index] * pixelsPerKm + 50
                    let path = Path {
                        $0.move(to: CGPoint(x: 0, y: y))
                        $0.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(appState.theme.line.opacity(0.2)), lineWidth: 1)
                    
                    // KM Marker on the right
                    let km = stationDistances[index]
                    context.draw(Text(String(format: "km %.1f", km)).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(appState.theme.dark.opacity(0.5)), at: CGPoint(x: size.width - 35, y: y - 8))
                }
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
    let orderedStations: [RailwayNode]
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
    
    private func drawTrainPath(_ points: [CGPoint], for train: RailwayTrain, in context: GraphicsContext) {
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
            let color: Color = train.priority > 7 ? .red : (appState.selectedTrainIds.contains(train.id) ? .cyan : appState.theme.dark)
            context.draw(Text(train.type + " " + train.name).font(.system(size: 10, weight: .bold)).foregroundColor(color), at: CGPoint(x: first.x, y: first.y - 12))
        }
    }
    
    private func strokePath(_ path: Path, for train: RailwayTrain, in context: GraphicsContext) {
        guard !path.isEmpty else { return }
        let isSelected = appState.selectedTrainIds.contains(train.id)
        let isEditing = isSelected && appState.isInspectorEditingMode
        let color: Color
        if isEditing { color = .yellow }
        else if isSelected { color = .cyan }
        else { color = train.priority > 7 ? .red : appState.theme.dark.opacity(0.6) }
        
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
    let orderedStations: [RailwayNode]
    let stationDistances: [Double]
    @EnvironmentObject var appState: AppState
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
        } symbols: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .tag("exclamationmark.triangle.fill")
            Image(systemName: "bolt.fill")
                .foregroundColor(.white)
                .tag("bolt.fill")
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
        context.stroke(Path(ellipseIn: rect), with: .color(appState.theme.background), lineWidth: 1.5)
        
        // Resolve and draw the icon
        if let resolved = context.resolveSymbol(id: icon) {
            context.draw(resolved, at: point)
        } else {
            // Fallback for simple images
            context.draw(Image(systemName: icon), at: point)
        }
    }
}

struct StationLabelsView: View {
    @EnvironmentObject var appState: AppState
    let stations: [RailwayNode]
    let distances: [Double]
    let pixelsPerKm: CGFloat
    @Binding var selectedStation: LineScheduleView.StationSelection? 
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            ForEach(0..<stations.count, id: \.self) { index in
                if index < distances.count {
                    let station = stations[index]
                    let dist = distances[index]
                    let y = dist * pixelsPerKm + 50
                    
                    Button(action: {
                        selectedStation = LineScheduleView.StationSelection(id: station.id)
                    }) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(station.name)
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .multilineTextAlignment(.trailing)
                            Text(String(format: "km %.1f", dist))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(selectedStation?.id == station.id ? appState.theme.accent : appState.theme.medium)
                        }
                        .padding(.trailing, 10)
                        .frame(width: 140, height: 36, alignment: .trailing)
                        .background(selectedStation?.id == station.id ? appState.theme.accent.opacity(0.1) : Color.clear)
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
