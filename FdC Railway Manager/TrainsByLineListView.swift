import SwiftUI
import Combine

/// Mostra i treni organizzati per linea
/// Principio: "Code that fits in your head" - ogni componente ha una singola responsabilità
struct TrainsByLineListView: View {
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    @State private var assignedCount: Int = 0
    @State private var showAssignmentAlert: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Treni per Linea").font(.headline).foregroundColor(appState.theme.dark)
            
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
                
                ForEach(allLinesGrouped, id: \.line.id) { item in
                    LineTrainsSection(line: item.line, trains: item.trains, onCreateTrain: {
                        createNewTrain(for: item.line)
                    })
                }
            }
            .alert("Assegnati \(assignedCount) treni alle linee.", isPresented: $showAssignmentAlert) {
                Button("OK", role: .cancel) { }
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
        linesManager.trains.filter { $0.lineId == nil || $0.lineId?.isEmpty == true }
    }
    
    /// Calcola quali linee hanno treni, includendo anche le linee vuote
    private var allLinesGrouped: [(line: RailwayLine, trains: [Train])] {
        linesManager.lines.map { line in
            let trainsForLine = linesManager.trains.filter { $0.lineId == line.id }
            return (line: line, trains: trainsForLine)
        }
        .sorted { $0.line.name < $1.line.name }
    }
    
    private func createNewTrain(for line: RailwayLine) {
        var newTrain = Train(
            id: UUID(),
            name: "\(line.codePrefix ?? "NUM") \(Int.random(in: 1000...9999))",
            type: "Regionale",
            lineId: line.id
        )
        // Pre-populate stops from line definition
        newTrain.stops = line.stops.map { stop in
            var newStop = stop
            newStop.id = UUID()
            return newStop
        }
        
        linesManager.trains.append(newTrain)
        
        // Open Inspector immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            appState.selectTrain(newTrain.id)
            appState.isInspectorEditingMode = true // Auto enter edit mode
        }
    }
    
    private func autoAssignTrains() {
        var count = 0
        let allLines = linesManager.lines
        
        for index in linesManager.trains.indices {
            let train = linesManager.trains[index]
            guard train.lineId == nil || train.lineId?.isEmpty == true else { continue }
            guard !train.stops.isEmpty else { continue }
            
            // Cerca una linea compatibile
            // Una linea è compatibile se contiene tutte le stazioni del treno nello stesso ordine relativo
            let matchingLines = allLines.filter { line in
                isTrainCompatible(train, with: line)
            }
            
            if let bestMatch = matchingLines.first {
                // Assegna
                linesManager.trains[index].lineId = bestMatch.id
                count += 1
            }
        }
        
        assignedCount = count
        if count > 0 {
            showAssignmentAlert = true
            linesManager.objectWillChange.send() // Forza aggiornamento UI
        }
    }
    
    private func isTrainCompatible(_ train: Train, with line: RailwayLine) -> Bool {
        let trainStops = train.stops.map { $0.stationId }
        let lineStops = line.stops.map { $0.stationId }
        
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
private struct LineTrainsSection: View {
    let line: RailwayLine
    let trains: [Train]
    let onCreateTrain: () -> Void
    @EnvironmentObject var appState: AppState
    
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
            lineSectionHeader
                .contentShape(Rectangle()) // Make entire header tappable for context menu
                .contextMenu {
                    Button(action: onCreateTrain) {
                        Label("Crea Nuova Corsa", systemImage: "plus")
                    }
                }
        }
    }
    
    private var lineSectionHeader: some View {
        HStack {
            Text(line.name)
                .font(.caption.bold())
                .foregroundColor(appState.theme.dark)
            Spacer()
            Circle().fill(line.uiColor).frame(width: 8, height: 8)
        }
        .padding(.horizontal, 4)
    }
}

/// Bottone per un singolo treno
private struct TrainRowButton: View {
    let train: Train
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: { appState.selectTrain(train.id) }) {
            HStack {
                trainTypeBadge
                Text(train.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
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
            /*
             Button("Elimina", systemImage: "trash", role: .destructive) {
                // Logic to delete train -> Need access to LinesManager or pass closure
             }
             */
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
