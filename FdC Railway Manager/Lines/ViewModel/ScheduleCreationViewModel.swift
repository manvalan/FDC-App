import SwiftUI
import Combine

// MARK: - ScheduleMode & NumberParity (tipi condivisi tra View e ViewModel)

/// Modalità di generazione dell'orario: corsa singola, cadenzata o Taktfahrplan.
enum ScheduleMode: String, CaseIterable, Identifiable {
    case single = "single_trip"
    case cadenced = "cadenced_trip"
    case taktfahrplan = "taktfahrplan"
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .single:        return "single_trip".localized
        case .cadenced:      return "cadenced_trip".localized
        case .taktfahrplan:  return "Taktfahrplan"
        }
    }
}

/// Parità della numerazione treni: numeri pari o dispari.
enum NumberParity: String, CaseIterable, Identifiable {
    case even = "even"
    case odd  = "odd"
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .even: return "even".localized
        case .odd:  return "odd".localized
        }
    }
}

// MARK: - Takt Diagnostic

// TaktDiagnosticEntry moved to TaktEngine.swift

// MARK: - ViewModel

/// ViewModel principale per la creazione degli orari ferroviari.
/// Gestisce tutta la logica di business: generazione treni, ottimizzazione,
/// allineamento Takt, calcolo percorsi e suggerimento veicoli.
@MainActor
final class ScheduleCreationViewModel: ObservableObject {

    // MARK: Dependencies (weak to avoid retain cycles with EnvironmentObjects)
    private weak var network: NetworkModel?
    private weak var manager: LinesManager?
    private weak var appState: AppState?
    /// Strong references ai placeholder creati dal convenience init.
    /// Evitano la dealloc prematura finché `injectDependencies()` non li sostituisce.
    private var placeholderRetain: [AnyObject] = []
    let line: TrainRoute

    var aiService: RailwayAIService = .shared

    // MARK: - Specialized Services (Modularization)
    private var kinematicCalculator: KinematicCalculator
    private var taktEngine: TaktEngine
    private var pathResolver: PathResolver
    private var suitabilityEngine: VehicleSuitabilityEngine
    private var generationEngine: ScheduleGenerationEngine

    // MARK: - Scheduling state

    @Published var mode: ScheduleMode = .single
    @Published var startTime: Date = Date()
    @Published var endTime: Date = Date().addingTimeInterval(3600 * 4)
    @Published var intervalMinutes: Int = 60
    @Published var selectedTrainType: TrainCategory = .regional
    @Published var selectedVehicle: Vehicle? = nil
    @Published var suggestedVehicles: [Vehicle] = []

    @Published var preferredParity: NumberParity = .even {
        didSet { syncParityNumbers() }
    }
    @Published var startNumber: Int = 2 {
        didSet { returnStartNumber = (startNumber % 2 == 0) ? 1 : 2 }
    }
    @Published var returnStartNumber: Int = 1

    // MARK: - Path state
    @Published var startStationId: String = ""
    @Published var endStationId: String = ""
    @Published var stationSequence: [String] = []
    @Published var skippedStopIds: Set<String> = []

    // MARK: - Taktfahrplan
    @Published var taktStationId: String = ""
    @Published var isMainLine: Bool = true

    var useTaktAlignment: Bool { mode == .taktfahrplan }

    // MARK: - Return
    @Published var scheduleReturn: Bool = true

    // MARK: - AI / status
    @Published var aiStatus: String? = nil
    @Published var routeAnalysis: RailwayAIService.RouteAnalysis? = nil
    @Published var isAnalyzingRoute: Bool = false

    // MARK: - Preview / results
    @Published var previewCount: Int = 0
    @Published var estimatedTravelTime: Int = 0
    @Published var estimatedDistance: Double = 0
    @Published var generatedTrains: [Train]? = nil
    /// Caratteristiche fisiche calcolate della linea, aggiornate ad ogni cambio di percorso.
    @Published var lineCharacteristics: LineCharacteristics = LineCharacteristics(
        totalDistance: 0, averageStopDistance: 0, numberOfStops: 0,
        maxLineSpeed: 160, serviceType: .regional, frequency: nil,
        maxGradient: nil, isElectrified: true
    )

