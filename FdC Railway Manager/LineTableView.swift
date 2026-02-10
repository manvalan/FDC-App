import SwiftUI
import Combine

struct LineTableView: View {
    @EnvironmentObject var appState: AppState
    let line: RailwayLine
    
    // Data passed from parent
    let orderedStations: [Node]
    
    // Processed Data
    @Binding var selectedStation: LineScheduleView.StationSelection? 
    
    @State private var selectedConflict: ScheduleConflict? = nil
    @State private var isOptimizing = false
    
    // Computed Properties for real-time reactivity
    private var sortedTrains: [Train] {
        appState.railroad.lines.trains
            .filter { $0.lineId == line.id }
            .sorted { (t1, t2) in
                (t1.departureTime ?? .distantPast) < (t2.departureTime ?? .distantPast)
            }
    }
    
    private var scheduleData: [UUID: [String: (Date?, Date?, String?)]] {
        var data: [UUID: [String: (Date?, Date?, String?)]] = [:]
        for train in sortedTrains {
            var trainSchedule: [String: (Date?, Date?, String?)] = [:]
            for stop in train.stops {
                trainSchedule[stop.stationId] = (stop.arrival, stop.departure, stop.track)
            }
            data[train.id] = trainSchedule
        }
        return data
    }
    
    var lineConflicts: [ScheduleConflict] {
        appState.railroad.lines.conflictManager.conflicts.filter { c in
            sortedTrains.contains(where: { $0.id == c.trainAId || $0.id == c.trainBId })
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // TOOLBAR TOP
            HStack {
                Text(line.name)
                    .font(.headline)
                
                Spacer()
                
                if !lineConflicts.isEmpty {
                    Button(action: optimizeLineWithAI) {
                        HStack {
                            if isOptimizing {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text("Risolvi AI")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isOptimizing)
                }
                
                Button(role: .destructive, action: deleteAllLineTrains) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .help("Elimina tutti i treni di questa linea")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    // FIXED COLUMN: Station Names
                    VStack(spacing: 0) {
                        Text("station".localized)
                            .font(.headline)
                            .frame(width: 150, height: 50, alignment: .leading)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.1))
                            .border(Color.gray.opacity(0.3))
                        
                        ForEach(orderedStations) { station in
                            Button(action: {
                                selectedStation = LineScheduleView.StationSelection(id: station.id)
                            }) {
                                Text(station.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(selectedStation?.id == station.id ? .blue : .primary)
                                    .frame(width: 150, height: 50, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .background(selectedStation?.id == station.id ? Color.blue.opacity(0.1) : Color(UIColor.systemBackground))
                            .border(Color.gray.opacity(0.2))
                            .buttonStyle(.plain)
                        }
                    }
                    .zIndex(1)
                    
                    // SCROLLABLE CONTENT: Trains and Times
                    ScrollView(.horizontal, showsIndicators: true) {
                        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                            // Header Row (Trains)
                            GridRow {
                                ForEach(sortedTrains) { train in
                                    Button(action: {
                                        appState.selectTrain(train.id)
                                    }) {
                                        VStack(alignment: .center, spacing: 2) {
                                            Text(train.type)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(appState.selectedTrainIds.contains(train.id) ? .white : .secondary)
                                            Text(train.name)
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(appState.selectedTrainIds.contains(train.id) ? .white : .primary)
                                        }
                                        .frame(width: 100, height: 50)
                                        .background(appState.selectedTrainIds.contains(train.id) ? Color.blue : Color.gray.opacity(0.1))
                                        .border(Color.gray.opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Data Rows
                            ForEach(orderedStations) { station in
                                GridRow {
                                    ForEach(sortedTrains) { train in
                                        ScheduleCellView(
                                            train: train,
                                            station: station,
                                            cellData: scheduleData[train.id]?[station.id],
                                            conflicts: appState.railroad.lines.conflictManager.conflicts,
                                            selectedConflict: $selectedConflict
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .popover(item: $selectedConflict) { conflict in
                    // (Popover content stays the same)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Dettagli Conflitto").font(.headline)
                        }
                        Divider()
                        
                        Text(conflict.description)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Text("Posizione:").bold()
                            Text(conflict.locationName)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Treni:").bold()
                            Text("\(conflict.trainAName) \(conflict.trainAId == conflict.trainBId ? "" : "e \(conflict.trainBName)")")
                        }
                        .font(.caption)
                        
                        // PROPOSTA DI RISOLUZIONE: Binario Alternativo
                        let stationId: String? = {
                            let parts = conflict.locationId.components(separatedBy: "::")
                            return parts.count >= 2 ? parts[1] : nil
                        }()
                        
                        if let sid = stationId,
                           let node = appState.railroad.network.nodes.first(where: { $0.id == sid }) {
                            
                            let trainsToFix: [Train] = {
                                var list: [Train] = []
                                if let tA = appState.railroad.lines.trains.first(where: { $0.id == conflict.trainAId }) { list.append(tA) }
                                if conflict.trainAId != conflict.trainBId,
                                   let tB = appState.railroad.lines.trains.first(where: { $0.id == conflict.trainBId }) { list.append(tB) }
                                return list
                            }()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                Text("SUGGERIMENTI:").font(.system(size: 10, weight: .black)).foregroundColor(.blue)
                                
                                ForEach(trainsToFix) { train in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Sposta \(train.name) su:").font(.caption).bold()
                                        
                                        let stopIdx = train.stops.firstIndex(where: { $0.stationId == sid }) ?? 0
                                        let prevSid = stopIdx > 0 ? train.stops[stopIdx - 1].stationId : nil
                                        let nextSid = stopIdx < train.stops.count - 1 ? train.stops[stopIdx + 1].stationId : nil
                                        let suggested = node.getTracksByProvenance(from: prevSid, nextStationId: nextSid, forLine: train.lineId)
                                        let currentTrack = train.stops[stopIdx].track ?? "1"
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                ForEach(suggested, id: \.self) { track in
                                                    if track != currentTrack {
                                                        Button("Bin. \(track)") {
                                                            applyTrackResolution(trainId: train.id, stationId: sid, track: track)
                                                        }
                                                        .buttonStyle(.borderedProminent)
                                                        .controlSize(.mini)
                                                    }
                                                }
                                                
                                                // Fallback: mostra tutti gli altri binari se non sono tra i suggeriti
                                                let maxP = node.platforms ?? 1
                                                if maxP > 1 {
                                                    ForEach(1...maxP, id: \.self) { p in
                                                        let track = "\(p)"
                                                        if !suggested.contains(track) && track != currentTrack {
                                                            Button("Bin. \(track)") {
                                                                applyTrackResolution(trainId: train.id, stationId: sid, track: track)
                                                            }
                                                            .buttonStyle(.bordered)
                                                            .controlSize(.mini)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .frame(width: 320)
                    .frame(minHeight: 250, maxHeight: 450)
                }
            }
        }
        .onReceive(appState.railroad.lines.objectWillChange) { _ in
            // This forces the view to re-evaluate computed properties when trains change
        }
    }
    
    // MARK: - Actions
    
    private func deleteAllLineTrains() {
        appState.railroad.lines.trains.removeAll { $0.lineId == line.id }
        appState.railroad.lines.validateSchedules()
    }
    
    private let geneticOptimizer = GeneticOptimizer()
    
    private func optimizeLineWithAI() {
        isOptimizing = true
        let focusIds = Set(sortedTrains.map { $0.id })
        let aiService = RailwayAIService.shared
        
        let request = aiService.createRequest(
            nodes: appState.railroad.network.nodes,
            edges: appState.railroad.network.edges,
            trains: appState.railroad.lines.trains,
            fixedTrainIds: [],
            activeAgentIds: focusIds,
            temporalObstacles: nil,
            conflicts: appState.railroad.lines.conflictManager.conflicts
        )
        
        Task {
            do {
                // 1. AI Cloud Pass (Bridge Combine to Async)
                var resolutionsApplied = false
                for try await response in aiService.optimize(request: request).values {
                    if let resolutions = response.resolutions, !resolutions.isEmpty {
                        appState.railroad.lines.applyResolutions(resolutions, network: appState.railroad.network, trainMapping: aiService.getTrainMapping())
                        resolutionsApplied = true
                    }
                }
                
                // 2. Native GA Final Refinement (Clean up routing, platforms, and minor shifts)
                // Usiamo il GeneticOptimizer nativo ultra-veloce per la pulizia finale
                let refinedTrains = await geneticOptimizer.optimize(
                    newTrains: appState.railroad.lines.trains.filter { focusIds.contains($0.id) },
                    existingTrains: appState.railroad.lines.trains.filter { !focusIds.contains($0.id) },
                    nodes: appState.railroad.network.nodes,
                    edges: appState.railroad.network.edges,
                    iterations: 150
                )
                
                // Aggiorna i treni con i risultati raffinati dal GA
                for refined in refinedTrains {
                    if let idx = appState.railroad.lines.trains.firstIndex(where: { $0.id == refined.id }) {
                        appState.railroad.lines.trains[idx] = refined
                    }
                }
                
                
                appState.railroad.lines.validateSchedules()
                
            } catch {
                print("❌ Optimization failed: \(error)")
            }
            isOptimizing = false
        }
    }
    
    private func applyTrackResolution(trainId: UUID, stationId: String, track: String) {
        if let tIdx = appState.railroad.lines.trains.firstIndex(where: { $0.id == trainId }) {
            if let sIdx = appState.railroad.lines.trains[tIdx].stops.firstIndex(where: { $0.stationId == stationId }) {
                appState.railroad.lines.trains[tIdx].stops[sIdx].track = track
                appState.railroad.lines.validateSchedules()
                selectedConflict = nil
            }
        }
    }
    
    private func formatTime(_ date: Date, ref: Date? = nil) -> String {
        var str = date.timeFormat
        if let r = ref {
            let cal = Calendar.current
            let d1 = date.normalized()
            let r1 = r.normalized()
            
            if !cal.isDate(d1, inSameDayAs: r1) {
                 let diff = cal.dateComponents([.day], from: r1, to: d1).day ?? 0
                 if diff > 0 { str += " (+\(diff))" }
                 else if diff < 0 { str += " (\(diff))" }
            }
        }
        return str
    }
}

// MARK: - Subviews

struct ScheduleCellView: View {
    @EnvironmentObject var appState: AppState
    let train: Train
    let station: Node
    let cellData: (Date?, Date?, String?)?
    let conflicts: [ScheduleConflict]
    @Binding var selectedConflict: ScheduleConflict?
    
    var body: some View {
        let cellConflicts = conflicts.filter { c in
            guard c.trainAId == train.id || c.trainBId == train.id else { return false }
            return c.locationId.contains(station.id)
        }
        let isConflict = !cellConflicts.isEmpty
        let stop = train.stops.first { $0.stationId == station.id }
        
        return Button(action: {
            if let first = cellConflicts.first {
                selectedConflict = first
            }
        }) {
            VStack(spacing: 1) {
                let stops = train.stops
                let trainStart = stops.first?.departure ?? train.departureTime
                
                if let arrDate = cellData?.0 {
                    let displayArr = stop?.plannedArrival ?? arrDate
                    Text(formatTime(displayArr, ref: trainStart))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(isConflict ? .white : (stop?.plannedArrival != nil ? .yellow : .green))
                }
                
                if let depDate = cellData?.1 {
                    Text(formatTime(depDate, ref: trainStart))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(isConflict ? .white : (stop?.customDwellSeconds != nil ? .yellow : .blue))
                }
                
                if let track = cellData?.2 {
                    Text(track)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isConflict ? Color.white.opacity(0.3) : Color.orange.opacity(0.2))
                        .cornerRadius(3)
                        .foregroundColor(isConflict ? .white : .primary)
                }
                
                if isConflict {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 10))
                }
                
                if cellData?.0 == nil && cellData?.1 == nil {
                    Text("-")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .frame(width: 100, height: 50)
            .background(isConflict ? Color.red.opacity(0.8) : Color.clear)
            .border(Color.gray.opacity(0.05))
        }
        .buttonStyle(.plain)
        .disabled(!isConflict)
    }
    
    private func formatTime(_ date: Date, ref: Date? = nil) -> String {
        var str = date.timeFormat
        if let r = ref {
            let cal = Calendar.current
            let d1 = date.normalized()
            let r1 = r.normalized()
            
            if !cal.isDate(d1, inSameDayAs: r1) {
                 let diff = cal.dateComponents([.day], from: r1, to: d1).day ?? 0
                 if diff > 0 { str += " (+\(diff))" }
                 else if diff < 0 { str += " (\(diff))" }
            }
        }
        return str
    }
}
