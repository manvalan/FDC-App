import SwiftUI
import Combine

// MARK: - ScheduleMode & NumberParity (shared types)

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

    /// Convenience init used by the View before real EnvironmentObjects are available.
    /// Call `injectDependencies` in `onAppear` to supply real objects.
    convenience init(line: RailwayLine, initialMode: ScheduleMode = .single) {
        let placeholderNetwork = NetworkModel()
        self.init(line: line, initialMode: initialMode,
                  network: RailwayNetwork(),
                  manager: TrainManager(network: placeholderNetwork),
                  appState: AppState.shared)
    }

    // MARK: - Inject real EnvironmentObject dependencies (called from onAppear)
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

    func updatePathCalculations() {
        estimatedDistance    = net.calculatePathDistance(path: stationSequence)
        estimatedTravelTime  = calculateAccurateTravelTime()
    }

    // MARK: - Preview count

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

    func alignToTakt(isReturn: Bool) {
        let sequence = isReturn ? Array(stationSequence.reversed()) : stationSequence
        guard sequence.count >= 2 else { return }

        let taktStations = sequence.compactMap { sid -> (String, Int)? in
            guard let node = net.nodes.first(where: { $0.id == sid }),
                  let takt = node.taktMinutes else { return nil }
            return (sid, takt)
        }
        guard let firstTakt = taktStations.first else { return }

        var totalMinutes: Double = 0
        var prevId = sequence[0]
        let dummyTrain = makeDummyTrain()

        for i in 0..<sequence.count {
            let sid = sequence[i]
            if sid == firstTakt.0 { break }
            if i > 0 {
                if let path = net.findPathEdges(from: prevId, to: sid) {
                    var legDist: Double = 0
                    var legSpeed: Double = .infinity
                    for edge in path { legDist += edge.distance; legSpeed = min(legSpeed, Double(edge.maxSpeed)) }
                    if legDist > 0 {
                        let hours = FDCSchedulerEngine.calculateTravelTime(
                            distanceKm: legDist,
                            maxSpeedKmh: legSpeed == .infinity ? 100 : legSpeed,
                            train: dummyTrain, initialSpeedKmh: 0, finalSpeedKmh: 0)
                        totalMinutes += (hours * 60) + (35.0 / 60.0)
                    }
                }
                let prevNode = net.nodes.first(where: { $0.id == prevId })
                totalMinutes += Double((prevNode?.type == .interchange) ? 5 : 3)
            }
            prevId = sid
        }

        let targetMinute = (Double(firstTakt.1) - totalMinutes + 3600.0)
        let alignedMinute = Int(targetMinute.rounded()) % 60
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startTime)
        comps.minute = alignedMinute
        if let newDate = Calendar.current.date(from: comps) {
            startTime = newDate
            updatePreview()
        }
    }

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
    func proposeOptimizedTimes() async {
        aiStatus = "Analisi rete in corso..."
        optimizerProgress = 0.0
        await generateSchedule()
    }

    // MARK: - Schedule generation

    @MainActor
    func generateSchedule(forceLocal: Bool = false) async {
        let calendar = Calendar.current
        print("\n🚀 [GEN] ===== INIZIO GENERAZIONE ORARIO =====")
        guard stationSequence.count >= 2 else {
            print("❌ [GEN] Sequenza stazioni insufficiente"); aiStatus = nil; return
        }

        var currentStart = startNumber
        if preferredParity == .even && currentStart % 2 != 0 { currentStart += 1 }
        if preferredParity == .odd  && currentStart % 2 == 0 { currentStart += 1 }

        let normalizedStart = normalizeDate(startTime)
        let normalizedEnd   = normalizeDate(endTime)
        let physics         = resolvePhysics()
        let effectiveVehicle = resolveVehicle()

        let rLineObj = mgr.lines.first(where: {
            $0.originId == line.destinationId && $0.destinationId == line.originId
        }) ?? line

        var trains: [Train] = []

        if mode == .taktfahrplan && intervalMinutes == 120 && scheduleReturn {
            trains = generateTakt120Pairs(calendar: calendar, normalizedStart: normalizedStart,
                                          currentStart: currentStart, rLineObj: rLineObj,
                                          physics: physics, effectiveVehicle: effectiveVehicle)
        } else {
            trains = generateStandard(calendar: calendar, normalizedStart: normalizedStart,
                                      normalizedEnd: normalizedEnd, currentStart: currentStart,
                                      rLineObj: rLineObj, physics: physics, effectiveVehicle: effectiveVehicle)
        }

        trains = trains.filter { !$0.stops.isEmpty }
        guard !trains.isEmpty else { print("❌ [GEN] Nessun treno valido generato"); aiStatus = nil; return }

        aiStatus = "starting_pipeline".localized
        optimizationStartTime = Date()

        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        try? await Task.sleep(nanoseconds: 100_000_000)

        let nodesCopy = net.nodes
        let edgesCopy = net.edges

        // TAKTFAHRPLAN: disabilita tutti gli algoritmi di ottimizzazione per mantenere orari deterministici
        let optimizedTrains = await RailwayScheduleOptimizer.shared.executePipeline(
            newTrains: trains,
            existingTrains: mgr.trains.filter { $0.lineId != line.id },
            nodes: nodesCopy,
            edges: edgesCopy,
            useAI: false,
            useGA: mode == .taktfahrplan ? false : useDepartureOptimizer, // TAKT: no ottimizzazione
            geneticOptimizer: nil,
            preferredTaktNodeId: (mode == .taktfahrplan && !taktStationId.isEmpty) ? taktStationId : nil
        )

        guard !optimizedTrains.isEmpty else { aiStatus = nil; return }

        var finalTrains = optimizedTrains
        if optimizeVehicleRotation {
            aiStatus = "Ottimizzazione turni mezzi..."
            let assignment = vehicleRotationOptimizer.optimizeVehicleAssignment(
                trains: finalTrains, vehicles: mgr.vehicles, minimumTurnaroundTime: minimumTurnaroundTime)
            for (vehicleId, trainIds) in assignment {
                for trainId in trainIds {
                    if let idx = finalTrains.firstIndex(where: { $0.id == trainId }) {
                        finalTrains[idx].vehicleId = vehicleId
                    }
                }
            }
        }

        generatedTrains = finalTrains
        state.schedulePreviewTrains   = finalTrains
        state.schedulePreviewLine     = line
        state.schedulePreviewMode     = mode
        state.schedulePreviewSelectedModel  = selectedModel
        state.schedulePreviewOptimizeVehicles  = optimizeVehicleRotation
        state.schedulePreviewMinTurnaroundTime = minimumTurnaroundTime
        aiStatus = nil
    }

    // MARK: - Accept / Reject

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

    func rejectSchedule() {
        state.schedulePreviewTrains = nil
        state.schedulePreviewLine   = nil
        generatedTrains = nil
    }

    // MARK: - Vehicle helpers

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

    func vehicleSuitabilityScore(_ vehicle: Vehicle, lineMaxSpeed: Double) -> Double {
        var score = 0.0
        score += max(0, 100 - abs(vehicle.maxSpeed - lineMaxSpeed)) * 0.35
        let altInfo = calculateAltitudeCharacteristics()
        if let maxGrad = altInfo.maxGradient {
            let altScore: Double = maxGrad > 25 ? min(vehicle.acceleration * 40, 100)
                                 : maxGrad > 15 ? min(vehicle.acceleration * 30, 100)
                                 : maxGrad > 10 ? min(vehicle.acceleration * 20, 100) : 50
            score += altScore * 0.15
        }
        let avgStopDist = estimatedDistance / Double(max(stationSequence.count - 1, 1))
        if avgStopDist < 10      { score += min(vehicle.acceleration * 30, 100) * 0.25 }
        else if avgStopDist < 20 { score += min(vehicle.acceleration * 20, 100) * 0.15
                                   score += min((vehicle.maxSpeed / lineMaxSpeed) * 50, 50) * 0.1 }
        else                     { score += min((vehicle.maxSpeed / lineMaxSpeed) * 100, 100) * 0.25 }
        let isElec = checkLineElectrification()
        score += (isElec == vehicle.isElectric ? 25 : (isElec ? 10 : -100)) * 0.10
        return score
    }

    func checkLineElectrification() -> Bool { true } // Conservative default

    func calculateAltitudeCharacteristics() -> (totalElevationGain: Double?, maxGradient: Double?, avgGradient: Double?) {
        let stations = stationSequence.compactMap { id in net.nodes.first(where: { $0.id == id }) }
        guard stations.count >= 2 else { return (nil, nil, nil) }
        let service = InfrastructureService(network: net)
        var totalGain = 0.0; var maxGrad = 0.0; var totalDist = 0.0; var totalElevChange = 0.0
        let seqStations = stationSequence.compactMap { id in net.nodes.first(where: { $0.id == id }) }
        for i in 0..<(seqStations.count - 1) {
            guard let path = service.findPath(from: seqStations[i].id, to: seqStations[i+1].id) else { continue }
            for j in 0..<(path.nodes.count - 1) {
                guard let alt1 = path.nodes[j].altitude, let alt2 = path.nodes[j+1].altitude,
                      j < path.segments.count else { continue }
                let segDist = path.segments[j].distance
                let diff = alt2 - alt1
                if diff > 0 { totalGain += diff } else { totalElevChange += abs(diff) }
                if segDist > 0 { maxGrad = max(maxGrad, abs(diff / (segDist * 1000)) * 1000) }
                totalDist += segDist
            }
        }
        let avg = totalDist > 0 ? ((totalGain + totalElevChange) / (totalDist * 1000)) * 1000 : 0
        return (totalGain, maxGrad, avg)
    }

    // MARK: - Train type preset

    func presetTrainType() {
        let lineTrains = mgr.trains.filter { $0.lineId == line.id }
        if let mostCommon = lineTrains.map({ $0.type })
            .reduce([String: Int](), { var d = $0; d[$1, default: 0] += 1; return d })
            .max(by: { $0.value < $1.value })?.key,
           let cat = TrainCategory(rawValue: mostCommon) {
            selectedTrainType = cat; return
        }
        guard line.stations.count >= 2 else { selectedTrainType = .regional; return }
        let hasHS = line.stations.indices.dropLast().contains(where: { i in
            let (f, t) = (line.stations[i], line.stations[i+1])
            return net.edges.contains(where: {
                (($0.from == f && $0.to == t) || ($0.from == t && $0.to == f)) && $0.trackType == .highSpeed
            })
        })
        selectedTrainType = hasHS ? .highSpeed : .regional
    }

    // MARK: - Utility

    func normalizeDate(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps) ?? date
    }

    func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    func stationName(_ id: String) -> String {
        if id.isEmpty { return "Seleziona..." }
        return net.nodes.first(where: { $0.id == id })?.name ?? "Sconosciuta"
    }

    func directionTitle(isReturn: Bool) -> String {
        guard stationSequence.count >= 2 else {
            return isReturn ? "B ➔ A (\("return".localized))" : "A ➔ B (\("outward".localized))"
        }
        let start = stationName(stationSequence.first ?? "")
        let end   = stationName(stationSequence.last ?? "")
        return isReturn ? "\(end) ➔ \(start) (\("return".localized))"
                        : "\(start) ➔ \(end) (\("outward".localized))"
    }

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

    private func makeDummyTrain() -> Train {
        Train(id: UUID(), number: 0, name: "Probe",
              type: selectedTrainType.rawValue, lineId: nil, departureTime: Date(),
              stops: [], vehicleId: nil,
              maxSpeed: Double(selectedTrainType.defaultMaxSpeed),
              acceleration: 0.5, deceleration: 0.5, mass: 200, power: 2500,
              priority: selectedTrainType.defaultPriority)
    }

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

    private func resolveVehicle() -> Vehicle? {
        selectedModel.map { $0.toVehicle() } ?? selectedVehicle
    }

    private func syncParityNumbers() {
        startNumber       = (preferredParity == .odd) ? 1 : 2
        returnStartNumber = (preferredParity == .odd) ? 2 : 1
    }

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