    // MARK: - Model / vehicle
    @Published var selectedModel: TrainModel? = nil
    @Published var trains: [Train] = []
    @Published var conflicts: [ScheduleConflict] = []

    // MARK: - Optimizers
    @Published var optimizeVehicleRotation: Bool = true
    @Published var minimumTurnaroundTime: Int = 15
    @Published var useDepartureOptimizer: Bool = true
    @Published var optimizerProgress: Double = 0.0
    @Published var localProposedOffset: Double? = nil

    // Proposed optimized times
    @Published var proposedOutboundTime: Date? = nil
    @Published var proposedReturnTime: Date? = nil
    @Published var proposedInterval: Int? = nil
    @Published var proposedReturnInterval: Int? = nil

    // MARK: - Internal
    var aiTask: Task<Void, Never>? = nil
    var optimizationStartTime: Date? = nil
    var isInitializing: Bool = true
    /// Cache per le caratteristiche altimetriche della linea (invalidata al cambio percorso).
    private var cachedAltitudeCharacteristics: (totalElevationGain: Double?, maxGradient: Double?, avgGradient: Double?)?
    let cadenceOptimizer = CadenceOptimizer()

    let departureOptimizer = DepartureTimeOptimizer()

    // MARK: - Init

    /// Inizializzatore completo con tutte le dipendenze reali.
    init(route: TrainRoute,
         initialMode: ScheduleMode = .single,
         network: NetworkModel,
         manager: LinesManager,
         appState: AppState) {
        self.line = route
        self.mode = initialMode
        self.network = network
        self.manager = manager
        self.appState = appState
        self.startStationId = line.originStationId
        self.endStationId   = line.destinationStationId
        
        self.kinematicCalculator = KinematicCalculator(network: network)
        self.taktEngine = TaktEngine(network: network, kinematicCalculator: kinematicCalculator)
        self.pathResolver = PathResolver(network: network)
        self.suitabilityEngine = VehicleSuitabilityEngine(kinematicCalculator: kinematicCalculator)
        self.generationEngine = ScheduleGenerationEngine(network: network, trainManager: manager)
    }

    /// Inizializzatore di comodo usato dalla View prima che gli EnvironmentObject siano disponibili.
    /// Chiamare `injectDependencies` in `onAppear` per fornire gli oggetti reali.
    convenience init(line: TrainRoute, initialMode: ScheduleMode = .single) {
        let placeholderNetworkModel = NetworkModel()
        let placeholderNetwork = RailwayNetwork()
        let placeholderManager = TrainManager(network: placeholderNetworkModel)
        self.init(route: line, initialMode: initialMode,
                  network: placeholderNetwork,
                  manager: placeholderManager,
                  appState: AppState.shared)
        self.placeholderRetain = [placeholderNetwork, placeholderManager]
    }

    // MARK: - Iniezione dipendenze reali (chiamato da onAppear)

    /// Inietta le dipendenze reali (EnvironmentObject) dopo che la View è apparsa.
    func injectDependencies(network: RailwayNetwork, manager: TrainManager, appState: AppState) {
        self.network  = network
        self.manager  = manager
        self.appState = appState
        // Rilascia i placeholder ora che le dipendenze reali sono iniettate
        self.placeholderRetain = []
        
        // Re-initialize services with real network
        self.kinematicCalculator = KinematicCalculator(network: network)
        self.taktEngine = TaktEngine(network: network, kinematicCalculator: kinematicCalculator)
        self.pathResolver = PathResolver(network: network)
        self.suitabilityEngine = VehicleSuitabilityEngine(kinematicCalculator: kinematicCalculator)
        self.generationEngine = ScheduleGenerationEngine(network: network, trainManager: manager)
    }

    // MARK: - Dependency accessors (crash-safe with diagnostic message)

