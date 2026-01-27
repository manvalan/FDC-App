import SwiftUI

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
    
    var body: some View {
        VStack { // Removed NavigationStack
            // Filters
            HStack {
                Picker("Binario", selection: $selectedTrack) {
                    Text("Tutti").tag(String?.none)
                    // Dynamic list of tracks?
                    // For now hardcoded common ones or extracted from data
                    ForEach(availableTracks, id: \.self) { track in
                        Text(track).tag(String?.some(track))
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Picker("Ordina", selection: $sortOrder) {
                    Text("Ora").tag(SortOrder.time)
                    Text("Treno").tag(SortOrder.train)
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            // Table
            List {
                ForEach(filteredArrivals) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(format(item.arrivalTime ?? item.departureTime))
                                .font(.title3).bold()
                                .foregroundColor(item.arrivalTime != nil ? .primary : .green)
                            Text(item.trainName)
                                .font(.caption)
                                .bold()
                        }
                        .frame(width: 80, alignment: .leading)
                        
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
            guard let startTime = train.departureTime,
                  let relId = train.relationId,
                  let relation = network.relations.first(where: { $0.id == relId }) else { continue }
            
            // Calculate Schedule for this train to find time at this station
            // Reusing logic (should be centralized, but copying for now is faster)
            
            var currentTime = startTime
            var prevId = relation.originId
            
            // Check Origin
            if relation.originId == station.id {
                results.append(StationArrival(
                    trainId: train.id,
                    trainName: train.type + " " + train.name,
                    relationName: relation.name,
                    origin: station.name,
                    destination: getName(relation.destinationId),
                    arrivalTime: nil,
                    departureTime: currentTime,
                    track: nil, // Origin track? Need to check relation stops logic? No, origin is not in stops.
                    isTerminus: false
                ))
            }
            
            // Traverse Stops
            for stop in relation.stops {
                guard let distInfo = network.findShortestPath(from: prevId, to: stop.stationId) else { continue }
                let hours = distInfo.1 / (Double(train.maxSpeed) * 0.9)
                let arrivalDate = currentTime.addingTimeInterval(hours * 3600)
                
                let dwell = stop.isSkipped ? 0 : Double(stop.minDwellTime)
                let depDate = arrivalDate.addingTimeInterval(dwell * 60)
                
                if stop.stationId == station.id {
                    results.append(StationArrival(
                        trainId: train.id,
                        trainName: train.type + " " + train.name,
                        relationName: relation.name,
                        origin: getName(relation.originId),
                        destination: getName(relation.destinationId),
                        arrivalTime: arrivalDate,
                        departureTime: stop.isSkipped ? nil : depDate,
                        track: stop.track,
                        isTerminus: false
                    ))
                }
                
                currentTime = depDate
                prevId = stop.stationId
            }
            
            // Check Destination
            if relation.destinationId == station.id && prevId != relation.destinationId {
                if let distInfo = network.findShortestPath(from: prevId, to: relation.destinationId) {
                    let hours = distInfo.1 / (Double(train.maxSpeed) * 0.9)
                    let arrivalDate = currentTime.addingTimeInterval(hours * 3600)
                    
                    results.append(StationArrival(
                        trainId: train.id,
                        trainName: train.type + " " + train.name,
                        relationName: relation.name,
                        origin: getName(relation.originId),
                        destination: getName(relation.destinationId),
                        arrivalTime: arrivalDate,
                        departureTime: nil,
                        track: nil, // Destination track logic?
                        isTerminus: true
                    ))
                }
            }
        }
        
        self.arrivals = results
    }
    
    func getName(_ id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? id
    }
}
