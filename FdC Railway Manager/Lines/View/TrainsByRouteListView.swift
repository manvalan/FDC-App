import SwiftUI
import Combine

/// Mostra i treni organizzati per rotta
/// Principio: "Code that fits in your head" - ogni componente ha una singola responsabilità
struct TrainsByRouteListView: View {
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    @State private var assignedCount: Int = 0
    @State private var showAssignmentAlert: Bool = false
    @State private var routeForCreation: TrainRoute? // Wizard Trigger
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Treni per Rotta").font(.headline).foregroundColor(appState.theme.dark)
            
            VStack(spacing: 16) {
                if !unassignedTrains.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: 6) {
                            ForEach(unassignedTrains) { train in
                                TrainRowButton(train: train)
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        unassignedHeader
                    }
                }
                
                ForEach(allRoutesGrouped, id: \.route.id) { item in
                    RouteTrainsSection(route: item.route, trains: item.trains, onCreateTrain: {
                        // Open Wizard
                        routeForCreation = item.route
                    })
                }
            }
            .alert("Assegnati \(assignedCount) treni alle linee.", isPresented: $showAssignmentAlert) {
                Button("OK", role: .cancel) { }
            }
            .sheet(item: $routeForCreation) { route in
                TrainCreationView(route: route)
            }
        }
    }
    
    private var unassignedHeader: some View {
        HStack {
            Text("Non Assegnati (\(unassignedTrains.count))")
                .font(.caption.bold())
                .foregroundColor(.orange)
            Spacer()
            Button("Auto-Assegna") {
                autoAssignTrains()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }
    
    /// Treni senza linea assegnata
    private var unassignedTrains: [Train] {
        linesManager.trains.filter { $0.routeId == nil || $0.routeId?.isEmpty == true }
    }
    
    /// Calcola quali rotte hanno treni, includendo anche le rotte vuote
    private var allRoutesGrouped: [(route: TrainRoute, trains: [Train])] {
        linesManager.routes.map { route in
            let trainsForRoute = linesManager.trains.filter { $0.routeId == route.id }
            return (route: route, trains: trainsForRoute)
        }
        .sorted { $0.route.name < $1.route.name }
    }
    
    private func autoAssignTrains() {
        var count = 0
        let allLines = linesManager.lines
        
        for index in linesManager.trains.indices {
            let train = linesManager.trains[index]
            guard train.routeId == nil || train.routeId?.isEmpty == true else { continue }
            guard !train.stops.isEmpty else { continue }
            
            // Cerca una rotta compatibile
            // Una rotta è compatibile se contiene tutte le stazioni del treno nello stesso ordine relativo
            let matchingRoutes = linesManager.routes.filter { route in
                isTrainCompatible(train, with: route)
            }
            
            if let bestMatch = matchingRoutes.first {
                // Assegna
                linesManager.trains[index].routeId = bestMatch.id
                count += 1
            }
        }
        
        assignedCount = count
        if count > 0 {
            showAssignmentAlert = true
            linesManager.objectWillChange.send() // Forza aggiornamento UI
        }
    }
    
    private func isTrainCompatible(_ train: Train, with route: TrainRoute) -> Bool {
        let trainStops = train.stops.map { $0.stationId }
        let lineStops = route.stationIds
        
        // Se il treno ha più fermate della linea, impossibile
        if trainStops.count > lineStops.count { return false }
        
        // Verifica sottosequenza (anche non contigua, se il treno salta fermate come i diretti)
        var trainIndex = 0
        var lineIndex = 0
        
        while trainIndex < trainStops.count && lineIndex < lineStops.count {
            if trainStops[trainIndex] == lineStops[lineIndex] {
                trainIndex += 1
            }
            lineIndex += 1
        }
        
        return trainIndex == trainStops.count
    }
}

/// Sezione che mostra i treni di una singola linea
private struct RouteTrainsSection: View {
    let route: TrainRoute
    let trains: [Train]
    let onCreateTrain: () -> Void
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        DisclosureGroup {
            if trains.isEmpty {
                Text("Nessun treno in orario")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        // Optional: Tap on empty state to create
                    }
                    .contextMenu {
                        Button(action: onCreateTrain) {
                            Label("Crea Nuova Corsa", systemImage: "plus")
                        }
                    }
            } else {
                VStack(spacing: 6) {
                    ForEach(trains, id: \.id) { train in
                        TrainRowButton(train: train)
                    }
                }
                .padding(.top, 4)
            }
        } label: {
            routeSectionHeader
                .contentShape(Rectangle()) // Make entire header tappable for context menu
                .contextMenu {
                    Button(action: onCreateTrain) {
                        Label("Crea Nuova Corsa", systemImage: "plus")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        linesManager.autoAssignRollingStock(for: route.id)
                    }) {
                        Label("Ottimizza Giri Macchina", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
        }
    }
    
    private var routeSectionHeader: some View {
        HStack {
            Text(route.name)
                .font(.caption.bold())
                .foregroundColor(appState.theme.dark)
            Spacer()
            Circle().fill(route.displayColor).frame(width: 8, height: 8)
        }
        .padding(.horizontal, 4)
    }
}

/// Bottone per un singolo treno
private struct TrainRowButton: View {
    let train: Train
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        Button(action: { appState.selectTrain(train.id) }) {
            HStack {
                trainTypeBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(train.name)
                        .font(.subheadline.bold())
                        .foregroundColor(appState.theme.dark)
                    
                    if let vid = train.vehicleId, let vehicle = linesManager.vehicles.first(where: { $0.id == vid }) {
                        Text(vehicle.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                departureTimeText
            }
            .padding(10)
            .background(appState.selectedTrainIds.contains(train.id) ? appState.theme.accent.opacity(0.1) : appState.theme.light.opacity(0.3))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Duplica", systemImage: "doc.on.doc") {
                // TODO: Logic to duplicate train
            }
            
            Divider()
            
            Button(role: .destructive) {
                linesManager.removeTrain(train.id)
            } label: {
                Label("Elimina Corsa", systemImage: "trash")
            }
        }
    }
    
    
    private var trainTypeBadge: some View {
        Text(train.type)
            .font(.system(size: 9, weight: .black))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(appState.theme.light)
            .foregroundColor(appState.theme.dark)
            .cornerRadius(4)
    }
    
    private var departureTimeText: some View {
        Text(train.departureTime ?? Date(), format: .dateTime.hour().minute())
            .font(.caption2)
            .monospaced()
    }
}
