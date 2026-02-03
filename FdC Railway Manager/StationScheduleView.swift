import SwiftUI
import Combine

struct StationScheduleView: View {
    let station: Node
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    
    @State private var selectedTrack: String? = nil // Filter by Track
    @State private var sortOrder: SortOrder = .time
    
    enum SortOrder {
        case time, train, destination
    }
    
    struct StationArrival: Identifiable {
        let id = UUID() // Unique ID for the row
        let trainId: UUID
        let trainType: String // New
        let trainName: String
        let relationName: String
        let origin: String
        let destination: String
        let arrivalTime: Date?
        let departureTime: Date?
        let track: String?
        let isTerminus: Bool
    }
    
    @State private var arrivals: [StationArrival] = []
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack { // Removed NavigationStack
            // Filters
            HStack {
                Picker("Binario", selection: $selectedTrack) {
                    Text("Tutti").tag(String?.none)
                    ForEach(availableTracks, id: \.self) { track in
                        Text(track).tag(String?.some(track))
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Picker("Ordina per", selection: $sortOrder) {
                    Text("Ora").tag(SortOrder.time)
                    Text("Treno").tag(SortOrder.train)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding()
            
            // Table
            List {
                ForEach(filteredArrivals) { item in
                    HStack {
                        HStack(spacing: 4) {
                            if let arr = item.arrivalTime {
                                VStack(alignment: .trailing) {
                                    Text("Arr.")
                                        .font(.system(size: 8)).foregroundColor(.secondary)
                                    Text(format(arr))
                                        .font(.system(size: 14)).bold()
                                }
                                .frame(width: 45)
                            } else {
                                Spacer().frame(width: 45)
                            }
                            
                            if let dep = item.departureTime {
                                VStack(alignment: .leading) {
                                    Text("Part.")
                                        .font(.system(size: 8)).foregroundColor(.secondary)
                                    Text(format(dep))
                                        .font(.system(size: 14)).bold()
                                        .foregroundColor(.green)
                                }
                                .frame(width: 45)
                            } else {
                                Spacer().frame(width: 45)
                            }
                        }
                        .frame(width: 100)
                        
                        VStack(alignment: .leading) {
                            Text(item.trainType)
                                .font(.caption2).bold()
                                .foregroundColor(.secondary)
                            Text(item.trainName)
                                .font(.caption2).bold()
                                .padding(.horizontal, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .frame(width: 80, alignment: .leading)
                        .contentShape(Rectangle()) // Better tap area
                        .onTapGesture {
                            appState.jumpToTrainId = item.trainId
                        }
                        
                        VStack(alignment: .leading) {
                            Text(item.destination)
                                .font(.headline)
                            Text(item.relationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(item.track ?? "-")
                            .font(.title2)
                            .bold()
                            .frame(width: 40)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.2)))
                    }
                }
            }
            .listStyle(.plain)
        }
        .onAppear(perform: calculateArrivals)
        .onChange(of: station.id) { _ in calculateArrivals() }
        .onReceive(manager.objectWillChange) { _ in
            calculateArrivals()
        }
    }
    
    var availableTracks: [String] {
        let tracks = Set(arrivals.compactMap { $0.track })
        return Array(tracks).sorted()
    }
    
    var filteredArrivals: [StationArrival] {
        var list = arrivals
        
        // Filter
        if let track = selectedTrack {
            list = list.filter { $0.track == track }
        }
        
        // Sort
        switch sortOrder {
        case .time:
            list.sort { ($0.arrivalTime ?? $0.departureTime ?? Date.distantFuture) < ($1.arrivalTime ?? $1.departureTime ?? Date.distantFuture) }
        case .train:
            list.sort { $0.trainName < $1.trainName }
        case .destination:
            list.sort { $0.destination < $1.destination }
        }
        
        return list
    }
    
    func format(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    func calculateArrivals() {
        var results: [StationArrival] = []
        
        // Scan all trains
        for train in manager.trains {
            // Check if departures/arrivals are populated. If not, trigger a refresh.
            let hasTimes = train.stops.contains { $0.arrival != nil || $0.departure != nil }
            if !hasTimes && !train.stops.isEmpty {
                // If we are here, something is desynced. 
                // However, we shouldn't trigger a full validateSchedules on EVERY view refresh.
                // We assume manager.refreshSchedules was called during import/optimization.
            }

            // Relation description lookup
            let relationName: String = {
                if let lId = train.lineId, let line = network.lines.first(where: { $0.id == lId }) {
                    return line.name
                }
                return train.type
            }()
            
            let originName = getName(train.stops.first?.stationId ?? "")
            let destName = getName(train.stops.last?.stationId ?? "")
            
            // Check if the train stops at this station
            if let stop = train.stops.first(where: { $0.stationId == station.id }) {
                let isTerminus = train.stops.last?.stationId == station.id
                let isOrigin = train.stops.first?.stationId == station.id
                
                results.append(StationArrival(
                    trainId: train.id,
                    trainType: train.type, // New
                    trainName: train.name,
                    relationName: relationName,
                    origin: originName,
                    destination: destName,
                    arrivalTime: isOrigin ? nil : stop.arrival,
                    departureTime: isTerminus ? nil : stop.departure,
                    track: stop.track,
                    isTerminus: isTerminus
                ))
            }
        }
        
        // Sorting by time correctly handles 2000 vs current dates as long as they are consistent
        self.arrivals = results
    }
    
    func getName(_ id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? id
    }
}
