import Foundation

/// Motore orchestratore per la generazione dell'orario, inclusa la preparazione dei treni e l'ottimizzazione.
final class ScheduleGenerationEngine {
    private let network: RailwayNetwork
    private let trainManager: TrainManager
    private let vehicleRotationOptimizer = VehicleRotationOptimizer()
    
    init(network: RailwayNetwork, trainManager: TrainManager) {
        self.network = network
        self.trainManager = trainManager
    }
    
    /// Esegue la pipeline completa di generazione orario.
    func generate(
        line: RailwayLine,
        mode: ScheduleMode,
        startTime: Date,
        endTime: Date,
        intervalMinutes: Int,
        stationSequence: [String],
        selectedTrainType: TrainCategory,
        selectedVehicle: Vehicle?,
        selectedModel: TrainModel?,
        skippedStopIds: Set<String>,
        isMainLine: Bool,
        scheduleReturn: Bool,
        startNumber: Int,
        returnStartNumber: Int,
        preferredParity: NumberParity,
        useDepartureOptimizer: Bool,
        taktStationId: String,
        optimizeVehicleRotation: Bool,
        minimumTurnaroundTime: Double,
        progressCallback: @escaping (String) -> Void
    ) async -> [Train] {
        progressCallback("Preparazione treni...")
        let trains = prepareTrains(
            line: line, mode: mode, startTime: startTime, endTime: endTime,
            intervalMinutes: intervalMinutes, stationSequence: stationSequence,
            selectedTrainType: selectedTrainType, selectedVehicle: selectedVehicle,
            selectedModel: selectedModel, skippedStopIds: skippedStopIds,
            isMainLine: isMainLine, scheduleReturn: scheduleReturn,
            startNumber: startNumber, returnStartNumber: returnStartNumber,
            preferredParity: preferredParity
        )
        
        guard !trains.isEmpty else { return [] }
        
        progressCallback("Ottimizzazione pipeline...")
        let optimized = await runOptimizationPipeline(
            trains: trains, lineId: line.id, mode: mode,
            useDepartureOptimizer: useDepartureOptimizer, taktStationId: taktStationId
        )
        
        guard !optimized.isEmpty else { return [] }
        
        if optimizeVehicleRotation {
            progressCallback("Ottimizzazione turni mezzi...")
            return await applyVehicleRotation(
                to: optimized,
                minimumTurnaroundTime: minimumTurnaroundTime
            )
        }
        
        return optimized
    }
    
    private func prepareTrains(
        line: RailwayLine, mode: ScheduleMode, startTime: Date, endTime: Date,
        intervalMinutes: Int, stationSequence: [String],
        selectedTrainType: TrainCategory, selectedVehicle: Vehicle?,
        selectedModel: TrainModel?, skippedStopIds: Set<String>,
        isMainLine: Bool, scheduleReturn: Bool,
        startNumber: Int, returnStartNumber: Int,
        preferredParity: NumberParity
    ) -> [Train] {
        let calendar = Calendar.current
        let currentStart = alignedStartNumber(startNumber: startNumber, preferredParity: preferredParity)
        let normalizedStart = normalizeDate(startTime)
        let normalizedEnd = normalizeDate(endTime)
        let physics = resolvePhysics(selectedModel: selectedModel, selectedVehicle: selectedVehicle, selectedTrainType: selectedTrainType)
        let effectiveVehicle = selectedModel?.toVehicle() ?? selectedVehicle
        let rLineObj = findReturnLine(line: line)
        
        let isTakt120 = mode == .taktfahrplan && intervalMinutes == 120 && scheduleReturn
        let raw: [Train]
        
        if isTakt120 {
            raw = generateTakt120Pairs(
                calendar: calendar, normalizedStart: normalizedStart, endTime: endTime,
                intervalMinutes: intervalMinutes, currentStart: currentStart,
                returnStartNumber: returnStartNumber, line: line, rLineObj: rLineObj,
                stationSequence: stationSequence, physics: physics,
                effectiveVehicle: effectiveVehicle, skippedStopIds: skippedStopIds,
                isMainLine: isMainLine
            )
        } else {
            raw = generateStandard(
                calendar: calendar, normalizedStart: normalizedStart, normalizedEnd: normalizedEnd,
                mode: mode, intervalMinutes: intervalMinutes, currentStart: currentStart,
                returnStartNumber: returnStartNumber, line: line, rLineObj: rLineObj,
                stationSequence: stationSequence, physics: physics,
                effectiveVehicle: effectiveVehicle, skippedStopIds: skippedStopIds,
                isMainLine: isMainLine, scheduleReturn: scheduleReturn
            )
        }
        return raw.filter { !$0.stops.isEmpty }
    }
    
    private func runOptimizationPipeline(
        trains: [Train], lineId: UUID, mode: ScheduleMode,
        useDepartureOptimizer: Bool, taktStationId: String
    ) async -> [Train] {
        let useGA = mode == .taktfahrplan ? false : useDepartureOptimizer
        let taktNode = (mode == .taktfahrplan && !taktStationId.isEmpty) ? taktStationId : nil
        
        return await RailwayScheduleOptimizer.shared.executePipeline(
            newTrains: trains,
            existingTrains: trainManager.trains.filter { $0.lineId != lineId },
            nodes: network.nodes, edges: network.edges,
            useAI: false, useGA: useGA,
            geneticOptimizer: (nil as GeneticOptimizer?),
            preferredTaktNodeId: taktNode)
    }
    