    private var net: RailwayNetwork {
        guard let n = network else {
            fatalError("⚠️ [ScheduleCreationViewModel] network è nil. Assicurarsi di chiamare injectDependencies() in onAppear prima di accedere alla rete.")
        }
        return n
    }
    private var mgr: TrainManager {
        guard let m = manager else {
            fatalError("⚠️ [ScheduleCreationViewModel] manager è nil. Assicurarsi di chiamare injectDependencies() in onAppear prima di accedere al manager.")
        }
        return m
    }
    private var state: AppState {
        guard let a = appState else {
            fatalError("⚠️ [ScheduleCreationViewModel] appState è nil. Assicurarsi di chiamare injectDependencies() in onAppear prima di accedere all'appState.")
        }
        return a
    }

    // MARK: - Setup

    /// Gestisce l'apparizione della View: inizializza stazioni, calcoli e preset.
    /// Se ci sono orari ottimizzati confermati, li applica e genera l'orario.
    func handleOnAppear() {
        print("📍 [ScheduleCreationViewModel] handleOnAppear for line: \(line.name)")
        startStationId  = line.originStationId
        endStationId    = line.destinationStationId
        stationSequence = line.stationIds
        isInitializing = false

        updatePathCalculations()
        updatePreview()

        // Apply confirmed optimized times if available
        if state.optimizedTimesConfirmed, let previewData = state.optimizedTimesPreviewData {
            startTime = previewData.proposedOutboundTime
            if let interval = previewData.proposedInterval { intervalMinutes = interval }
            state.optimizedTimesPreviewData = nil
            state.optimizedTimesConfirmed = false
            aiTask = Task { await generateSchedule() }
            return
        }

        presetTrainType()
        updateSuggestedVehicles()
        syncStartNumbers()
        updatePreview()

        // AI analysis disabled for now
        // if state.useCloudAI { triggerLineAnalysis() }
        updatePathCalculations()
    }

    // MARK: - Path helpers

    /// Aggiorna la sequenza stazioni in base alla selezione di partenza/arrivo.
    /// Gestisce anche il caso in cui l'ordine sia invertito.
    func updateStationSequenceFromSelection() {
        stationSequence = pathResolver.resolveStationSequence(route: line, startId: startStationId, endId: endStationId)
        cachedAltitudeCharacteristics = nil
        presetTaktHub()
    }

    /// Ricalcola distanza stimata, tempo di viaggio e caratteristiche infrastruttura per il percorso attuale.
    func updatePathCalculations() {
        estimatedDistance = pathResolver.calculatePathDistance(stationSequence: stationSequence)
        estimatedTravelTime = kinematicCalculator.calculateAccurateTravelTime(stationSequence: stationSequence, train: makeDummyTrain())
        lineCharacteristics = calculateLineCharacteristics()
    }

    // MARK: - Preview count

    /// Aggiorna il conteggio anteprima delle corse (andata + eventuale ritorno).
    func updatePreview() {
        let calendar = Calendar.current
        let start = normalizeDate(startTime)
        let end   = normalizeDate(endTime)

        func count(s: Date, e: Date, interval: Int) -> Int {
            if mode == .single { return 1 }
            let sMin = calendar.component(.hour, from: s) * 60 + calendar.component(.minute, from: s)
            var eMin = calendar.component(.hour, from: e) * 60 + calendar.component(.minute, from: e)
            if eMin < sMin { eMin += 24 * 60 }
            if interval <= 0 { return 1 }
            return (eMin - sMin) / interval + 1
        }

        var total = count(s: start, e: end, interval: intervalMinutes)
        if scheduleReturn { total += count(s: start, e: end, interval: intervalMinutes) }
        previewCount = max(0, total)
    }

    // MARK: - Takt alignment

    /// Allinea l'orario di partenza al minuto Takt della prima stazione con nodo Takt.
    /// - Parameter isReturn: se `true`, calcola per la direzione di ritorno.
    func alignToTakt(isReturn: Bool) {
        if let newDate = taktEngine.calculateAlignedStartTime(
            startTime: startTime,
            stationSequence: stationSequence,
            taktStationId: taktStationId,
            train: makeDummyTrain(),
            isReturn: isReturn) {
            startTime = newDate
            updatePreview()
        }
    }



    func presetTaktHub() {
        taktStationId = pathResolver.presetTaktHub(stationSequence: stationSequence, currentHubId: taktStationId)
    }

