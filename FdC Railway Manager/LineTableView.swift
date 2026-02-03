import SwiftUI

struct LineTableView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    let line: RailwayLine
    
    // Data passed from parent
    let orderedStations: [Node]
    
    // Processed Data
    // We organize data as: [StationID : [TrainID : (Arrival, Departure, Track)]]
    // But for the View, we need:
    // Columns: [Train] (Sorted by first departure)
    // Rows: [Station]
    // Cell: Time + Track
    
    @Binding var selectedStation: LineScheduleView.StationSelection? // Added Binding
    
    @State private var sortedTrains: [Train] = []
    @State private var scheduleData: [UUID: [String: (Date?, Date?, String?)]] = [:] // TrainID -> StationID -> (Arr, Dep, Track)
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                // Header Row
                GridRow {
                    Text("Stazione")
                        .font(.headline)
                        .frame(width: 150, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .border(Color.gray.opacity(0.3))
                    
                    ForEach(sortedTrains) { train in
                        VStack(alignment: .center) {
                            Text(train.type)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(train.name)
                                .font(.caption)
                                .bold()
                        }
                        .frame(width: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .border(Color.gray.opacity(0.3))
                    }
                }
                
                // Data Rows
                ForEach(orderedStations) { station in
                    GridRow {
                        // Station Name (Button for Selection)
                        Button(action: {
                            selectedStation = LineScheduleView.StationSelection(id: station.id)
                        }) {
                            Text(station.name)
                                .font(.subheadline)
                                .foregroundColor(selectedStation?.id == station.id ? .blue : .primary)
                                .frame(width: 150, alignment: .leading)
                                .padding(8)
                        }
                        .background(selectedStation?.id == station.id ? Color.blue.opacity(0.1) : Color.clear)
                        .border(Color.gray.opacity(0.2))
                        .buttonStyle(.plain)
                        
                        // Train Times
                        ForEach(sortedTrains) { train in
                            let cellData = scheduleData[train.id]?[station.id]
                            
                            // Check Conflict: station-specific or line-segment conflict involving this train and station
                            let isConflict = manager.conflictManager.conflicts.contains { c in
                                guard c.trainAId == train.id || c.trainBId == train.id else { return false }
                                if c.locationType == .station {
                                    return c.locationId.hasPrefix(station.id)
                                } else {
                                    // Segment conflict: does it involve this station?
                                    return c.locationId.contains(station.id)
                                }
                            }
                            
                            VStack(spacing: 2) {
                                let isFirstStop = train.stops.first?.stationId == station.id
                                let trainStart = train.stops.first?.departure ?? train.departureTime
                                if let arr = cellData?.0, !isFirstStop {
                                    Text("A: " + formatTime(arr, ref: trainStart))
                                        .font(.caption2)
                                        .foregroundColor(isConflict ? .white : .green)
                                }
                                let isLastStop = train.stops.last?.stationId == station.id
                                if let dep = cellData?.1, !isLastStop {
                                    Text("P: " + formatTime(dep, ref: trainStart))
                                        .font(.caption2)
                                        .foregroundColor(isConflict ? .white : .blue)
                                }
                                if let track = cellData?.2 {
                                    Text(track)
                                        .font(.caption2)
                                        .bold()
                                        .padding(2)
                                        .background(isConflict ? Color.white.opacity(0.3) : Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                if isConflict {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.white)
                                        .font(.caption2)
                                }
                                if cellData?.0 == nil && cellData?.1 == nil {
                                    Text("-")
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }
                            .frame(width: 100, height: 50)
                            .background(isConflict ? Color.red.opacity(0.8) : Color.clear) // Red background for conflict
                            .border(Color.gray.opacity(0.1))
                        }
                    }
                }
            }
        }
        .onAppear {
            calculateScheduleTable()
        }
    }
    
    private func formatTime(_ date: Date, ref: Date? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        var str = formatter.string(from: date)
        if let r = ref {
            let cal = Calendar.current
            if !cal.isDate(date, inSameDayAs: r) {
                 let diff = cal.dateComponents([.day], from: r, to: date).day ?? 0
                 if diff > 0 { str += " (+\(diff))" }
                 else if diff < 0 { str += " (\(diff))" }
            }
        }
        return str
    }
    
    private func calculateScheduleTable() {
        // 1. Find all trains for this line
        let lineTrains = manager.trains.filter { $0.lineId == line.id }
        
        // 2. Sort them by departure time
        self.sortedTrains = lineTrains.sorted { t1, t2 in
            (t1.departureTime ?? Date.distantPast) < (t2.departureTime ?? Date.distantPast)
        }
        
        // 3. Compute Schedule for each train - USE PRE-CALCULATED STOP DATA
        var data: [UUID: [String: (Date?, Date?, String?)]] = [:]
        
        for train in sortedTrains {
            var trainSchedule: [String: (Date?, Date?, String?)] = [:]
            
            for stop in train.stops {
                trainSchedule[stop.stationId] = (stop.arrival, stop.departure, stop.track)
            }
            
            data[train.id] = trainSchedule
        }
        
        self.scheduleData = data
    }
}
