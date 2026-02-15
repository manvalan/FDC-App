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
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredArrivals) { item in
                        arrivalRow(for: item)
                            .onTapGesture {
                                appState.jumpToTrainId = item.trainId
                            }
                            .contextMenu {
                                Button {
                                    appState.selectTrain(item.trainId)
                                    appState.isInspectorEditingMode = true
                                    appState.showPanel(.inspector)
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
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
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
                let originName = getName(originId)
                let destName = getName(destId)
                
                results.append(StationArrival(
                    trainId: train.id,
                    trainType: train.type,
                    trainName: train.name,
                    relationName: relationName,
                    origin: originName,
                    destination: destName,
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
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.primary)
                } else if let arr = item.arrivalTime {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ARR")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.secondary)
                        Text(arr.timeFormat)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 70, alignment: .leading)
            
            // INFO BLOCK
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    let catColor = TrainCategory(rawValue: item.trainType)?.color ?? .gray
                    
                    Text(item.trainType.prefix(3).uppercased())
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(catColor.opacity(0.2))
                        .foregroundColor(catColor)
                        .cornerRadius(4)
                    
                    Text(item.trainName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .bold()
                    Text(item.destination)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if let vName = item.vehicleName {
                         Text("• \(vName)")
                             .font(.caption2)
                             .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // TRACK BUTTON
            Button(action: { editingArrival = item }) {
                VStack(spacing: 0) {
                    Text(item.track ?? "-")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text("BIN")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 50, height: 50)
                .background(item.track != nil ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .foregroundColor(item.track != nil ? .blue : .gray)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(item.track != nil ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(appState.selectedTrainIds.contains(item.trainId) ? appState.theme.accent : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