    private func travelMinutesToStation(_ targetId: String, in sequence: [String]) -> Double {
        return kinematicCalculator.travelMinutesToStation(targetId, in: sequence, train: makeDummyTrain())
    }

    private func legTravelMinutes(from: String, to: String, train: Train) -> Double {
        return kinematicCalculator.legTravelMinutes(from: from, to: to, train: train)
    }

    private func dwellMinutes(at stationId: String) -> Double {
        return kinematicCalculator.dwellMinutes(at: stationId)
    }



    /// Calcola i suggerimenti Takt per ogni stazione con minuto Takt configurato.
    /// Restituisce le finestre di arrivo (-15/-5 min) e partenza (+5/+15 min).
    func calculateTaktSuggestions() -> [(stationId: String, stationName: String, taktMinute: Int,
                                          suggestedArrival: String, suggestedDeparture: String)] {
        return taktEngine.calculateTaktSuggestions(stationSequence: stationSequence)
    }

    // MARK: - Takt Diagnostic per treni non principali

    /// Verifica e diagnostica il posizionamento Takt per tutti i treni generati.
    /// Controlla che i treni secondari (non principali) rispettino le finestre temporali
    /// all'hub Takt senza interferire con i treni principali.
    ///
    /// La validazione verifica:
    /// - Che ogni treno passi per l'hub Takt
    /// - Che i treni secondari non si sovrappongano ai treni principali
    /// - Che la distanza dal minuto Takt sia ragionevole
    ///
    /// - Returns: Array di `TaktDiagnosticEntry` con il report per ogni treno.
    func validateNonMainTaktPlacement() -> [TaktDiagnosticEntry] {
        return taktEngine.validateTaktPlacement(trains: generatedTrains ?? [], taktStationId: taktStationId)
    }



    // MARK: - AI Analysis

    /// Avvia l'analisi AI della linea (se il cloud AI è attivo).
    func triggerRouteAnalysis() {
        guard let net = network else { return }
        Task {
            isAnalyzingRoute = true
            do {
                routeAnalysis = try await aiService.analyzeRoute(
                    name: line.name,
                    stationIds: stationSequence,
                    nodes: net.nodes,
                    edges: net.edges)
            } catch { print("⚠️ AI route analysis failed: \(error)") }
            isAnalyzingRoute = false
        }
    }

    // MARK: - Departure time optimisation

    /// Cerca la finestra di partenza ideale usando l'ottimizzatore di cadenza.
    /// Minimizza i conflitti con i treni esistenti nella rete.
    func findIdealBaseTime(isReturn: Bool) {
        optimizationStartTime = Date()
        Task {
            let seq = isReturn ? stationSequence.reversed() : Array(stationSequence)
            let tempLine = TrainRoute(id: line.id, name: line.name,
                                      originStationId: seq.first ?? "",
                                      destinationStationId: seq.last ?? "",
                                      stationIds: seq)
            let offset = await cadenceOptimizer.proposeIdealWindow(
                for: tempLine,
                frequency: Double(intervalMinutes),
                existingTrains: mgr.trains,
                network: net)
            let base = normalizeDate(startTime)
            let baseStart = Calendar.current.startOfDay(for: base)
            startTime = baseStart.addingTimeInterval(offset * 60)
            localProposedOffset = offset
            updatePreview()
        }
    }

    @MainActor
    /// Propone orari ottimizzati avviando la pipeline completa di generazione.
    func proposeOptimizedTimes() async {
        aiStatus = "Analisi rete in corso..."
        optimizerProgress = 0.0
        await generateSchedule()
    }

    // MARK: - Schedule generation

