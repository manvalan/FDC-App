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

// MARK: - ViewModel

/// ViewModel principale per la creazione degli orari ferroviari.
/// Gestisce tutta la logica di business: generazione treni, ottimizzazione,
/// allineamento Takt, calcolo percorsi e suggerimento veicoli.
@MainActor
final class ScheduleCreationViewModel: ObservableObject {

    // MARK: Dependencies (weak to avoid retain cycles with EnvironmentObjects)
    private weak var network: RailwayNetwork?
    private weak var manager: TrainManager?
    private weak var appState: AppState?
    let line: RailwayLine

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
    @Published var lineAnalysis: RailwayAIService.LineAnalysis? = nil
    @Published var isAnalyzingLine: Bool = false

    // MARK: - Preview / results
    @Published var previewCount: Int = 0
    @Published var estimatedTravelTime: Int = 0
    @Published var estimatedDistance: Double = 0
    @Published var generatedTrains: [Train]? = nil

    // MARK: - Model / vehicle
    @Published var selectedModel: TrainModel? = nil

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
    let cadenceOptimizer = CadenceOptimizer()
    private let vehicleRotationOptimizer = VehicleRotationOptimizer()
    let departureOptimizer = DepartureTimeOptimizer()

    // MARK: - Init

    /// Inizializzatore completo con tutte le dipendenze reali.
    init(line: RailwayLine,
         initialMode: ScheduleMode = .single,
         network: RailwayNetwork,
         manager: TrainManager,
         appState: AppState) {
        self.line = line
        self.mode = initialMode
        self.network = network
        self.manager = manager
        self.appState = appState
        self.startStationId = line.originId
        self.endStationId = line.destinationId
    }

    /// Inizializzatore di comodo usato dalla View prima che gli EnvironmentObject siano disponibili.
    /// Chiamare `injectDependencies` in `onAppear` per fornire gli oggetti reali.
    convenience init(line: RailwayLine, initialMode: ScheduleMode = .single) {
        let placeholderNetwork = NetworkModel()
        self.init(line: line, initialMode: initialMode,
                  network: RailwayNetwork(),
                  manager: TrainManager(network: placeholderNetwork),
                  appState: AppState.shared)
    }

    // MARK: - Iniezione dipendenze reali (chiamato da onAppear)

    /// Inietta le dipendenze reali (EnvironmentObject) dopo che la View è apparsa.
    func injectDependencies(network: RailwayNetwork, manager: TrainManager, appState: AppState) {
        self.network  = network
        self.manager  = manager
        self.appState = appState
    }

    // MARK: - Dependency accessors (crash-safe force-unwrap with guard)

    private var net: RailwayNetwork { network! }
    private var mgr: TrainManager  { manager! }
    private var state: AppState    { appState! }

    // MARK: - Setup

    /// Gestisce l'apparizione della View: inizializza stazioni, calcoli e preset.
    /// Se ci sono orari ottimizzati confermati, li applica e genera l'orario.
    func handleOnAppear() {
        print("📍 [ScheduleCreationViewModel] handleOnAppear for line: \(line.name)")
        startStationId = line.originId
        endStationId   = line.destinationId
        stationSequence = line.stations
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

        if state.useCloudAI { triggerLineAnalysis() }
        updatePathCalculations()
    }

    // MARK: - Path helpers

    /// Aggiorna la sequenza stazioni in base alla selezione di partenza/arrivo.
    /// Gestisce anche il caso in cui l'ordine sia invertito.
    func updateStationSequenceFromSelection() {
        guard !startStationId.isEmpty, !endStationId.isEmpty else { return }
        let lineStations = line.stations
        guard let sIdx = lineStations.firstIndex(of: startStationId),
              let eIdx = lineStations.firstIndex(of: endStationId) else { return }
        let range = sIdx <= eIdx
            ? Array(lineStations[sIdx...eIdx])
            : Array(lineStations[eIdx...sIdx].reversed())
        stationSequence = range
        print("✅ Updated stationSequence: \(stationSequence.count) stations")
    }

