import SwiftUI

struct StationOccupancyView: View {
    let station: Node
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    
    // Scale: Pixels per minute or hour
    @State private var timeScale: CGFloat = 60.0 // Pixels per hour (same as Main Graph if possible, or adjustable)
    
    // Calculated Data
    struct OccupationBlock: Identifiable {
        let id = UUID()
        let trainName: String
        let track: String
        let arrival: Date
        let departure: Date
        let type: String // "Fermata", "Passaggio"
    }
    
    @State private var blocks: [OccupationBlock] = []
    @State private var tracks: [String] = []
    
    // Constants
    let rowHeight: CGFloat = 40.0
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Occupazione Binari: \(station.name)")
                .font(.headline)
                .padding()
            
            // Toolbar for Scale?
            
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        // Background Grid (Time)
                        drawTimeGrid(width: max(geometry.size.width, 24 * timeScale), height: CGFloat(tracks.count) * rowHeight + 50)
                        
                        // Rows (Tracks)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(tracks, id: \.self) { track in
                                ZStack(alignment: .leading) {
                                    // Row Background
                                    Rectangle().fill(Color.gray.opacity(0.1))
                                        .frame(height: rowHeight - 2)
                                        .frame(maxWidth: .infinity)
                                    
                                    // Track Label (Sticky?)
                                    // ideally we'd want labels to be separate. 
                                    // For now just put them here, they scroll away.
                                    Text("Bin \(track)")
                                        .font(.caption)
                                        .bold()
                                        .padding(.leading, 4)
                                        .frame(width: 80, alignment: .leading)
                                }
                                .frame(height: rowHeight)
                            }
                        }
                        
                        // Blocks
                        ForEach(blocks) { block in
                            if let trackIndex = tracks.firstIndex(of: block.track) {
                                let y = CGFloat(trackIndex) * rowHeight
                                let startX = timeToX(block.arrival)
                                let endX = timeToX(block.departure)
                                let width = max(2, endX - startX)
                                
                                Rectangle()
                                    .fill(block.type == "Passaggio" ? Color.blue.opacity(0.5) : Color.green.opacity(0.6))
                                    .frame(width: width, height: rowHeight - 10)
                                    .cornerRadius(4)
                                    .overlay(
                                        Text(block.trainName)
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .padding(2)
                                    )
                                    .position(x: startX + width/2, y: y + rowHeight/2)
                                    .help("\(block.trainName): \(format(block.arrival)) - \(format(block.departure))")
                            }
                        }
                    }
                    .frame(width: max(geometry.size.width, 24 * timeScale), height: CGFloat(tracks.count) * rowHeight + 50)
                }
            }
        }
        .onAppear {
            calculateOccupancy()
        }
    }
    
    func timeToX(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        return (CGFloat(h) + CGFloat(m)/60.0) * timeScale
    }
    
    func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    private func drawTimeGrid(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            for hour in 0...24 {
                let x = CGFloat(hour) * timeScale
                let path = Path {
                    $0.move(to: CGPoint(x: x, y: 0))
                    $0.addLine(to: CGPoint(x: x, y: height))
                }
                context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                context.draw(Text("\(hour):00").font(.caption), at: CGPoint(x: x + 5, y: 5))
            }
        }
    }
    
    private func calculateOccupancy() {
        var results: [OccupationBlock] = []
        var foundTracks: Set<String> = []
        
        for train in manager.trains {
            // Find if this train stops/passes at this station
            if let stop = train.stops.first(where: { $0.stationId == station.id }) {
                // We need arrival OR departure to show something
                let arrival = stop.arrival ?? stop.departure ?? Date()
                let departure = stop.departure ?? stop.arrival ?? Date().addingTimeInterval(300)
                
                let track = stop.track ?? "1"
                foundTracks.insert(track)
                
                results.append(OccupationBlock(
                    trainName: train.name,
                    track: track,
                    arrival: arrival,
                    departure: stop.isSkipped ? arrival.addingTimeInterval(120) : departure,
                    type: stop.isSkipped ? "Passaggio" : "Fermata"
                ))
            }
        }
        
        self.tracks = Array(foundTracks).sorted()
        if self.tracks.isEmpty { self.tracks = ["1", "2"] }
        self.blocks = results
    }
}