    func generateSchedule(forceLocal: Bool = false) async {
        print("\n🚀 [GEN] ===== INIZIO GENERAZIONE ORARIO =====")
        guard stationSequence.count >= 2 else {
            print("❌ [GEN] Sequenza stazioni insufficiente"); aiStatus = nil; return
        }

        let trains = await generationEngine.generate(
            line: line, mode: mode, startTime: startTime, endTime: endTime,
            intervalMinutes: intervalMinutes, stationSequence: stationSequence,
            selectedTrainType: selectedTrainType, selectedVehicle: selectedVehicle,
            selectedModel: selectedModel, skippedStopIds: skippedStopIds,
            isMainLine: isMainLine, scheduleReturn: scheduleReturn,
            startNumber: startNumber, returnStartNumber: returnStartNumber,
            preferredParity: preferredParity, useDepartureOptimizer: useDepartureOptimizer,
            taktStationId: taktStationId,
            progressCallback: { [weak self] status in self?.aiStatus = status }
        )

        guard !trains.isEmpty else { aiStatus = nil; return }

        publishResults(trains)

        // Validazione automatica Takt per treni non principali
        if mode == .taktfahrplan {
            let _ = validateNonMainTaktPlacement()
        }
    }


    /// Pubblica i treni finali nello stato di anteprima dell'AppState.
    /// Raggruppa gli aggiornamenti per minimizzare i cicli di rendering SwiftUI.
    private func publishResults(_ trains: [Train]) {
        generatedTrains = trains
        // Batch update su AppState: setta tutte le proprietà in un colpo solo
        // per evitare cicli di rendering multipli
        let s = state
        s.schedulePreviewTrains             = trains
        s.schedulePreviewRoute              = line
        s.schedulePreviewMode               = mode
        s.schedulePreviewSelectedModel       = selectedModel
        s.schedulePreviewOptimizeVehicles     = optimizeVehicleRotation
        s.schedulePreviewMinTurnaroundTime    = minimumTurnaroundTime
        aiStatus = nil
    }

    /// Inizializza i numeri treno in base alla parità selezionata.
    private func initializeNumbers(for trains: [Train]) -> [Train] {
        var result = trains
        var currentNumber = alignedStartNumber()
        for i in 0..<result.count {
            result[i].number = currentNumber
            currentNumber += 2 // Incrementa di 2 per mantenere la parità
        }
        return result
    }

    /// Restituisce il numero iniziale del treno, allineato alla parità selezionata.
    private func alignedStartNumber() -> Int {
        var num = startNumber
        if preferredParity == .even && num % 2 != 0 { num += 1 }
        if preferredParity == .odd  && num % 2 == 0 { num += 1 }
        return num
    }

    /// Cerca la relazione di ritorno (origine/destinazione invertite), o usa la relazione corrente.
    private func findReturnLine() -> TrainRoute {
        mgr.routes.first(where: {
            $0.originStationId == line.destinationStationId && $0.destinationStationId == line.originStationId
        }) ?? line
    }

