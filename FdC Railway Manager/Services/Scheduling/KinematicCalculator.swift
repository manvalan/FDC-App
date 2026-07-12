import Foundation

/// Servizio dedicato ai calcoli cinematici e dei tempi di percorrenza.
/// Segue i principi di "Code That Fits in Your Head" isolando la logica computazionale.
struct KinematicCalculator {
    private let topology: RailwayTopology

    init(topology: RailwayTopology) {
        self.topology = topology
    }

    init(network: NetworkModel) {
        self.topology = RailwayTopology(nodes: network.nodes, edges: network.edges)
    }

    // MARK: - Travel Time Calculations

    func calculateAccurateTravelTime(
        stationSequence: [String],
        train: Train
    ) -> Int {
        guard stationSequence.count >= 2 else { return 0 }
        var totalSeconds: TimeInterval = 0
        var prevId = stationSequence[0]

        for i in 1..<stationSequence.count {
            let curId = stationSequence[i]
            if let path = topology.findPathEdges(from: prevId, to: curId) {
                var legDist: Double = 0
                var legMinSpeed: Double = .infinity
                for edge in path {
                    legDist += edge.distance
                    legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                }

                if legDist > 0 {
                    var gradient: Double = 0
                    if let fN = topology.node(id: prevId),
                       let tN = topology.node(id: curId),
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
                        let node = topology.node(id: curId)
                        totalSeconds += Double(
                            (node?.type == .interchange) ? 5 : 3
                        ) * 60
                    }
                }
            }
            prevId = curId
        }
        return Int(ceil(totalSeconds / 60))
    }

    func travelMinutesToStation(
        _ targetId: String,
        in sequence: [String],
        train: Train
    ) -> Double {
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

    func legTravelMinutes(from: String, to: String, train: Train) -> Double {
        guard let path = topology.findPathEdges(from: from, to: to) else {
            return 0
        }
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

    func dwellMinutes(at stationId: String) -> Double {
        let node = topology.node(id: stationId)
        let isInterchange = node?.type == .interchange
        return isInterchange ? 5.0 : 3.0
    }

    // MARK: - Altitude & Elevation

    func calculateAltitudeCharacteristics(
        stationSequence: [String]
    ) -> (totalElevationGain: Double?, maxGradient: Double?, avgGradient: Double?) {
        let nodes = stationSequence.compactMap { topology.node(id: $0) }
        guard nodes.count >= 2 else { return (nil, nil, nil) }

        var totalGain = 0.0
        var maxGrad = 0.0
        var totalDist = 0.0
        var totalDescent = 0.0

        for i in 0..<(nodes.count - 1) {
            let segment = segmentElevation(
                from: nodes[i].id,
                to: nodes[i + 1].id
            )
            totalGain += segment.gain
            totalDescent += segment.descent
            maxGrad = max(maxGrad, segment.maxGrad)
            totalDist += segment.dist
        }

        let totalChange = totalGain + totalDescent
        let avg = totalDist > 0
            ? (totalChange / (totalDist * 1000)) * 1000
            : 0
        return (Optional(totalGain), Optional(maxGrad), Optional(avg))
    }

    private func segmentElevation(
        from: String,
        to: String
    ) -> (gain: Double, descent: Double, maxGrad: Double, dist: Double) {
        guard let path = topology.findPathEdges(from: from, to: to) else {
            return (0, 0, 0, 0)
        }
        var gain = 0.0
        var descent = 0.0
        var maxGrad = 0.0
        var dist = 0.0
        var prevAlt = topology.node(id: from)?.altitude

        for edge in path {
            dist += edge.distance
            guard let nextAlt = topology.node(id: edge.to)?.altitude,
                  let startAlt = prevAlt ?? topology.node(id: edge.from)?.altitude
            else { continue }
            let diff = nextAlt - startAlt
            if diff > 0 { gain += diff } else { descent += abs(diff) }
            if edge.distance > 0 {
                let gradient = abs(diff / (edge.distance * 1000)) * 1000
                maxGrad = max(maxGrad, gradient)
            }
            prevAlt = nextAlt
        }
        return (gain, descent, maxGrad, dist)
    }
}
