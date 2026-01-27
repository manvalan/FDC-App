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
                                if let arr = cellData?.0 {
                                    Text("A: " + formatTime(arr))
                                        .font(.caption2)
                                        .foregroundColor(isConflict ? .white : .green)
                                }
                                if let dep = cellData?.1 {
                                    Text("P: " + formatTime(dep))
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func calculateScheduleTable() {
        // 1. Find all trains for this line
        let lineTrainIds = manager.trains.filter { train in
            guard let rId = train.relationId, let rel = network.relations.first(where: { $0.id == rId }) else { return false }
            return rel.lineId == line.id
        }
        
        // 2. Sort them by departure time
        self.sortedTrains = lineTrainIds.sorted { t1, t2 in
            (t1.departureTime ?? Date.distantPast) < (t2.departureTime ?? Date.distantPast)
        }
        
        // 3. Compute Schedule for each train
        var data: [UUID: [String: (Date?, Date?, String?)]] = [:]
        
        for train in sortedTrains {
            guard let depTime = train.departureTime,
                  let relId = train.relationId,
                  let rel = network.relations.first(where: { $0.id == relId }) else { continue }
            
            var trainSchedule: [String: (Date?, Date?, String?)] = [:]
            
            var currentTime = depTime
            var prevId = rel.originId
            
            // Origin
            // Dep only. Track? Origin isn't in stops usually, but we might want to infer it or just leave nil if not set.
            // Actually RelationStop doesn't include origin. So no track data for origin unless we add it to Relation struct.
            trainSchedule[prevId] = (nil, currentTime, nil)
            
            for stop in rel.stops {
                guard let distInfo = network.findShortestPath(from: prevId, to: stop.stationId) else { continue }
                let hours = distInfo.1 / (Double(train.maxSpeed) * 0.9)
                let arrivalDate = currentTime.addingTimeInterval(hours * 3600)
                
                let dwell = stop.isSkipped ? 0 : Double(stop.minDwellTime)
                let depDate = arrivalDate.addingTimeInterval(dwell * 60)
                
                // Store Arrival, Departure, Track
                trainSchedule[stop.stationId] = (arrivalDate, dwell > 0 ? depDate : nil, stop.track)
                
                currentTime = depDate
                prevId = stop.stationId
            }
            
            // Terminus
            if prevId != rel.destinationId {
                if let distInfo = network.findShortestPath(from: prevId, to: rel.destinationId) {
                    let hours = distInfo.1 / (Double(train.maxSpeed) * 0.9)
                    let arrivalDate = currentTime.addingTimeInterval(hours * 3600)
                    trainSchedule[rel.destinationId] = (arrivalDate, nil, nil) // Destination track?
                }
            }
            
            data[train.id] = trainSchedule
        }
        
        self.scheduleData = data
    }
}