    /// Nasconde la tastiera su iOS inviando resignFirstResponder.
    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil)
        #endif
    }

    // MARK: - Accept / Reject

    /// Accetta l'orario generato e aggiunge i treni al manager.
    /// I treni vengono creati senza mezzo fisico assegnato (vehicleId = nil):
    /// l'assegnazione dei turni macchina è delegata al menu dedicato.
    func acceptSchedule() {
        guard let trains = generatedTrains else { return }

        mgr.trains.append(contentsOf: trains)
        mgr.validateSchedules()

        state.schedulePreviewTrains = nil
        state.schedulePreviewRoute  = nil
        state.selectedRouteId       = line.id
        state.sidebarSelection      = .routes
        generatedTrains = nil
        state.creationRouteId = nil
    }

    /// Rifiuta l'orario generato e pulisce lo stato di anteprima.
    func rejectSchedule() {
        state.schedulePreviewTrains = nil
        state.schedulePreviewRoute  = nil
        generatedTrains = nil
    }

    // MARK: - Vehicle helpers

    /// Filtra e ordina i veicoli disponibili per idoneità alla linea corrente.
    /// Tiene conto di velocità, elettrificazione e tipo di treno selezionato.
    func updateSuggestedVehicles() {
        let all = mgr.vehicles
        guard !all.isEmpty else { return }
        let isElectrified = checkLineElectrification()
        var filtered = all.filter { v in
            let match: Bool = {
                switch selectedTrainType {
                case .highSpeed: return v.maxSpeed >= 200
                case .direct:    return v.maxSpeed >= 160 && v.maxSpeed < 250
                case .regional:  return v.maxSpeed >= 100 && v.maxSpeed < 200
                case .freight:   return v.maxSpeed < 120
                case .support:   return true
                }
            }()
            if !isElectrified && v.isElectric { return false }
            return match
        }
        let lineMaxSpeed: Double = { switch selectedTrainType {
            case .highSpeed: return 300; case .direct: return 200
            case .regional:  return 160; case .freight: return 100; case .support: return 120
        }}()
        // Pre-calcola gli score una volta sola per evitare ricalcoli O(n log n) nel sort
        let scores: [UUID: Double] = Dictionary(uniqueKeysWithValues: filtered.map {
            ($0.id, vehicleSuitabilityScore($0, lineMaxSpeed: lineMaxSpeed))
        })
        filtered.sort { (scores[$0.id] ?? 0) > (scores[$1.id] ?? 0) }
        suggestedVehicles = Array(filtered.prefix(3))
        if selectedVehicle == nil { selectedVehicle = suggestedVehicles.first }
    }

    func vehicleSuitabilityScore(_ vehicle: Vehicle, lineMaxSpeed: Double) -> Double {
        return suitabilityEngine.calculateSuitabilityScore(
            vehicle: vehicle,
            lineMaxSpeed: lineMaxSpeed,
            stationSequence: stationSequence,
            estimatedDistance: estimatedDistance,
            isLineElectrified: checkLineElectrification())
    }

    /// Verifica se l'intero percorso della linea è elettrificato controllando gli edge della rete.
    func checkLineElectrification() -> Bool {
        guard stationSequence.count >= 2 else { return true }
        return InfrastructureService(network: net).checkPathElectrification(stationIds: stationSequence)
    }



    // MARK: - Train type preset

    /// Imposta automaticamente il tipo di treno: usa il più comune sulla linea,
    /// oppure determina in base alla presenza di tratte ad alta velocità.
    func presetTrainType() {
        if let existing = mostCommonTrainType() {
            selectedTrainType = existing
            return
        }
        selectedTrainType = pathResolver.hasHighSpeedTrack(stationSequence: stationSequence) ? .highSpeed : .regional
    }

    /// Trova la categoria di treno più frequente su questa linea, se esistono treni.
    private func mostCommonTrainType() -> TrainCategory? {
        let lineTrains = mgr.trains.filter { $0.routeId == line.id }
        guard !lineTrains.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        for train in lineTrains {
            counts[train.type, default: 0] += 1
        }
        guard let topType = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return TrainCategory(rawValue: topType)
    }



    // MARK: - Utility

    /// Normalizza una data rimuovendo i secondi e componenti inferiori.
    func normalizeDate(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps) ?? date
    }

    /// Formatta una data nel formato "HH:mm".
    func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    /// Restituisce il nome leggibile di una stazione dato il suo ID.
    func stationName(_ id: String) -> String {
        if id.isEmpty { return "Seleziona..." }
        return net.nodes.first(where: { $0.id == id })?.name ?? "Sconosciuta"
    }

    /// Genera il titolo della direzione (es. "Milano ➔ Roma (andata)").
    func directionTitle(isReturn: Bool) -> String {
        guard stationSequence.count >= 2 else {
            return isReturn ? "B ➔ A (\("return".localized))" : "A ➔ B (\("outward".localized))"
        }
        let start = stationName(stationSequence.first ?? "")
        let end   = stationName(stationSequence.last ?? "")
        return isReturn ? "\(end) ➔ \(start) (\("return".localized))"
                        : "\(start) ➔ \(end) (\("outward".localized))"
    }

    /// Calcola le caratteristiche della linea per la selezione del modello di treno.
    /// Include pendenza massima reale (da altitudini nodi) e stato di elettrificazione.
    func calculateLineCharacteristics() -> LineCharacteristics {
        let altInfo = kinematicCalculator.calculateAltitudeCharacteristics(stationSequence: stationSequence)
        let isElectrified = checkLineElectrification()
        return LineCharacteristics(
            totalDistance:       estimatedDistance,
            averageStopDistance: estimatedDistance / Double(max(stationSequence.count - 1, 1)),
            numberOfStops:       stationSequence.count,
            maxLineSpeed:        Double(selectedTrainType.defaultMaxSpeed),
            serviceType:         selectedTrainType,
            frequency:           mode == .single ? nil : intervalMinutes,
            maxGradient:         altInfo.maxGradient,
            isElectrified:       isElectrified
        )
    }

    // MARK: - Private helpers

    /// Applica lo schema Intercity: salta le stazioni non contrassegnate come nodi principali.
    func applyIntercityPattern() {
        skippedStopIds.removeAll()
        guard stationSequence.count > 2 else { return }
        for i in 1..<(stationSequence.count - 1) {
            let sid = stationSequence[i]
            if let station = net.nodes.first(where: { $0.id == sid }),
               station.visualType != .filledSquare && station.visualType != .emptySquare {
                skippedStopIds.insert(sid)
            }
        }
    }

    /// Applica lo schema Diretto: salta tutte le fermate intermedie.
    func applyExpressPattern() {
        skippedStopIds.removeAll()
        guard stationSequence.count > 2 else { return }
        for i in 1..<(stationSequence.count - 1) {
            skippedStopIds.insert(stationSequence[i])
        }
    }


    /// Crea un treno fittizio per i calcoli di tempo di percorrenza.
    private func makeDummyTrain() -> Train {
        Train(id: UUID(), number: 0, name: "Probe",
              type: selectedTrainType.rawValue, lineId: nil, departureTime: Date(),
              stops: [], vehicleId: nil,
              maxSpeed: Double(selectedTrainType.defaultMaxSpeed),
              acceleration: 0.5, deceleration: 0.5, mass: 200, power: 2500,
              priority: selectedTrainType.defaultPriority,
              isElectric: true, isMainTrain: false)
    }

    /// Risolve i parametri fisici del treno: priorità modello > veicolo > default per categoria.
    private func resolvePhysics() -> (acceleration: Double, deceleration: Double, mass: Double, power: Double, maxSpeed: Double) {
        if let model = selectedModel {
            let v = model.toVehicle()
            return (v.acceleration, v.deceleration, v.mass, v.power, v.maxSpeed)
        }
        if let vehicle = selectedVehicle {
            return (vehicle.acceleration, vehicle.deceleration, vehicle.mass, vehicle.power, vehicle.maxSpeed)
        }
        let dp = appState?.getPhysics(for: selectedTrainType) ?? (acceleration: 0.5, deceleration: 0.4)
        return (dp.acceleration, dp.deceleration, 200, 2500, Double(selectedTrainType.defaultMaxSpeed))
    }

    /// Risolve il veicolo effettivo: priorità modello selezionato > veicolo selezionato.
    private func resolveVehicle() -> Vehicle? {
        selectedModel.map { $0.toVehicle() } ?? selectedVehicle
    }

    /// Sincronizza i numeri di partenza/ritorno quando cambia la parità preferita.
    private func syncParityNumbers() {
        startNumber       = (preferredParity == .odd) ? 1 : 2
        returnStartNumber = (preferredParity == .odd) ? 2 : 1
    }

    /// Sincronizza i numeri iniziali in base ai treni già esistenti sulla linea.
    /// Trova il numero più alto usato e assegna il successivo rispettando la parità.
    private func syncStartNumbers() {
        let lineTrains = mgr.trains.filter { $0.routeId == line.id }
        let prefix = line.numberPrefix ?? 0
        let used = lineTrains.compactMap { t -> Int? in
            guard let num = t.number else { return nil }
            let base = num - (prefix * 1000); return (base >= 0 && base < 1000) ? base : nil
        }
        let maxUsed = used.max() ?? -1
        startNumber = (maxUsed + 1 < 1000) ? maxUsed + 1 : 0
        if preferredParity == .even && startNumber % 2 != 0 { startNumber += 1 }
        if preferredParity == .odd  && startNumber % 2 == 0 { startNumber += 1 }
        returnStartNumber = startNumber + 1 < 1000 ? startNumber + 1 : 1
    }

}
