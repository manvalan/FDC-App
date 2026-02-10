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
        let stopIndex: Int
        let vehicleName: String?
    }
    
    @State private var arrivals: [StationArrival] = []
    @State private var editingArrival: StationArrival? = nil // For track selection sheet
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
                                    Text(arr.timeFormat)
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
                                    Text(dep.timeFormat)
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
                        .padding(.vertical, 4)
                        .background(
                            appState.selectedTrainIds.contains(item.trainId) 
                            ? Color.blue.opacity(0.2) 
                            : Color.clear
                        )
                        .cornerRadius(4)
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
                            
                            if let vName = item.vehicleName {
                                Text(vName)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(3)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            editingArrival = item
                        }) {
                            Text(item.track ?? "-")
                                .font(.title2)
                                .bold()
                                .frame(width: 40)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.2)))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
        }
        .onAppear(perform: calculateArrivals)
        .onChange(of: station.id) { _ in calculateArrivals() }
        .onReceive(appState.railroad.lines.objectWillChange.debounce(for: .milliseconds(100), scheduler: RunLoop.main)) { _ in
            calculateArrivals()
        }
        .sheet(item: $editingArrival) { item in
            if let train = manager.trains.first(where: { $0.id == item.trainId }),
               let binding = manager.binding(for: train) {
                TrackSelectionSheet(
                    train: binding,
                    stopIndex: item.stopIndex,
                    network: network
                )
            }
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
    
    
    func calculateArrivals() {
        let currentStationId = station.id
        let allNodes = network.nodes
        let nodeMap = Dictionary(uniqueKeysWithValues: allNodes.map { ($0.id, $0.name) })
        
        var results: [StationArrival] = []
        
        for train in manager.trains {
            // Check if departures/arrivals are populated. If not, trigger a refresh.
            guard let stopIndex = train.stops.firstIndex(where: { $0.stationId == currentStationId }) else { continue }
            
            let stop = train.stops[stopIndex]
            let relationName: String = {
                if let lId = train.lineId, let line = manager.lines.first(where: { $0.id == lId }) {
                    return line.name
                }
                return train.type
            }()
            
            let isTerminus = stopIndex == train.stops.count - 1
            let isOrigin = stopIndex == 0
            
            let originId = train.stops.first?.stationId ?? ""
            let destId = train.stops.last?.stationId ?? ""
            
            results.append(StationArrival(
                trainId: train.id,
                trainType: train.type, 
                trainName: train.name,
                relationName: relationName,
                origin: nodeMap[originId] ?? originId,
                destination: nodeMap[destId] ?? destId,
                arrivalTime: isOrigin ? nil : (stop.plannedArrival ?? stop.arrival),
                departureTime: isTerminus ? nil : (stop.plannedDeparture ?? stop.departure),
                track: stop.track,
                isTerminus: isTerminus,
                stopIndex: stopIndex,
                vehicleName: {
                    if let vId = train.vehicleId, let v = manager.vehicles.first(where: { $0.id == vId }) {
                        return v.name
                    }
                    return nil
                }()
            ))
        }
        
        self.arrivals = results
    }
    
    func getName(_ id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? id
    }
}
