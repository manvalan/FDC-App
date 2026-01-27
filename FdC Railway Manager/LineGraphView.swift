import SwiftUI

struct LineGraphView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    let line: RailwayLine
    
    // Data passed from parent
    let orderedStations: [Node]
    let stationDistances: [Double]
    let maxDistance: Double
    
    // Zoom/Pan State
    @State private var timeScale: CGFloat = 60.0 // Pixels per hour
    @State private var pixelsPerKm: CGFloat = 5.0 // Vertical Scale (Zoom) - Default reduced for better overview
    
    // Selection Wrapper (Identifiable for Sheet) -> Now Binding from Parent
    @Binding var selectedStation: LineScheduleView.StationSelection?
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        
                        // 1. Station Names Column
                        StationLabelsView(
                            stations: orderedStations,
                            distances: stationDistances,
                            pixelsPerKm: pixelsPerKm,
                            selectedStation: $selectedStation
                        )
                        .frame(width: 120) // Fixed width for labels
                        .background(Color(UIColor.systemBackground))
                        .zIndex(1) 
                        
                        // 2. The Graph
                        ZStack(alignment: .topLeading) {
                            // Background Grid
                            let graphHeight = max(geometry.size.height, maxDistance * pixelsPerKm + 100)
                            let graphWidth = max(geometry.size.width - 120, 24 * timeScale)
                            
                            drawGrid(width: graphWidth, height: graphHeight)
                            
                            // Train Plots
                            drawTrains(width: graphWidth)
                            
                            // Conflict Markers
                            drawConflicts(width: graphWidth)
                        }
                        .frame(width: max(geometry.size.width - 120, 24 * timeScale), 
                               height: maxDistance * pixelsPerKm + 100)
                    }
                }
            }
        }
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
        // Sheet removed - Parent handles split view
    }
    
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
                context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                context.draw(Text("\(hour):00").font(.caption), at: CGPoint(x: x + 5, y: 5))
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
            let calendar = Calendar.current
            
            for conflict in manager.conflictManager.conflicts {
                // Determine Y coordinate
                var y: CGFloat? = nil
                
                if conflict.locationType == .station {
                    let stationId = conflict.locationId.components(separatedBy: "::").first ?? ""
                    if let idx = orderedStations.firstIndex(where: { $0.id == stationId }) {
                         y = stationDistances[idx] * pixelsPerKm + 50
                    }
                } else {
                    // Line Conflict: Try to approximate Y based on Edge?
                    // Skipping visual mapping for simple line conflicts if we don't have endpoints easily
                    // Could try to find station previous to this edge?
                }
                
                if let y = y {
                    // Time X
                    let startX = xFor(conflict.timeStart)
                    let endX = xFor(conflict.timeEnd)
                    let conflictWidth = max(8, endX - startX)
                    
                    let rect = CGRect(x: startX - conflictWidth/2, y: y - 10, width: conflictWidth, height: 20)
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.red.opacity(0.6)))
                    context.draw(Image(systemName: "exclamationmark.triangle.fill"), at: CGPoint(x: startX, y: y))
                } else if conflict.locationType == .line {
                    // Try to visualize line conflict between two stations
                    if conflict.locationId.hasPrefix("EDGE::") {
                        let parts = conflict.locationId.replacingOccurrences(of: "EDGE::", with: "").components(separatedBy: "-")
                        if parts.count == 2 {
                            if let idx1 = orderedStations.firstIndex(where: { $0.id == parts[0] }),
                               let idx2 = orderedStations.firstIndex(where: { $0.id == parts[1] }) {
                                let y1 = stationDistances[idx1] * pixelsPerKm + 50
                                let y2 = stationDistances[idx2] * pixelsPerKm + 50
                                let midY = (y1 + y2) / 2
                                let startX = xFor(conflict.timeStart)
                                
                                context.fill(Path(ellipseIn: CGRect(x: startX - 8, y: midY - 8, width: 16, height: 16)), with: .color(.red.opacity(0.8)))
                                context.draw(Image(systemName: "bolt.fill"), at: CGPoint(x: startX, y: midY))
                            }
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
            // Filter trains relevant to this line
            let lineTrainIds = manager.trains.filter { train in
                guard let rId = train.relationId, let rel = network.relations.first(where: { $0.id == rId }) else { return false }
                return rel.lineId == line.id
            }
            
            for train in lineTrainIds {
                guard let depTime = train.departureTime, 
                      let relId = train.relationId, 
                      let rel = network.relations.first(where: { $0.id == relId }) else { continue }
                
                let calendar = Calendar.current
                let startHour = calendar.component(.hour, from: depTime)
                let startMin = calendar.component(.minute, from: depTime)
                let startOffsetHours = Double(startHour) + Double(startMin)/60.0
                
                var points: [CGPoint] = []
                var currentTime = depTime
                var prevId = rel.originId
                
                // Origin Point
                if let idx = orderedStations.firstIndex(where: { $0.id == prevId }) {
                    let y = stationDistances[idx] * pixelsPerKm + 50
                    let x = startOffsetHours * timeScale
                    points.append(CGPoint(x: x, y: y))
                }
                
                // Traverse stops
                for stop in rel.stops {
                     guard let distInfo = network.findShortestPath(from: prevId, to: stop.stationId) else { continue }
                     let distKm = distInfo.1
                     let hours = distKm / (Double(train.maxSpeed) * 0.9)
                     let arrivalDate = currentTime.addingTimeInterval(hours * 3600)
                     
                     if let idx = orderedStations.firstIndex(where: { $0.id == stop.stationId }) {
                         let y = stationDistances[idx] * pixelsPerKm + 50
                         let arrH = calendar.component(.hour, from: arrivalDate)
                         let arrM = calendar.component(.minute, from: arrivalDate)
                         let x = (Double(arrH) + Double(arrM)/60.0) * timeScale
                         points.append(CGPoint(x: x, y: y))
                     }
                     
                     let dwell = stop.isSkipped ? 0 : Double(stop.minDwellTime)
                     let depDate = arrivalDate.addingTimeInterval(dwell * 60)
                     if dwell > 0 {
                          if let idx = orderedStations.firstIndex(where: { $0.id == stop.stationId }) {
                             let y = stationDistances[idx] * pixelsPerKm + 50
                             let depH = calendar.component(.hour, from: depDate)
                             let depM = calendar.component(.minute, from: depDate)
                             let x = (Double(depH) + Double(depM)/60.0) * timeScale
                             points.append(CGPoint(x: x, y: y))
                         }
                     }
                     
                     currentTime = depDate
                     prevId = stop.stationId
                }
                
                // Terminus
                if prevId != rel.destinationId {
                     guard let distInfo = network.findShortestPath(from: prevId, to: rel.destinationId) else { continue }
                     let distKm = distInfo.1
                     let hours = distKm / (Double(train.maxSpeed) * 0.9)
                     let arrivalDate = currentTime.addingTimeInterval(hours * 3600)
                     
                     if let idx = orderedStations.firstIndex(where: { $0.id == rel.destinationId }) {
                         let y = stationDistances[idx] * pixelsPerKm + 50
                         let arrH = calendar.component(.hour, from: arrivalDate)
                         let arrM = calendar.component(.minute, from: arrivalDate)
                         let x = (Double(arrH) + Double(arrM)/60.0) * timeScale
                         points.append(CGPoint(x: x, y: y))
                     }
                }
                
                // Draw Path
                if !points.isEmpty {
                    let path = Path {
                        $0.move(to: points[0])
                        for p in points.dropFirst() {
                            $0.addLine(to: p)
                        }
                    }
                    context.stroke(path, with: .color(.primary), lineWidth: 2)
                    
                    if let first = points.first {
                        context.draw(Text(train.type + " " + train.name).font(.caption2).foregroundColor(.primary), at: CGPoint(x: first.x, y: first.y - 10))
                    }
                }
            }
        }
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
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.primary)
                            .padding(.trailing, 8)
                            .frame(height: 20)
                    }
                    .position(x: 60, y: y) // Center in the 120 width column
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
