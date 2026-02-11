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
    
    @State private var filteredArrivals: [StationArrival] = [] // Ora è @State, non computed
    
    var body: some View {
        VStack {
            // Filters
            HStack {
                Picker("Binario", selection: $selectedTrack) {
                    Text("Tutti").tag(String?.none)
                    ForEach(availableTracks, id: \.self) { track in
                        Text(track).tag(String?.some(track))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedTrack) { _ in applyFilters() }
                
                Spacer()
                
                Picker("Ordina per", selection: $sortOrder) {
                    Text("Ora").tag(SortOrder.time)
                    Text("Treno").tag(SortOrder.train)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .onChange(of: sortOrder) { _ in applyFilters() }
            }
            .padding()
            
            // Table
            if filteredArrivals.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "tram.fill.tunnel")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Nessun treno programmato")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Debug info
                    VStack(alignment: .leading) {
                        Text("Debug Info:").font(.caption).bold()
                        Text("Stazione: \(station.name) (\(station.id))").font(.caption2)
                        Text("Totale Treni: \(manager.trains.count)").font(.caption2)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredArrivals) { item in
                    // ... (stesso contenuto della riga) ...
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.jumpToTrainId = item.trainId
                        }
                        .contextMenu {
                            Button {
                                appState.selectTrain(item.trainId)
                                appState.isInspectorEditingMode = true
                                appState.isInspectorVisible = true
                            } label: {
                                Label("Modifica Treno", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                if let idx = manager.trains.firstIndex(where: { $0.id == item.trainId }) {
                                    manager.trains.remove(at: idx)
                                    // Trigger refresh
                                    calculateArrivals()
                                }
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
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
            } // Close else block
        }
        .onAppear(perform: calculateArrivals)
        .onChange(of: station.id) { _ in calculateArrivals() }
        .onReceive(appState.railroad.lines.objectWillChange.debounce(for: .milliseconds(300), scheduler: RunLoop.main)) { _ in
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
            } else if let train = manager.trains.first(where: { $0.id == item.trainId }) {
                // Fallback safe binding creation
                 TrackSelectionSheet(
                    train: Binding(
                        get: { train },
                        set: { if let idx = manager.trains.firstIndex(where: {$0.id == train.id}) { manager.trains[idx] = $0 } }
                    ),
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
    
    // Removed computed property filteredArrivals
    
    func applyFilters() {
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
        
        self.filteredArrivals = list
    }
    
    func calculateArrivals() {
        let currentStationId = station.id
        // Capture snapshot for background processing
        let trains = manager.trains
        let lines = manager.lines
        let vehicles = manager.vehicles
        let nodes = network.nodes
        
        Task(priority: .userInitiated) {
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.name) })
            let lineMap = Dictionary(uniqueKeysWithValues: lines.map { ($0.id, $0) })
            let vehicleMap = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0) })
            
            var results: [StationArrival] = []
            
            for train in trains {
                // Fast checking first
                guard let stopIndex = train.stops.firstIndex(where: { $0.stationId == currentStationId }) else { continue }
                
                let stop = train.stops[stopIndex]
                
                // Optimized lookup
                let relationName: String
                if let lId = train.lineId, let line = lineMap[lId] {
                    relationName = line.name
                } else {
                    relationName = train.type
                }
                
                let vehicleName: String?
                if let vId = train.vehicleId, let v = vehicleMap[vId] {
                    vehicleName = v.name
                } else {
                    vehicleName = nil
                }
                
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
                    vehicleName: vehicleName
                ))
            }
            
            await MainActor.run {
                self.arrivals = results
                self.applyFilters()
            }
        }
    }
    
    func getName(_ id: String) -> String {
        network.nodes.first(where: { $0.id == id })?.name ?? id
    }
    
    @ViewBuilder
    private func arrivalRow(for item: StationArrival) -> some View {
        HStack(spacing: 12) {
            // TIME BLOCK
            VStack(alignment: .leading, spacing: 2) {
                if let dep = item.departureTime {
                    Text(dep.timeFormat)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                } else if let arr = item.arrivalTime {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ARR")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.secondary)
                        Text(arr.timeFormat)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 60, alignment: .leading)
            
            // INFO BLOCK
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.trainType)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.trainType == "Regionale" ? Color.blue : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Text(item.trainName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(item.destination)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // TRACK BUTTON
            Button(action: { editingArrival = item }) {
                VStack(spacing: 0) {
                    Text(item.track ?? "-")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("BIN")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 45, height: 45)
                .background(item.track != nil ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                .foregroundColor(item.track != nil ? .blue : .secondary)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(item.track != nil ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}
