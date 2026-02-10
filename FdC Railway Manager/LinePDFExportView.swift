import SwiftUI

struct LinePDFExportView: View {
    let line: RailwayLine
    let orderedStations: [Node]
    let trains: [Train]
    let network: RailwayNetwork
    
    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 8) {
                Text("ORARIO FERROVIARIO")
                    .font(.title.bold())
                Text("Linea: \(line.name)")
                    .font(.title2)
                Text("Generato il: \(Date().formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // Outward Section
            timetableSection(title: "ANDATA (Outward)", stations: orderedStations, isReturn: false)
            
            // Page Break simulation for content
            Divider()
            
            // Return Section
            timetableSection(title: "RITORNO (Return)", stations: orderedStations.reversed(), isReturn: true)
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .foregroundColor(.black)
    }
    
    private func timetableSection(title: String, stations: [Node], isReturn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            // Table
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    // Header Row: Train Numbers
                    GridRow {
                        Text("Stazione")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 120, height: 30, alignment: .leading)
                            .padding(.horizontal, 4)
                            .background(Color.gray.opacity(0.1))
                            .border(Color.black, width: 0.5)
                        
                        let sectionTrains = filterTrains(isReturn: isReturn)
                        ForEach(sectionTrains) { train in
                            VStack(spacing: 2) {
                                Text(train.type)
                                    .font(.system(size: 7))
                                Text("\(train.number ?? 0)")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .frame(width: 50, height: 30)
                            .border(Color.black, width: 0.5)
                        }
                    }
                    
                    // Station Rows
                    ForEach(stations) { station in
                        GridRow {
                            Text(station.name)
                                .font(.system(size: 9, weight: .semibold))
                                .frame(width: 120, height: 25, alignment: .leading)
                                .padding(.horizontal, 4)
                                .border(Color.black, width: 0.5)
                            
                            let sectionTrains = filterTrains(isReturn: isReturn)
                            ForEach(sectionTrains) { train in
                                let timeStr = getTimeFor(train: train, stationId: station.id)
                                Text(timeStr)
                                    .font(.system(size: 9, design: .monospaced))
                                    .frame(width: 50, height: 25)
                                    .border(Color.black, width: 0.5)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func filterTrains(isReturn: Bool) -> [Train] {
        let lineTrains = trains.filter { $0.lineId == line.id }
        
        let filtered = lineTrains.filter { train in
            guard train.stops.count >= 2 else { return false }
            let firstStation = train.stops.first?.stationId ?? ""
            let lastStation = train.stops.last?.stationId ?? ""
            
            let firstIdx = orderedStations.firstIndex(where: { $0.id == firstStation }) ?? -1
            let lastIdx = orderedStations.firstIndex(where: { $0.id == lastStation }) ?? -1
            
            if isReturn {
                return firstIdx > lastIdx && firstIdx != -1 && lastIdx != -1
            } else {
                return firstIdx < lastIdx && firstIdx != -1 && lastIdx != -1
            }
        }
        
        return filtered.sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
    }
    
    private func getTimeFor(train: Train, stationId: String) -> String {
        if let stop = train.stops.first(where: { $0.stationId == stationId }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            // Show Departure if both exist, except for last stop
            let isLast = train.stops.last?.stationId == stationId
            if isLast, let arr = stop.arrival {
                return formatter.string(from: arr)
            } else if let dep = stop.departure {
                return formatter.string(from: dep)
            }
        }
        return "-"
    }
}
