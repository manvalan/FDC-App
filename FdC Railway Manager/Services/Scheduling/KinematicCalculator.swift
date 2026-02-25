import Foundation

/// Servizio dedicato ai calcoli cinematici e dei tempi di percorrenza.
/// Segue i principi di "Code That Fits in Your Head" isolando la logica computazionale.
final class KinematicCalculator {
    private let network: RailwayNetwork
    
    init(network: RailwayNetwork) {
        self.network = network
    }
    
    // MARK: - Travel Time Calculations
    
    /// Calcola il tempo di viaggio accurato in minuti, considerando velocità massime,
    /// pendenze e tempi di sosta intermedi per ogni tratta.
    func calculateAccurateTravelTime(stationSequence: [String], train: Train) -> Int {
        guard stationSequence.count >= 2 else { return 0 }
        var totalSeconds: TimeInterval = 0
        var prevId = stationSequence[0]
        
        for i in 1..<stationSequence.count {
            let curId = stationSequence[i]
            if let path = network.findPathEdges(from: prevId, to: curId) {
                var legDist: Double = 0
                var legMinSpeed: Double = .infinity
                for edge in path {
                    legDist += edge.distance
                    legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                }
                
                if legDist > 0 {
                    var gradient: Double = 0
                    if let fN = network.nodes.first(where: { $0.id == prevId }),
                       let tN = network.nodes.first(where: { $0.id == curId }),
                       let fA = fN.altitude, let tA = tN.altitude {
                        gradient = ((tA - fA) / (legDist * 1000)) * 100
                    }
                    
                    let hours = FDCSchedulerEngine.calculateTravelTime(
                        distanceKm: legDist,
                        maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed,
                        train: train,
                        initialSpeedKmh: 0,
                        finalSpeedKmh: 0,
                        gradient: gradient
                    )
                    
                    totalSeconds += max(hours * 3600 + 35, 60)
                    
                    if i < stationSequence.count - 1 {
                        let node = network.nodes.first(where: { $0.id == curId })
                        totalSeconds += Double((node?.type == .interchange) ? 5 : 3) * 60
                    }
                }
            }
            prevId = curId
        }
        return Int(ceil(totalSeconds / 60))
    }
    
    /// Calcola i minuti di percorrenza dalla prima stazione fino alla stazione target.
    func travelMinutesToStation(_ targetId: String, in sequence: [String], train: Train) -> Double {
        var totalMinutes: Double = 0
        var prevId = sequence[0]
        
        for i in 1..<sequence.count {
            let sid = sequence[i]
            if sid == targetId { break }
            totalMinutes += legTravelMinutes(from: prevId, to: sid, train: train)
            totalMinutes += dwellMinutes(at: prevId)
            prevId = sid
        }
        return totalMinutes
    }
    
    /// Calcola i minuti di percorrenza per una singola tratta tra due stazioni consecutive.
    func legTravelMinutes(from: String, to: String, train: Train) -> Double {
        guard let path = network.findPathEdges(from: from, to: to) else { return 0 }
        var legDist: Double = 0
        var legSpeed: Double = .infinity
        for edge in path {
            legDist += edge.distance
            legSpeed = min(legSpeed, Double(edge.maxSpeed))
        }
        guard legDist > 0 else { return 0 }
        let effectiveSpeed = legSpeed == .infinity ? 100.0 : legSpeed
        let hours = FDCSchedulerEngine.calculateTravelTime(
            distanceKm: legDist,
            maxSpeedKmh: effectiveSpeed,
            train: train,
            initialSpeedKmh: 0,
            finalSpeedKmh: 0
        )
        return (hours * 60) + (35.0 / 60.0)
    }
    
    /// Restituisce i minuti di sosta in stazione.
    func dwellMinutes(at stationId: String) -> Double {
        let node = network.nodes.first(where: { $0.id == stationId })
        let isInterchange = node?.type == .interchange
        return isInterchange ? 5.0 : 3.0
    }
    
    // MARK: - Altitude & Elevation
    
    /// Calcola le caratteristiche altimetriche della linea.
    func calculateAltitudeCharacteristics(stationSequence: [String]) -> (totalElevationGain: Double?, maxGradient: Double?, avgGradient: Double?) {
        let nodes = stationSequence.compactMap { id in network.nodes.first(where: { $0.id == id }) }
        guard nodes.count >= 2 else { return (nil, nil, nil) }
        
        let service = InfrastructureService(network: network)
        var totalGain = 0.0
        var maxGrad = 0.0
        var totalDist = 0.0
        var totalDescent = 0.0
        
        for i in 0..<(nodes.count - 1) {
            let (gain, descent, grad, dist) = segmentElevation(from: nodes[i].id, to: nodes[i + 1].id, service: service)
            totalGain += gain
            totalDescent += descent
            maxGrad = max(maxGrad, grad)
            totalDist += dist
        }
        
        let totalChange = totalGain + totalDescent
        let avg = totalDist > 0 ? (totalChange / (totalDist * 1000)) * 1000 : 0
        return (Optional(totalGain), Optional(maxGrad), Optional(avg))
    }
    
    private func segmentElevation(from: String, to: String, service: InfrastructureService) -> (gain: Double, descent: Double, maxGrad: Double, dist: Double) {
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
}