    private func applyVehicleRotation(to trains: [Train], minimumTurnaroundTime: Double) async -> [Train] {
        var result = trains
        let assignment = vehicleRotationOptimizer.optimizeVehicleAssignment(
            trains: result, vehicles: trainManager.vehicles,
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
    
    // MARK: - Helpers
    
    private func alignedStartNumber(startNumber: Int, preferredParity: NumberParity) -> Int {
        var num = startNumber
        if preferredParity == .even && num % 2 != 0 { num += 1 }
        if preferredParity == .odd  && num % 2 == 0 { num += 1 }
        return num
    }
    
    private func findReturnLine(line: RailwayLine) -> RailwayLine {
        trainManager.lines.first(where: {
            $0.originId == line.destinationId && $0.destinationId == line.originId
        }) ?? line
    }
    
    private func normalizeDate(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: comps) ?? date
    }
    
    private func resolvePhysics(selectedModel: TrainModel?, selectedVehicle: Vehicle?, selectedTrainType: TrainCategory) -> (Double, Double, Double, Double, Double) {
        if let model = selectedModel {
            let v = model.toVehicle()
            return (v.acceleration, v.deceleration, v.mass, v.power, v.maxSpeed)
        }
        if let vehicle = selectedVehicle {
            return (vehicle.acceleration, vehicle.deceleration, vehicle.mass, vehicle.power, vehicle.maxSpeed)
        }
        // Fallback or default values (can be passsed in as well)
        return (0.5, 0.4, 200, 2500, Double(selectedTrainType.defaultMaxSpeed))
    }
    
    private func generateTakt120Pairs(
        calendar: Calendar, normalizedStart: Date, endTime: Date, intervalMinutes: Int,
        currentStart: Int, returnStartNumber: Int, line: RailwayLine, rLineObj: RailwayLine,
        stationSequence: [String], physics: (Double, Double, Double, Double, Double),
        effectiveVehicle: Vehicle?, skippedStopIds: Set<String>, isMainLine: Bool
    ) -> [Train] {
        let sMin = calendar.component(.hour, from: normalizedStart) * 60 + calendar.component(.minute, from: normalizedStart)
        var eMin = calendar.component(.hour, from: normalizeDate(endTime)) * 60 + calendar.component(.minute, from: normalizeDate(endTime))
        if eMin < sMin { eMin += 24 * 60 }
        let iterations = (eMin - sMin) / intervalMinutes + 1
        var result: [Train] = []
        for i in 0..<iterations {
            let dep = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedStart) ?? normalizedStart
            let t1 = trainManager.instantiateTrain(number: (line.numberPrefix ?? 0) * 100 + currentStart + (i * 2),
                category: selectedTrainType, departureTime: dep, line: line,
                stationSequence: stationSequence, acceleration: physics.0, deceleration: physics.1,
                mass: physics.2, power: physics.3, preferredTrack: "1",
                vehicleId: effectiveVehicle?.id, skippedStopIds: skippedStopIds, isMainTrain: isMainLine)
            let t2 = trainManager.instantiateTrain(
                number: (rLineObj.numberPrefix ?? line.numberPrefix ?? 0) * 100 + returnStartNumber + (i * 2),
                category: selectedTrainType, departureTime: dep, line: rLineObj,
                stationSequence: Array(stationSequence.reversed()), acceleration: physics.0, deceleration: physics.1,
                mass: physics.2, power: physics.3, preferredTrack: "2",
                vehicleId: effectiveVehicle?.id, skippedStopIds: skippedStopIds, isMainTrain: isMainLine)
            result.append(contentsOf: [t1, t2])
        }
        return result
    }
    
    private func generateStandard(
        calendar: Calendar, normalizedStart: Date, normalizedEnd: Date, mode: ScheduleMode, intervalMinutes: Int,
        currentStart: Int, returnStartNumber: Int, line: RailwayLine, rLineObj: RailwayLine,
        stationSequence: [String], physics: (Double, Double, Double, Double, Double),
        effectiveVehicle: Vehicle?, skippedStopIds: Set<String>, isMainLine: Bool, scheduleReturn: Bool
    ) -> [Train] {
        var result: [Train] = []
        let sMin = calendar.component(.hour, from: normalizedStart) * 60 + calendar.component(.minute, from: normalizedStart)
        var eMin = calendar.component(.hour, from: normalizedEnd) * 60 + calendar.component(.minute, from: normalizedEnd)
        if eMin < sMin { eMin += 24 * 60 }
        let outIter = mode == .single ? 1 : (eMin - sMin) / intervalMinutes + 1
        for i in 0..<outIter {
            let dep = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: normalizedStart) ?? normalizedStart
            let t = trainManager.instantiateTrain(number: (line.numberPrefix ?? 0) * 100 + currentStart + (i * 2),
                category: selectedTrainType, departureTime: dep, line: line,
                stationSequence: stationSequence, acceleration: physics.0, deceleration: physics.1,
                mass: physics.2, power: physics.3, preferredTrack: "1",
                vehicleId: effectiveVehicle?.id, skippedStopIds: skippedStopIds, isMainTrain: isMainLine)
            result.append(t)
        }
        if scheduleReturn {
            let retIter = mode == .single ? 1 : outIter
            let returnOffset: Int = (mode == .taktfahrplan && !isMainLine) ? intervalMinutes / 2 : 0
            
            for i in 0..<retIter {
                let dep = calendar.date(byAdding: .minute, value: i * intervalMinutes + returnOffset, to: normalizedStart) ?? normalizedStart
                let t = trainManager.instantiateTrain(
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
