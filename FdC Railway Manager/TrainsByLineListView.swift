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
        VStack(alignment: .leading, spacing: 12) {
            Text("Treni per Linea").font(.headline)
            
            List {
                if !unassignedTrains.isEmpty {
                    Section(header: unassignedHeader) {
                        ForEach(unassignedTrains) { train in
                            TrainRowButton(train: train)
                        }
                    }
                }
                
                ForEach(linesWithTrains, id: \.line.id) { item in
                    LineTrainsSection(line: item.line, trains: item.trains)
                }
            }
            .listStyle(.insetGrouped)
            .frame(minHeight: 400)
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
    
    /// Calcola quali linee hanno treni
    private var linesWithTrains: [(line: RailwayLine, trains: [Train])] {
        linesManager.lines.compactMap { line in
            let trainsForLine = linesManager.trains.filter { $0.lineId == line.id }
            guard !trainsForLine.isEmpty else { return nil }
            return (line: line, trains: trainsForLine)
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
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Section(header: lineSectionHeader) {
            ForEach(trains, id: \.id) { train in
                TrainRowButton(train: train)
            }
        }
    }
    
    private var lineSectionHeader: some View {
        Text(line.name)
            .font(.caption.bold())
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
                Text(train.name).bold()
                Spacer()
                departureTimeText
            }
        }
    }
    
    
    private var trainTypeBadge: some View {
        Text(train.type)
            .font(.caption)
            .padding(4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(4)
    }
    
    private var departureTimeText: some View {
        Text(train.departureTime ?? Date(), format: .dateTime.hour().minute())
            .font(.caption2)
            .monospaced()
    }
}
