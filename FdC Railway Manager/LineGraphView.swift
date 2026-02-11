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
    @State private var pixelsPerKm: CGFloat = 5.0 // Vertical Scale (Zoom) - Default reduced for better overview
    
    @State private var lastScale: CGFloat = 1.0 // For magnification gesture
    
    // Selection Wrapper (Identifiable for Sheet) -> Now Binding from Parent
    @Binding var selectedStation: LineScheduleView.StationSelection?
    
    var body: some View {
        GeometryReader { geometry in
                ScrollViewReader { verticalProxy in
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: 0) {
                            // 1. Station Names Column (Fixed Horizontally)
                            StationLabelsView(
                                stations: orderedStations,
                                distances: stationDistances,
                                pixelsPerKm: pixelsPerKm,
                                selectedStation: $selectedStation
                            )
                            .frame(width: 140)
                            .background(.ultraThinMaterial)
                            .zIndex(10)
                            
                            // 2. The Graph (Scrollable Horizontally)
                            ScrollViewReader { horizontalProxy in
                                ScrollView(.horizontal, showsIndicators: true) {
                                    ZStack(alignment: .topLeading) {
                                        // Background Depth
                                        let graphHeight = max(geometry.size.height, maxDistance * pixelsPerKm + 100)
                                        let graphWidth = 24 * timeScale
                                        
                                        Rectangle()
                                            .fill(Color(white: 0.95))
                                            .frame(width: graphWidth, height: graphHeight)
                                            .border(appState.theme.dark, lineWidth: 1) // Dark border for the "window"
                                        
                                        drawGrid(width: graphWidth, height: graphHeight)
                                        
                                        // Invisible markers for horizontal scrolling (Time)
                                        ForEach(0...24, id: \.self) { hour in
                                            Color.clear
                                                .frame(width: 1, height: 1)
                                                .position(x: CGFloat(hour) * timeScale, y: 0)
                                                .id("HOUR_\(hour)")
                                        }
                                        
                                        // Train Plots
                                        drawTrains(width: graphWidth)
                                        
                                        // Conflict Markers
                                        drawConflicts(width: graphWidth)
                                    }
                                    .frame(width: 24 * timeScale, 
                                           height: maxDistance * pixelsPerKm + 100)
                                    .onTapGesture { location in
                                        findTrainAtLocation(location)
                                    }
                                    .onChange(of: appState.selectedTrainIds) { ids in
                                        if let trainId = ids.first, 
                                           let train = manager.trains.first(where: { $0.id == trainId }),
                                           let firstStop = train.stops.first(where: { stop in orderedStations.contains(where: { $0.id == stop.stationId }) }) {
                                            
                                            // Center Horizontally (Time)
                                            let calendar = Calendar.current
                                            let hour = calendar.component(.hour, from: firstStop.departure ?? firstStop.arrival ?? Date())
                                            
                                            withAnimation(.easeInOut(duration: 0.8)) {
                                                horizontalProxy.scrollTo("HOUR_\(hour)", anchor: .center)
                                                verticalProxy.scrollTo(firstStop.stationId, anchor: .center)
                                            }
                                        }
                                    }
                                }
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            timeScale = min(max(20, timeScale * delta), 300)
                                            lastScale = value
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        }
                                )
                            }
                        }
                    }
                }
                }
            } // GeometryReader
        }
        .background(appState.theme.background) // Use app background color (light grigetto)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    // Vertical Zoom (Scale)
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
        .onReceive(manager.objectWillChange) { _ in
            // Forza il ridisegno quando cambiano i dati (es. orari modificati nell'inspector)
            self.redrawTrigger = UUID()
        }
        .id(redrawTrigger) // Questo forza la ricreazione della vista se necessario, o basta invocare il body
    }
    
    // Stato per forzare il refresh del Canvas
    @State private var redrawTrigger = UUID()
    
    // MARK: - Drawing Components
    
    private func drawGrid(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            // Draw Time Grid (Vertical Lines)
            for hour in 0...24 {
                let x = CGFloat(hour) * timeScale
                
                let path = Path {
                    $0.move(to: CGPoint(x: x, y: 0))
                    $0.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 1)
                context.draw(Text(hour == 24 ? "0:00" : "\(hour):00").font(.caption).foregroundColor(.secondary), at: CGPoint(x: x + 5, y: 5))
            }
            
            // Draw Station Grid (Horizontal Lines)
            for (index, _) in orderedStations.enumerated() {
                guard index < stationDistances.count else { continue }
                let dist = stationDistances[index]
                let y = dist * pixelsPerKm + 50 // Margin top
                
                let path = Path {
                    $0.move(to: CGPoint(x: 0, y: y))
                    $0.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.primary.opacity(0.1)), lineWidth: 1)
            }
        }
    }
    
    private func drawConflicts(width: CGFloat) -> some View {
        Canvas { context, size in
            for conflict in manager.conflictManager.conflicts {
                let resId = conflict.locationId
                var y: CGFloat? = nil
                if conflict.locationType == .station {
                    // Match TRACK::[stationId]::[track] or STATION_GLOBAL::[stationId]
                    let stationId = resId.components(separatedBy: "::").first { id in
                         orderedStations.contains { $0.id == id }
                    } ?? ""
                    
                    if let idx = orderedStations.firstIndex(where: { $0.id == stationId }) {
                         y = stationDistances[idx] * pixelsPerKm + 50
                    }
                }
                
                if let y = y {
                    // Time X
                    let startX = xFor(conflict.timeStart)
                    
                    // CERCHIETTO ROSSO (Red Circle) for Station Conflict
                    let radius: CGFloat = 12
                    let circleRect = CGRect(x: startX - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    
                    context.fill(Path(ellipseIn: circleRect), with: .color(.red))
                    context.stroke(Path(ellipseIn: circleRect), with: .color(.white), lineWidth: 1.5) // White border for contrast
                    
                    context.draw(Image(systemName: "exclamationmark.triangle.fill"), at: CGPoint(x: startX, y: y))
                } else if conflict.locationType == .line || resId.hasPrefix("SEGMENT") {
                    let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
                    let parts = content.components(separatedBy: "--")
                    if parts.count == 2 {
                        if let idx1 = orderedStations.firstIndex(where: { $0.id == parts[0] }),
                           let idx2 = orderedStations.firstIndex(where: { $0.id == parts[1] }) {
                            let y1 = stationDistances[idx1] * pixelsPerKm + 50
                            let y2 = stationDistances[idx2] * pixelsPerKm + 50
                            let midY = (y1 + y2) / 2
                            let startX = xFor(conflict.timeStart)
                            
                            // CERCHIETTO ROSSO (Red Circle) for Line Conflict
                            let radius: CGFloat = 10
                            let circleRect = CGRect(x: startX - radius, y: midY - radius, width: radius * 2, height: radius * 2)
                            
                            context.fill(Path(ellipseIn: circleRect), with: .color(.red))
                            context.stroke(Path(ellipseIn: circleRect), with: .color(.white), lineWidth: 1.5)
                            
                            context.draw(Image(systemName: "bolt.fill"), at: CGPoint(x: startX, y: midY))
                        }
                    }
                }
            }
        }
    }
    
    private func xFor(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        let s = calendar.component(.second, from: date)
        return (CGFloat(h) + CGFloat(m)/60.0 + CGFloat(s)/3600.0) * timeScale
    }
    
    private func drawTrains(width: CGFloat) -> some View {
        Canvas { context, size in
            // Filter trains that touch ANY station of this line (for true platform/segment occupancy)
            let lineStationIds = Set(orderedStations.map { $0.id })
            let lineTrainIds = manager.trains.filter { train in
                train.stops.contains { lineStationIds.contains($0.stationId) }
            }
            
            for train in lineTrainIds {
                var points: [CGPoint] = []
                
                // Plot using actual pre-calculated stop times from Train objects
                for stop in train.stops {
                    if let idx = orderedStations.firstIndex(where: { $0.id == stop.stationId }) {
                        // MATH: Add small Y offset based on track (platform) to distinguish occupancy
                        let y = CGFloat(stationDistances[idx]) * pixelsPerKm + 50.0
                        
                        // Use planned times if available, otherwise use calculated times
                        let arrivalTime = stop.plannedArrival ?? stop.arrival
                        let departureTime = stop.plannedDeparture ?? stop.departure
                        
                        if let arrival = arrivalTime {
                            points.append(CGPoint(x: xFor(arrival), y: y))
                        }
                        
                        if let departure = departureTime {
                            points.append(CGPoint(x: xFor(departure), y: y))
                        }
                    } else {
                        // Train is leaving the visible line area - draw what we collected and reset
                        if points.count >= 2 {
                            drawTrainPath(points, for: train, in: context)
                        }
                        points = []
                    }
                }
                
                // Draw remaining/final path
                if points.count >= 2 {
                    drawTrainPath(points, for: train, in: context)
                }
            }
        }
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
                // Normal segment
                currentPath.addLine(to: p2)
            } else {
                // Crossing Midnight!
                // Calculate y at midnight
                let distToMidnight = maxX - p1.x
                let totalDist = distToMidnight + p2.x
                let ratio = distToMidnight / totalDist
                let yMidnight = p1.y + (p2.y - p1.y) * ratio
                
                // End current path segment at midnight
                currentPath.addLine(to: CGPoint(x: maxX, y: yMidnight))
                
                // Stroke the current segment
                strokePath(currentPath, for: train, in: context)
                
                // Start a new path from 0 at midnight
                currentPath = Path()
                currentPath.move(to: CGPoint(x: 0, y: yMidnight))
                currentPath.addLine(to: p2)
                movedToStart = true
            }
        }
        
        // Stroke final remaining path
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
        if isEditing {
            color = .yellow // High contrast for editing
        } else if isSelected {
            color = .cyan // Glowing cyan for selection
        } else {
            color = train.priority > 7 ? .red : .white.opacity(0.6)
        }
        
        let lineWidth: CGFloat = isEditing ? 6 : (isSelected ? 4 : 2)
        
        context.drawLayer { subgroup in
            if isSelected {
                subgroup.addFilter(.shadow(color: color.opacity(0.8), radius: isEditing ? 12 : 6))
            }
            subgroup.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
    

    
    private func findTrainAtLocation(_ location: CGPoint) {
        let lineStationIds = Set(orderedStations.map { $0.id })
        let trains = manager.trains.filter { train in
            train.stops.contains { lineStationIds.contains($0.stationId) }
        }
        
        var bestTrain: Train? = nil
        var minDistance: CGFloat = 20.0 // Detection threshold in pixels
        
        for train in trains {
            var points: [CGPoint] = []
            for stop in train.stops {
                if let idx = orderedStations.firstIndex(where: { $0.id == stop.stationId }) {
                    let y = CGFloat(stationDistances[idx]) * pixelsPerKm + 50.0
                    if let arrival = stop.arrival { points.append(CGPoint(x: xFor(arrival), y: y)) }
                    if let departure = stop.departure { points.append(CGPoint(x: xFor(departure), y: y)) }
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
    
    private func checkSegments(_ points: [CGPoint], for train: Train, at location: CGPoint, minDist: inout CGFloat, best: inout Train?) {
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i+1]
            
            // MATH: Distance from point to line segment
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

// Helper View for Station Labels
struct StationLabelsView: View {
    let stations: [Node]
    let distances: [Double]
    let pixelsPerKm: CGFloat
    @Binding var selectedStation: LineScheduleView.StationSelection? // Changed Binding Type
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear // Container
            
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
                    .id(station.id) // TARGET FOR SCROLLING
                    .position(x: 70, y: y) // Center in the 140 width column
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
