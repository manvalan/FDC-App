import SwiftUI
import Combine

/// ViewModel per la gestione dell'editing di una linea ferroviaria.
/// Segue i principi di separazione delle responsabilità e "Code That Fits in Your Head".
final class LineEditViewModel: ObservableObject {
    // MARK: - State Properties
    
    @Published var lineName: String = ""
    @Published var codePrefix: String = ""
    @Published var numberPrefix: Int = 0
    @Published var cadenceFrequency: Double = 60.0
    @Published var lineColor: Color = .blue
    @Published var terminalTracks: [String: String] = [:]
    
    @Published var startStationId: String = ""
    @Published var viaStationIds: [String] = []
    @Published var endStationId: String = ""
    @Published var stationSequence: [String] = []
    
    @Published var errorMessage: String? = nil
    @Published var lineAnalysis: RailwayAIService.LineAnalysis? = nil
    @Published var isAnalyzingLine: Bool = false
    @Published var proposedOffset: Double? = nil
    
    @Published var isRunningOptimizer: Bool = false
    
    // MARK: - Dependencies
    
    private var lineId: String = ""
    private var appState: AppState?
    private let cadenceOptimizer = CadenceOptimizer()
    private var cancellables = Set<AnyCancellable>()
    
    private var network: NetworkModel { appState?.railroad.network ?? NetworkModel() }
    private var lines: LinesManager { appState?.railroad.lines ?? LinesManager(railroad: RailroadNetwork()) }
    
    // MARK: - Initialization
    
    init() {}
    
    func setup(lineId: String, appState: AppState) {
        self.lineId = lineId
        self.appState = appState
        
        loadLineData()
        setupObservers()
    }
    
    // MARK: - Logic
    
    /// Carica i dati iniziali della linea
    private func loadLineData() {
        guard let line = lines.lines.first(where: { $0.id == lineId }) else {
            return
        }
        
        lineName = line.name
        codePrefix = line.codePrefix ?? ""
        numberPrefix = line.numberPrefix ?? 0
        cadenceFrequency = line.cadenceFrequency ?? 60.0
        lineColor = Color(hex: line.color ?? "") ?? .blue
        terminalTracks = line.terminalTracks
        
        startStationId = line.originId
        endStationId = line.destinationId
        stationSequence = line.stops.map { $0.stationId }
        
        if let appState = appState, appState.useCloudAI && stationSequence.count >= 2 {
            triggerLineAnalysis()
        }
    }
    
    private func setupObservers() {
        $stationSequence
            .sink { [weak self] newSeq in
                guard let self = self else { return }
                if let appState = self.appState, appState.useCloudAI && newSeq.count >= 2 {
                    self.triggerLineAnalysis()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Salva le modifiche apportate
    func saveChanges() -> Bool {
        guard let index = lines.lines.firstIndex(where: { $0.id == lineId }) else { return false }
        
        appState?.railroad.network.createCheckpoint()
        
        let hexColor = lineColor.toHex()
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        
        // Update the existing line
        lines.lines[index].name = lineName
        lines.lines[index].color = hexColor
        lines.lines[index].originId = stationSequence.first ?? startStationId
        lines.lines[index].destinationId = stationSequence.last ?? endStationId
        lines.lines[index].stops = stops
        lines.lines[index].codePrefix = codePrefix.isEmpty ? nil : codePrefix
        lines.lines[index].numberPrefix = numberPrefix == 0 ? nil : numberPrefix
        lines.lines[index].cadenceFrequency = cadenceFrequency
        lines.lines[index].terminalTracks = terminalTracks
        
        // Update all trains of this line to use these tracks at terminal stations
        for tIdx in lines.trains.indices {
            if lines.trains[tIdx].lineId == lineId {
                // Update start stop
                if let firstId = stationSequence.first, let track = terminalTracks[firstId] {
                    if let sIdx = lines.trains[tIdx].stops.firstIndex(where: { $0.stationId == firstId }) {
                        lines.trains[tIdx].stops[sIdx].track = track
                        lines.trains[tIdx].stops[sIdx].isManualTrack = true
                    }
                }
                // Update end stop
                if let lastId = stationSequence.last, let track = terminalTracks[lastId] {
                    if let sIdx = lines.trains[tIdx].stops.firstIndex(where: { $0.stationId == lastId }) {
                        lines.trains[tIdx].stops[sIdx].track = track
                        lines.trains[tIdx].stops[sIdx].isManualTrack = true
                    }
                }
            }
        }
        
        lines.validateSchedules()
        return true
    }
    
    /// Avvia l'analisi AI della linea
    func triggerLineAnalysis() {
        Task {
            await MainActor.run { isAnalyzingLine = true }
            do {
                let analysis = try await RailwayAIService.shared.analyzeLine(
                    name: lineName.isEmpty ? "Line" : lineName,
                    stationIds: stationSequence,
                    nodes: network.nodes,
                    edges: network.edges
                )
                await MainActor.run { self.lineAnalysis = analysis }
            } catch {
                print("❌ AI Line Analysis failed: \(error)")
            }
            await MainActor.run { isAnalyzingLine = false }
        }
    }
    
    /// Trova il momento ideale per il cadenzamento
    func findIdealOffset() {
        Task {
            await MainActor.run { isRunningOptimizer = true }
            let line = RailwayLine(
                id: lineId,
                name: lineName,
                stops: stationSequence.map { RelationStop(stationId: $0) }
            )
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: line, 
                frequency: cadenceFrequency, 
                existingTrains: lines.trains.filter { $0.lineId != lineId }, 
                network: network
            )
            await MainActor.run { 
                self.proposedOffset = offset
                self.isRunningOptimizer = false
            }
        }
    }
    
    /// Ritorna suggerimenti di stazioni adiacenti
    func getSuggestions() -> [Node] {
        guard let lastId = stationSequence.last else { return [] }
        let connectedIds = network.getNeighborStations(for: lastId)
        return network.nodes.filter { node in
            connectedIds.contains(node.id) &&
            (node.type == .station || node.type == .interchange) &&
            node.id != lastId
        }
        .sorted { $0.name < $1.name }
    }
    
    /// Ottimizza l'assegnazione dei mezzi
    func autoAssignRollingStock() {
        appState?.railroad.network.createCheckpoint()
        lines.autoAssignRollingStock(for: lineId)
    }
    
    /// Handlers per il picking sulla mappa o lista
    func handleStationSelection(type: PickerType, stationId: String) {
        switch type {
        case .start:
            startStationId = stationId
            if stationSequence.isEmpty {
                stationSequence = [stationId]
            } else {
                stationSequence[0] = stationId
            }
        case .via(let idx):
            if idx < viaStationIds.count {
                viaStationIds[idx] = stationId
            }
        case .end:
            endStationId = stationId
            if stationSequence.count >= 1 {
                stationSequence[stationSequence.count - 1] = stationId
            }
        case .manual:
            stationSequence.append(stationId)
        }
    }
}
