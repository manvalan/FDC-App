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
        VStack(spacing: 0) {
            // Header with filters
            VStack(spacing: 12) {
                // Station title
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(station.name)
                            .font(.title2.bold())
                            .foregroundColor(appState.theme.dark)
                        Text("Tabellone Orari")
                            .font(.caption)
                            .foregroundColor(appState.theme.medium)
                    }
                    Spacer()
                }
                
                // Filters row
                HStack(spacing: 12) {
                    // Track filter
                    Menu {
                        Button {
                            selectedTrack = nil
                        } label: {
                            Label("Tutti i binari", systemImage: selectedTrack == nil ? "checkmark" : "")
                        }
                        
                        Divider()
                        
                        ForEach(availableTracks, id: \.self) { track in
                            Button {
                                selectedTrack = track
                            } label: {
                                Label("Binario \(track)", systemImage: selectedTrack == track ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right.square")
                                .font(.caption)
                            Text(selectedTrack ?? "Tutti")
                                .font(.subheadline.bold())
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(appState.theme.dark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(appState.theme.backgroundSecondary)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Sort picker
                    Picker("Ordina per", selection: $sortOrder) {
                        Label("Ora", systemImage: "clock").tag(SortOrder.time)
                        Label("Treno", systemImage: "tram").tag(SortOrder.train)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .padding()
            .background(appState.theme.surface)
            
            Divider()
            
            // Content
            if filteredArrivals.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(appState.theme.accent.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "tram.fill.tunnel")
                            .font(.system(size: 40))
                            .foregroundColor(appState.theme.accent)
                    }
                    
                    VStack(spacing: 6) {
                        Text("Nessun treno programmato")
                            .font(.headline)
                            .foregroundColor(appState.theme.dark)
                        Text("Non ci sono treni previsti per questa stazione")
                            .font(.subheadline)
                            .foregroundColor(appState.theme.medium)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
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
                                            calculateArrivals()
                                        }
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(appState.theme.background)
        .onAppear(perform: calculateArrivals)
        .onChange(of: station.id) { _ in calculateArrivals() }
        .onChange(of: selectedTrack) { _ in applyFilters() }
        .onChange(of: sortOrder) { _ in applyFilters() }
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
        let routes = manager.routes
        let vehicles = manager.vehicles
        let nodes = network.nodes
        
        Task(priority: .userInitiated) {
            var nodeMap: [String: String] = [:]
            for node in nodes { nodeMap[node.id] = node.name }
            var routeMap: [String: TrainRoute] = [:]
            for route in routes { routeMap[route.id] = route }
            var vehicleMap: [UUID: RailwayVehicle] = [:]
            for vehicle in vehicles { vehicleMap[vehicle.id] = vehicle }
            
            var results: [StationArrival] = []
            
            for train in trains {
                // Fast checking first
                guard let stopIndex = train.stops.firstIndex(where: { $0.stationId == currentStationId }) else { continue }
                
                let stop = train.stops[stopIndex]
                
                // Optimized lookup
                let relationName: String
                if let rId = train.routeId, let route = routeMap[rId] {
                    relationName = route.name
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
        HStack(spacing: 16) {
            // TIME BLOCK with glassmorphic background
            VStack(alignment: .center, spacing: 2) {
                if let dep = item.departureTime {
                    Text(dep.timeFormat)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(appState.theme.dark)
                } else if let arr = item.arrivalTime {
                    VStack(alignment: .center, spacing: 1) {
                        Text("ARR")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(appState.theme.medium)
                            .tracking(1)
                        Text(arr.timeFormat)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(appState.theme.medium)
                    }
                }
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(appState.theme.backgroundSecondary)
            )
            
            // INFO BLOCK
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    let catColor = TrainCategory(rawValue: item.trainType)?.color ?? .gray
                    
                    // Train type badge
                    Text(item.trainType.prefix(3).uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(catColor.opacity(0.15))
                        .foregroundColor(catColor)
                        .cornerRadius(6)
                    
                    Text(item.trainName)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(appState.theme.dark)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "arrow.forward")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(appState.theme.accent)
                    
                    Text(item.destination)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(appState.theme.medium)
                    
                    if let vName = item.vehicleName {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(appState.theme.line)
                        Text(vName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(appState.theme.medium)
                    }
                }
            }
            
            Spacer()
            
            // TRACK BUTTON with new design
            Button(action: { editingArrival = item }) {
                VStack(spacing: 2) {
                    Text(item.track ?? "-")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(item.track != nil ? appState.theme.accent : appState.theme.medium)
                    Text("BIN")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(item.track != nil ? appState.theme.accent.opacity(0.7) : appState.theme.medium)
                }
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.track != nil ? appState.theme.accent.opacity(0.1) : appState.theme.backgroundSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.track != nil ? appState.theme.accent.opacity(0.3) : appState.theme.line.opacity(0.2), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(appState.theme.surface)
        .cornerRadius(12)
        .shadow(color: appState.theme.line.opacity(0.08), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    appState.selectedTrainIds.contains(item.trainId) 
                        ? appState.theme.accent 
                        : appState.theme.line.opacity(0.1), 
                    lineWidth: appState.selectedTrainIds.contains(item.trainId) ? 2 : 1
                )
        )
    }
}
