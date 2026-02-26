import SwiftUI

struct TrainSelectionPicker: View {
    let vehicleId: UUID
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    @Environment(\.dismiss) var dismiss
    
    @State private var useSmartFilter: Bool = true
    
    private var lastStationId: String? {
        let vehicleTrains = manager.trains.filter { $0.vehicleId == vehicleId && $0.departureTime != nil }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
        return vehicleTrains.last?.stops.last?.stationId
    }
    
    private var lastStationName: String {
        guard let id = lastStationId else { return "Nessuna" }
        return appState.railroad.network.nodes.first(where: { $0.id == id })?.name ?? id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Header
            Picker("Filtra per Linea", selection: $appState.lastVehicleAssignmentRouteId) {
                Text("Tutti i treni disponibili").tag(String?.none)
                Divider()
                ForEach(manager.sortedRoutes) { route in
                    Text(route.name).tag(String?.some(route.id))
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            List {
                let filteredTrains = manager.trains.filter { train in
                    let isAvailable = train.vehicleId == nil
                    let matchesLine = appState.lastVehicleAssignmentRouteId == nil || train.routeId == appState.lastVehicleAssignmentRouteId
                    
                    var matchesSmart = true
                    if useSmartFilter, let lastPos = lastStationId {
                        matchesSmart = train.stops.first?.stationId == lastPos
                    }
                    
                    return isAvailable && matchesLine && matchesSmart
                }
                
                if let lastPos = lastStationId {
                    smartFilterSection(lastPos)
                }
                
                if filteredTrains.isEmpty {
                    emptyTrainsSection
                } else {
                    Section {
                        ForEach(filteredTrains) { train in
                            trainSelectionRow(train)
                        }
                    }
                }
            }
        }
        .navigationTitle("Assegna Treno")
    }

    private func smartFilterSection(_ lastPos: String) -> some View {
        Section {
            let matchesSmartBinding = Binding<Bool>(
                get: { useSmartFilter },
                set: { useSmartFilter = $0 }
            )
            Toggle(isOn: matchesSmartBinding) {
                VStack(alignment: .leading) {
                    Text("Filtro intelligente").font(.subheadline).bold()
                    Text("Mostra solo treni partenti da \(lastStationName)")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyTrainsSection: some View {
        Section {
            Text(appState.lastVehicleAssignmentRouteId == nil ? "Tutti i treni hanno già un mezzo assegnato." : "Nessun treno disponibile per la linea selezionata.")
                .foregroundColor(.secondary)
                .italic()
                .padding()
        }
    }

    private func trainSelectionRow(_ train: Train) -> some View {
        let conflictsWithNew = checkPotentialConflict(train: train)
        return Button(action: { assignVehicleToTrain(train) }) {
            VStack(alignment: .leading, spacing: 6) {
                trainHeaderRow(train)
                trainRouteRow(train)
                
                if let conflict = conflictsWithNew {
                    conflictWarningRow(conflict)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func trainHeaderRow(_ train: Train) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(train.name).font(.headline)
                if let route = manager.routes.first(where: { $0.id == train.routeId }) {
                    Text(route.name).font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(train.type).font(.caption2).padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
        }
    }

    private func trainRouteRow(_ train: Train) -> some View {
        HStack(spacing: 4) {
            let originId = train.stops.first?.stationId ?? ""
            let originName = appState.railroad.network.nodes.first(where: { $0.id == originId })?.name ?? originId
            let isAtLastPos = originId == lastStationId
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.circle.fill")
                Text(originName)
                    .fontWeight(isAtLastPos ? .bold : .regular)
            }
            .foregroundColor(isAtLastPos ? .green : .primary)
            
            Text("→").foregroundColor(.secondary)
            
            let destId = train.stops.last?.stationId ?? ""
            let destName = appState.railroad.network.nodes.first(where: { $0.id == destId })?.name ?? destId
            Text(destName)
            
            Spacer()
            
            if let dep = train.departureTime {
                Text(dep.timeFormat).font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .font(.system(size: 11))
    }

    private func conflictWarningRow(_ conflict: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(conflict).font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.red)
        .padding(.vertical, 2)
    }

    private func assignVehicleToTrain(_ train: Train) {
        if let idx = manager.trains.firstIndex(where: { $0.id == train.id }) {
            manager.trains[idx].vehicleId = vehicleId
        }
        dismiss()
    }

    private func checkPotentialConflict(train: Train) -> String? {
        // Find existing trains for this vehicle
        let existing = manager.trains.filter { $0.vehicleId == vehicleId && $0.departureTime != nil }
        
        guard let newDep = train.departureTime else { return nil }
        
        for ex in existing {
            if let exArr = ex.stops.last?.arrival, let exDep = ex.departureTime {
                // If the new train starts before an existing one arrives
                if newDep < exArr.addingTimeInterval(15 * 60) && newDep > exDep.addingTimeInterval(-15 * 60) {
                    return "In conflitto con \(ex.name) (Arr: \(exArr.timeFormat))"
                }
                
                // If an existing train starts before the new one arrives
                if let newArr = train.stops.last?.arrival {
                    if exDep < newArr.addingTimeInterval(15 * 60) && exDep > newDep.addingTimeInterval(-15 * 60) {
                        return "In conflitto con \(ex.name) (Parte: \(exDep.timeFormat))"
                    }
                }
            }
        }
        
        return nil
    }
}