    /// Ricalcola distanza stimata e tempo di viaggio per il percorso attuale.
    func updatePathCalculations() {
        estimatedDistance    = net.calculatePathDistance(path: stationSequence)
        estimatedTravelTime  = calculateAccurateTravelTime()
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
        let sequence = isReturn ? Array(stationSequence.reversed()) : stationSequence
        guard sequence.count >= 2 else { return }

        let firstTakt = findFirstTaktStation(in: sequence)
        guard let firstTakt else { return }

        let totalMinutes = travelMinutesToStation(firstTakt.0, in: sequence)
        applyTaktAlignment(taktMinute: firstTakt.1, travelMinutes: totalMinutes)
    }

    /// Trova la prima stazione nella sequenza che ha un minuto Takt configurato.
    /// - Returns: tupla (id stazione, minuto Takt) oppure `nil` se nessuna stazione ha Takt.
    private func findFirstTaktStation(in sequence: [String]) -> (String, Int)? {
        for sid in sequence {
            if let node = net.nodes.first(where: { $0.id == sid }),
               let takt = node.taktMinutes {
                return (sid, takt)
            }
        }
        return nil
    }

    /// Calcola il tempo di viaggio in minuti dalla prima stazione fino alla stazione target.
    private func travelMinutesToStation(_ targetId: String, in sequence: [String]) -> Double {
        var totalMinutes: Double = 0
        var prevId = sequence[0]
        let dummyTrain = makeDummyTrain()

        for i in 1..<sequence.count {
            let sid = sequence[i]
            if sid == targetId { break }
            totalMinutes += legTravelMinutes(from: prevId, to: sid, train: dummyTrain)
            totalMinutes += dwellMinutes(at: prevId)
            prevId = sid
        }
        return totalMinutes
    }

    /// Calcola i minuti di percorrenza per una singola tratta tra due stazioni consecutive.
    private func legTravelMinutes(from: String, to: String, train: Train) -> Double {
        guard let path = net.findPathEdges(from: from, to: to) else { return 0 }
        var legDist: Double = 0
        var legSpeed: Double = .infinity
        for edge in path {
            legDist += edge.distance
            legSpeed = min(legSpeed, Double(edge.maxSpeed))
        }
        guard legDist > 0 else { return 0 }
        let effectiveSpeed = legSpeed == .infinity ? 100.0 : legSpeed
        let hours = FDCSchedulerEngine.calculateTravelTime(
            distanceKm: legDist, maxSpeedKmh: effectiveSpeed,
            train: train, initialSpeedKmh: 0, finalSpeedKmh: 0)
        return (hours * 60) + (35.0 / 60.0)
    }

    /// Restituisce i minuti di sosta in stazione (5 min per nodi di scambio, 3 min per gli altri).
    private func dwellMinutes(at stationId: String) -> Double {
        let node = net.nodes.first(where: { $0.id == stationId })
        let isInterchange = node?.type == .interchange
        return isInterchange ? 5.0 : 3.0
    }

