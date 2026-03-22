import SwiftUI
import Combine

/// ViewModel per la gestione dell'editing di una rotta commerciale (TrainRoute).
/// Segue i principi di separazione delle responsabilità e "Code That Fits in Your Head".
final class RouteEditViewModel: ObservableObject {
    // MARK: - State Properties
    
    @Published var routeName: String = ""
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
    @Published var routeAnalysis: RailwayAIService.RouteAnalysis? = nil
    @Published var isAnalyzingRoute: Bool = false
    @Published var proposedOffset: Double? = nil
    
    @Published var isRunningOptimizer: Bool = false
    
    // MARK: - Dependencies
    
    private var routeId: String = ""
    private var appState: AppState?
    var aiService: RailwayAIService = .shared
    private let cadenceOptimizer = CadenceOptimizer()
    private var cancellables = Set<AnyCancellable>()
    
    private var network: NetworkModel { appState?.railroad.network ?? NetworkModel() }
    var lines: LinesManager { appState?.railroad.lines ?? LinesManager(network: NetworkModel()) }
    
    // MARK: - Initialization
    
    init() {}
    
    func setup(routeId: String, appState: AppState) {
        self.routeId = routeId
        self.appState = appState
        
        loadLineData()
        setupObservers()
    }
    
    // MARK: - Logic
    
    /// Carica i dati iniziali della linea
    private func loadLineData() {
        guard let route = lines.routes.first(where: { $0.id == routeId }) else {
            return
        }
        
        routeName = route.name
        codePrefix = route.serviceCodePrefix ?? ""
        numberPrefix = route.numberPrefix ?? 0
        cadenceFrequency = 60.0 // cadenceFrequency non è più in TrainRoute
        lineColor = Color(hex: route.color ?? "") ?? .blue
        terminalTracks = [:] // terminalTracks non è più in TrainRoute
        
        startStationId = route.originStationId
        endStationId = route.destinationStationId
        stationSequence = route.stationIds
        
        if let appState = appState, appState.useCloudAI && stationSequence.count >= 2 {
            triggerRouteAnalysis()
        }
    }
    
    private func setupObservers() {
        $stationSequence
            .sink { [weak self] newSeq in
                guard let self = self else { return }
                if let appState = self.appState, appState.useCloudAI && newSeq.count >= 2 {
                    self.triggerRouteAnalysis()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Salva le modifiche apportate
    func saveChanges() -> Bool {
        guard let index = lines.routes.firstIndex(where: { $0.id == routeId }) else { return false }
        
        appState?.railroad.network.createCheckpoint()
        
        let hexColor = lineColor.toHex()
        
        // Update the existing route
        lines.routes[index].name = routeName
        lines.routes[index].color = hexColor
        lines.routes[index].originStationId = stationSequence.first ?? startStationId
        lines.routes[index].destinationStationId = stationSequence.last ?? endStationId
        lines.routes[index].stationIds = stationSequence
        lines.routes[index].serviceCodePrefix = codePrefix.isEmpty ? nil : codePrefix
        lines.routes[index].numberPrefix = numberPrefix == 0 ? nil : numberPrefix
        
        // Update all trains of this route to use these tracks at terminal stations
        for tIdx in lines.trains.indices {
            if lines.trains[tIdx].routeId == routeId {
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
    
    /// Avvia l'analisi AI della rotta
    func triggerRouteAnalysis() {
        Task {
            await MainActor.run { isAnalyzingRoute = true }
            do {
                let analysis = try await aiService.analyzeRoute(
                    name: routeName.isEmpty ? "Route" : routeName,
                    stationIds: stationSequence,
                    nodes: network.nodes,
                    edges: network.edges
                )
                await MainActor.run { self.routeAnalysis = analysis }
            } catch {
                print("❌ AI Route Analysis failed: \(error)")
            }
            await MainActor.run { isAnalyzingRoute = false }
        }
    }
    
    /// Trova il momento ideale per il cadenzamento
    func findIdealOffset() {
        Task {
            await MainActor.run { isRunningOptimizer = true }
            let route = TrainRoute(
                id: routeId,
                name: routeName,
                stationIds: stationSequence
            )
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: route, 
                frequency: cadenceFrequency, 
                existingTrains: lines.trains.filter { $0.routeId != routeId }, 
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
        lines.autoAssignRollingStock(for: routeId)
    }
    
    /// Handlers per il picking sulla mappa o lista
    func handleStationSelection(type: PickerType, stationId: String) {
        if appState?.mapEditMode == .erasePath {
             stationSequence.removeAll(where: { $0 == stationId })
             return
        }
        
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
            if !stationSequence.contains(stationId) || appState?.mapEditMode == .brushPath {
                stationSequence.append(stationId)
            }
        }
    }
}