    /// Applica l'allineamento Takt modificando l'orario di partenza.
    private func applyTaktAlignment(taktMinute: Int, travelMinutes: Double) {
        let targetMinute = (Double(taktMinute) - travelMinutes + 3600.0)
        let alignedMinute = Int(targetMinute.rounded()) % 60
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startTime)
        comps.minute = alignedMinute
        if let newDate = Calendar.current.date(from: comps) {
            startTime = newDate
            updatePreview()
        }
    }

    /// Calcola i suggerimenti Takt per ogni stazione con minuto Takt configurato.
    /// Restituisce le finestre di arrivo (-15/-5 min) e partenza (+5/+15 min).
    func calculateTaktSuggestions() -> [(stationId: String, stationName: String, taktMinute: Int,
                                          suggestedArrival: String, suggestedDeparture: String)] {
        var suggestions: [(String, String, Int, String, String)] = []
        for stationId in stationSequence {
            guard let station = net.nodes.first(where: { $0.id == stationId }),
                  let taktMinute = station.taktMinutes else { continue }
            let arrS = (taktMinute - 15 + 60) % 60; let arrE = (taktMinute - 5 + 60) % 60
            let depS = (taktMinute + 5) % 60;         let depE = (taktMinute + 15) % 60
            suggestions.append((stationId, station.name, taktMinute,
                                 String(format: ":%02d-:%02d", arrS, arrE),
                                 String(format: ":%02d-:%02d", depS, depE)))
        }
        return suggestions
    }

    // MARK: - AI Analysis

    /// Avvia l'analisi AI della linea (se il cloud AI è attivo).
    func triggerLineAnalysis() {
        Task {
            isAnalyzingLine = true
            do {
                let tempLine = RailwayLine(id: line.id, name: line.name,
                                           stops: stationSequence.map { RelationStop(stationId: $0) })
                lineAnalysis = try await RailwayAIService.shared.analyzeLine(
                    name: line.name,
                    stationIds: stationSequence,
                    nodes: net.nodes,
                    edges: net.edges)
            } catch { print("⚠️ AI line analysis failed: \(error)") }
            isAnalyzingLine = false
        }
    }

    // MARK: - Departure time optimisation

    /// Cerca la finestra di partenza ideale usando l'ottimizzatore di cadenza.
    /// Minimizza i conflitti con i treni esistenti nella rete.
    func findIdealBaseTime(isReturn: Bool) {
        optimizationStartTime = Date()
        Task {
            let seq = isReturn ? stationSequence.reversed() : Array(stationSequence)
            let tempLine = RailwayLine(id: line.id, name: line.name,
                                       stops: seq.map { RelationStop(stationId: $0) })
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

    @MainActor
    /// Genera l'intero orario: prepara i treni, esegue la pipeline di ottimizzazione
    /// e pubblica i risultati nell'anteprima.
    func generateSchedule(forceLocal: Bool = false) async {
        print("\n🚀 [GEN] ===== INIZIO GENERAZIONE ORARIO =====")
        guard stationSequence.count >= 2 else {
            print("❌ [GEN] Sequenza stazioni insufficiente"); aiStatus = nil; return
        }

        let trains = prepareTrains()
        guard !trains.isEmpty else {
            print("❌ [GEN] Nessun treno valido generato"); aiStatus = nil; return
        }

        let optimized = await runOptimizationPipeline(trains: trains)
        guard !optimized.isEmpty else { aiStatus = nil; return }

        let finalTrains = await applyVehicleRotation(to: optimized)
        publishResults(finalTrains)
    }

    /// Prepara tutti i treni grezzi in base alla modalità e alle impostazioni correnti.
    private func prepareTrains() -> [Train] {
        let calendar = Calendar.current
        let currentStart = alignedStartNumber()
        let normalizedStart = normalizeDate(startTime)
        let normalizedEnd   = normalizeDate(endTime)
        let physics         = resolvePhysics()
        let effectiveVehicle = resolveVehicle()
        let rLineObj = findReturnLine()

        let isTakt120 = mode == .taktfahrplan && intervalMinutes == 120 && scheduleReturn
        let raw: [Train]

        if isTakt120 {
            raw = generateTakt120Pairs(calendar: calendar, normalizedStart: normalizedStart,
                                       currentStart: currentStart, rLineObj: rLineObj,
                                       physics: physics, effectiveVehicle: effectiveVehicle)
        } else {
            raw = generateStandard(calendar: calendar, normalizedStart: normalizedStart,
                                   normalizedEnd: normalizedEnd, currentStart: currentStart,
                                   rLineObj: rLineObj, physics: physics, effectiveVehicle: effectiveVehicle)
        }
        return raw.filter { !$0.stops.isEmpty }
    }

    /// Esegue la pipeline di ottimizzazione sui treni grezzi (algoritmo genetico, ecc.).
    private func runOptimizationPipeline(trains: [Train]) async -> [Train] {
        aiStatus = "starting_pipeline".localized
        optimizationStartTime = Date()
        dismissKeyboard()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let useGA = mode == .taktfahrplan ? false : useDepartureOptimizer
        let taktNode = (mode == .taktfahrplan && !taktStationId.isEmpty) ? taktStationId : nil

        return await RailwayScheduleOptimizer.shared.executePipeline(
            newTrains: trains,
            existingTrains: mgr.trains.filter { $0.lineId != line.id },
            nodes: net.nodes, edges: net.edges,
            useAI: false, useGA: useGA,
            geneticOptimizer: nil,
            preferredTaktNodeId: taktNode)
    }

    /// Applica l'ottimizzazione dei turni veicoli, se abilitata.
    private func applyVehicleRotation(to trains: [Train]) async -> [Train] {
        guard optimizeVehicleRotation else { return trains }
        aiStatus = "Ottimizzazione turni mezzi..."
        var result = trains
        let assignment = vehicleRotationOptimizer.optimizeVehicleAssignment(
            trains: result, vehicles: mgr.vehicles,
            minimumTurnaroundTime: minimumTurnaroundTime)
        for (vehicleId, trainIds) in assignment {
            for trainId in trainIds {
                if let idx = result.firstIndex(where: { $0.id == trainId }) {
                    result[idx].vehicleId = vehicleId
                }
            }
        }
        return result
    }

    /// Pubblica i treni finali nello stato di anteprima dell'AppState.
    private func publishResults(_ trains: [Train]) {
        generatedTrains = trains
        state.schedulePreviewTrains             = trains
        state.schedulePreviewLine               = line
        state.schedulePreviewMode               = mode
        state.schedulePreviewSelectedModel       = selectedModel
        state.schedulePreviewOptimizeVehicles     = optimizeVehicleRotation
        state.schedulePreviewMinTurnaroundTime    = minimumTurnaroundTime
        aiStatus = nil
    }

    /// Restituisce il numero iniziale del treno, allineato alla parità selezionata.
    private func alignedStartNumber() -> Int {
        var num = startNumber
        if preferredParity == .even && num % 2 != 0 { num += 1 }
        if preferredParity == .odd  && num % 2 == 0 { num += 1 }
        return num
    }

    /// Cerca la linea di ritorno (origine/destinazione invertite), o usa la linea corrente.
    private func findReturnLine() -> RailwayLine {
        mgr.lines.first(where: {
            $0.originId == line.destinationId && $0.destinationId == line.originId
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

    /// Accetta l'orario generato: crea veicoli se necessario, assegna i turni
    /// e aggiunge i treni al manager. Chiude la vista di creazione.
    func acceptSchedule() {
        guard var trains = generatedTrains else { return }

        if let model = selectedModel, optimizeVehicleRotation {
            let needed = vehicleRotationOptimizer.suggestVehicleCount(
                for: trains, minimumTurnaroundTime: minimumTurnaroundTime)
            var created: [Vehicle] = []
            for i in 1...needed {
                let v = model.toVehicle(name: "\(model.nome) #\(i) - \(line.name)")
                created.append(v); mgr.vehicles.append(v)
            }
            let assignment = vehicleRotationOptimizer.optimizeVehicleAssignment(
                trains: trains, vehicles: created, minimumTurnaroundTime: minimumTurnaroundTime)
            for (vehicleId, trainIds) in assignment {
                for id in trainIds {
                    if let idx = trains.firstIndex(where: { $0.id == id }) { trains[idx].vehicleId = vehicleId }
                }
            }
        }

        mgr.trains.append(contentsOf: trains)
        mgr.validateSchedules()

        state.schedulePreviewTrains = nil
        state.schedulePreviewLine   = nil
        state.selectedLineId        = line.id
        state.sidebarSelection      = .lines
        generatedTrains = nil
        state.creationLineId = nil
    }

    /// Rifiuta l'orario generato e pulisce lo stato di anteprima.
    func rejectSchedule() {
        state.schedulePreviewTrains = nil
        state.schedulePreviewLine   = nil
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
        filtered.sort { vehicleSuitabilityScore($0, lineMaxSpeed: lineMaxSpeed) >
                        vehicleSuitabilityScore($1, lineMaxSpeed: lineMaxSpeed) }
        suggestedVehicles = Array(filtered.prefix(3))
        if selectedVehicle == nil { selectedVehicle = suggestedVehicles.first }
    }

    /// Calcola un punteggio di idoneità per un veicolo rispetto alla linea.
    /// Composto da: corrispondenza velocità, altimetria, spaziatura fermate, elettrificazione.
    func vehicleSuitabilityScore(_ vehicle: Vehicle, lineMaxSpeed: Double) -> Double {
        let speedScore   = scoreForSpeedMatch(vehicle: vehicle, lineMaxSpeed: lineMaxSpeed)
        let altitudeScore = scoreForAltitude(vehicle: vehicle)
        let stopScore    = scoreForStopSpacing(vehicle: vehicle, lineMaxSpeed: lineMaxSpeed)
        let elecScore    = scoreForElectrification(vehicle: vehicle)
        return speedScore + altitudeScore + stopScore + elecScore
    }

    /// Punteggio parziale: corrispondenza tra velocità max veicolo e velocità linea (peso 35%).
    private func scoreForSpeedMatch(vehicle: Vehicle, lineMaxSpeed: Double) -> Double {
        max(0, 100 - abs(vehicle.maxSpeed - lineMaxSpeed)) * 0.35
    }

    /// Punteggio parziale: capacità del veicolo di affrontare le pendenze della linea (peso 15%).
    private func scoreForAltitude(vehicle: Vehicle) -> Double {
        let altInfo = calculateAltitudeCharacteristics()
        guard let maxGrad = altInfo.maxGradient else { return 0 }
        let multiplier: Double
        if maxGrad > 25      { multiplier = 40 }
        else if maxGrad > 15 { multiplier = 30 }
        else if maxGrad > 10 { multiplier = 20 }
        else                 { return 50 * 0.15 }
        return min(vehicle.acceleration * multiplier, 100) * 0.15
    }

    /// Punteggio parziale: adeguatezza del veicolo alla spaziatura media delle fermate (peso 25%).
    private func scoreForStopSpacing(vehicle: Vehicle, lineMaxSpeed: Double) -> Double {
        let stopCount = max(stationSequence.count - 1, 1)
        let avgDist = estimatedDistance / Double(stopCount)
        if avgDist < 10 {
            return min(vehicle.acceleration * 30, 100) * 0.25
        } else if avgDist < 20 {
            let accelPart = min(vehicle.acceleration * 20, 100) * 0.15
            let speedPart = min((vehicle.maxSpeed / lineMaxSpeed) * 50, 50) * 0.1
            return accelPart + speedPart
        } else {
            return min((vehicle.maxSpeed / lineMaxSpeed) * 100, 100) * 0.25
        }
    }

    /// Punteggio parziale: compatibilità elettrificazione veicolo/linea (peso 10%).
    private func scoreForElectrification(vehicle: Vehicle) -> Double {
        let isElec = checkLineElectrification()
        let rawScore: Double
        if isElec == vehicle.isElectric { rawScore = 25 }
        else if isElec                  { rawScore = 10 }
        else                            { rawScore = -100 }
        return rawScore * 0.10
    }

    /// Verifica se la linea è elettrificata. Default conservativo: `true`.
    func checkLineElectrification() -> Bool { true }

    /// Calcola le caratteristiche altimetriche della linea: dislivello totale, pendenza massima e media.
    func calculateAltitudeCharacteristics() -> (totalElevationGain: Double?, maxGradient: Double?, avgGradient: Double?) {
        let nodes = stationSequence.compactMap { id in net.nodes.first(where: { $0.id == id }) }
        guard nodes.count >= 2 else { return (nil, nil, nil) }

        let service = InfrastructureService(network: net)
        var totalGain = 0.0
        var maxGrad = 0.0
        var totalDist = 0.0
        var totalDescent = 0.0

        for i in 0..<(nodes.count - 1) {
            let (gain, descent, grad, dist) = segmentElevation(
                from: nodes[i].id, to: nodes[i + 1].id, service: service)
            totalGain += gain
            totalDescent += descent
            maxGrad = max(maxGrad, grad)
            totalDist += dist
        }

        let totalChange = totalGain + totalDescent
        let avg = totalDist > 0 ? (totalChange / (totalDist * 1000)) * 1000 : 0
        return (totalGain, maxGrad, avg)
    }

    /// Calcola i dati altimetrici per un singolo segmento tra due stazioni.
    /// Restituisce: guadagno in salita, discesa, pendenza massima e distanza.
    private func segmentElevation(from: String, to: String,
                                   service: InfrastructureService) -> (gain: Double, descent: Double, maxGrad: Double, dist: Double) {
        guard let path = service.findPath(from: from, to: to) else { return (0, 0, 0, 0) }
        var gain = 0.0, descent = 0.0, maxGrad = 0.0, dist = 0.0

        for j in 0..<(path.nodes.count - 1) {
            guard let alt1 = path.nodes[j].altitude,
                  let alt2 = path.nodes[j + 1].altitude,
                  j < path.segments.count else { continue }
            let segDist = path.segments[j].distance
            let diff = alt2 - alt1
            if diff > 0 { gain += diff } else { descent += abs(diff) }
            if segDist > 0 {
                let gradient = abs(diff / (segDist * 1000)) * 1000
                maxGrad = max(maxGrad, gradient)
            }
            dist += segDist
        }
        return (gain, descent, maxGrad, dist)
    }

    // MARK: - Train type preset

    /// Imposta automaticamente il tipo di treno: usa il più comune sulla linea,
    /// oppure determina in base alla presenza di tratte ad alta velocità.
    func presetTrainType() {
        if let existing = mostCommonTrainType() {
            selectedTrainType = existing
            return
        }
        selectedTrainType = lineHasHighSpeedTrack() ? .highSpeed : .regional
    }

    /// Trova la categoria di treno più frequente su questa linea, se esistono treni.
    private func mostCommonTrainType() -> TrainCategory? {
        let lineTrains = mgr.trains.filter { $0.lineId == line.id }
        guard !lineTrains.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        for train in lineTrains {
            counts[train.type, default: 0] += 1
        }
        guard let topType = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return TrainCategory(rawValue: topType)
    }

    /// Verifica se la linea contiene segmenti di binario ad alta velocità.
    private func lineHasHighSpeedTrack() -> Bool {
        guard line.stations.count >= 2 else { return false }
        for i in 0..<(line.stations.count - 1) {
            let from = line.stations[i]
            let to = line.stations[i + 1]
            let hasHS = net.edges.contains { edge in
                let matchesDirection = (edge.from == from && edge.to == to)
                    || (edge.from == to && edge.to == from)
                return matchesDirection && edge.trackType == .highSpeed
            }
            if hasHS { return true }
        }
        return false
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
    func calculateLineCharacteristics() -> LineCharacteristics {
        LineCharacteristics(
            totalDistance:      estimatedDistance,
            averageStopDistance: estimatedDistance / Double(max(stationSequence.count - 1, 1)),
            numberOfStops:      stationSequence.count,
            maxLineSpeed:       Double(selectedTrainType.defaultMaxSpeed),
            serviceType:        selectedTrainType,
            frequency:          mode == .single ? nil : intervalMinutes
        )
    }

    // MARK: - Private helpers

    /// Calcola il tempo di viaggio accurato in minuti, considerando velocità massime,
    /// pendenze e tempi di sosta intermedi per ogni tratta.
    private func calculateAccurateTravelTime() -> Int {
        guard stationSequence.count >= 2 else { return 0 }
        let dummy = makeDummyTrain()
        var totalSeconds: TimeInterval = 0
        var prevId = stationSequence[0]
        for i in 1..<stationSequence.count {
            let curId = stationSequence[i]
            if let path = net.findPathEdges(from: prevId, to: curId) {
                var legDist: Double = 0; var legMinSpeed: Double = .infinity
                for edge in path { legDist += edge.distance; legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed)) }
                if legDist > 0 {
                    var gradient: Double = 0
                    if let fN = net.nodes.first(where: { $0.id == prevId }),
                       let tN = net.nodes.first(where: { $0.id == curId }),
                       let fA = fN.altitude, let tA = tN.altitude {
                        gradient = ((tA - fA) / (legDist * 1000)) * 100
                    }
                    let hours = FDCSchedulerEngine.calculateTravelTime(
                        distanceKm: legDist, maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed,
                        train: dummy, initialSpeedKmh: 0, finalSpeedKmh: 0, gradient: gradient)
                    totalSeconds += max(hours * 3600 + 35, 60)
                    if i < stationSequence.count - 1 {
                        let node = net.nodes.first(where: { $0.id == curId })
                        totalSeconds += Double((node?.type == .interchange) ? 5 : 3) * 60
                    }
                }
            }
            prevId = curId
        }
        return Int(ceil(totalSeconds / 60))
    }

    /// Crea un treno fittizio per i calcoli di tempo di percorrenza.
    private func makeDummyTrain() -> Train {
        Train(id: UUID(), number: 0, name: "Probe",
              type: selectedTrainType.rawValue, lineId: nil, departureTime: Date(),
              stops: [], vehicleId: nil,
              maxSpeed: Double(selectedTrainType.defaultMaxSpeed),
              acceleration: 0.5, deceleration: 0.5, mass: 200, power: 2500,
              priority: selectedTrainType.defaultPriority)
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
        let dp = state.getPhysics(for: selectedTrainType)
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
        let lineTrains = mgr.trains.filter { $0.lineId == line.id }
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

    // MARK: - Train generation helpers

    /// Genera coppie di treni Takt con intervallo 120 minuti (andata + ritorno simultanei).
    private func generateTakt120Pairs(calendar: Calendar, normalizedStart: Date, currentStart: Int,
                                       rLineObj: RailwayLine, physics: (Double,Double,Double,Double,Double),
                                       effectiveVehicle: Vehicle?) -> [Train] {
        let sMin = calendar.component(.hour, from: normalizedStart) * 60 + calendar.component(.minute, from: normalizedStart)
        var eMin = calendar.component(.hour, from: normalizeDate(endTime)) * 60 + calendar.component(.minute, from: normalizeDate(endTime))
        if eMin < sMin { eMin += 24 * 60 }
        let iterations = (eMin - sMin) / intervalMinutes + 1
        var result: [Train] = []
        for i in 0..<iterations {
            let dep = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedStart) ?? normalizedStart
            let t1 = mgr.instantiateTrain(number: (line.numberPrefix ?? 0) * 100 + currentStart + (i * 2),
                category: selectedTrainType, departureTime: dep, line: line,
                stationSequence: stationSequence, acceleration: physics.0, deceleration: physics.1,
                mass: physics.2, power: physics.3, preferredTrack: "1",
                vehicleId: effectiveVehicle?.id, skippedStopIds: skippedStopIds, isMainTrain: isMainLine)
            let t2 = mgr.instantiateTrain(
                number: (rLineObj.numberPrefix ?? line.numberPrefix ?? 0) * 100 + returnStartNumber + (i * 2),
                category: selectedTrainType, departureTime: dep, line: rLineObj,
                stationSequence: Array(stationSequence.reversed()), acceleration: physics.0, deceleration: physics.1,
                mass: physics.2, power: physics.3, preferredTrack: "2",
                vehicleId: effectiveVehicle?.id, skippedStopIds: skippedStopIds, isMainTrain: isMainLine)
            result.append(contentsOf: [t1, t2])
        }
        return result
    }

    /// Genera treni con modalità standard (singola o cadenzata).
    /// Crea prima le corse di andata, poi eventualmente quelle di ritorno.
    private func generateStandard(calendar: Calendar, normalizedStart: Date, normalizedEnd: Date,
                                   currentStart: Int, rLineObj: RailwayLine,
                                   physics: (Double,Double,Double,Double,Double),
                                   effectiveVehicle: Vehicle?) -> [Train] {
        var result: [Train] = []
        let sMin = calendar.component(.hour, from: normalizedStart) * 60 + calendar.component(.minute, from: normalizedStart)
        var eMin = calendar.component(.hour, from: normalizedEnd) * 60 + calendar.component(.minute, from: normalizedEnd)
        if eMin < sMin { eMin += 24 * 60 }
        let outIter = mode == .single ? 1 : (eMin - sMin) / intervalMinutes + 1
        for i in 0..<outIter {
            let dep = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedStart) ?? normalizedStart
            let t = mgr.instantiateTrain(number: (line.numberPrefix ?? 0) * 100 + currentStart + (i * 2),
                category: selectedTrainType, departureTime: dep, line: line,
                stationSequence: stationSequence, acceleration: physics.0, deceleration: physics.1,
                mass: physics.2, power: physics.3, preferredTrack: "1",
                vehicleId: effectiveVehicle?.id, skippedStopIds: skippedStopIds, isMainTrain: isMainLine)
            result.append(t)
        }
        if scheduleReturn {
            let retIter = mode == .single ? 1 : outIter
            for i in 0..<retIter {
                let dep = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedStart) ?? normalizedStart
                let t = mgr.instantiateTrain(
                    number: (rLineObj.numberPrefix ?? line.numberPrefix ?? 0) * 100 + returnStartNumber + (i * 2),
                    category: selectedTrainType, departureTime: dep, line: rLineObj,
                    stationSequence: Array(stationSequence.reversed()), acceleration: physics.0, deceleration: physics.1,
                    mass: physics.2, power: physics.3, preferredTrack: "2",
                    vehicleId: effectiveVehicle?.id, skippedStopIds: skippedStopIds, isMainTrain: isMainLine)
                result.append(t)
            }
        }
        return result
    }
}
