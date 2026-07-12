import Foundation

/// Ricalcolo fisico degli orari fermata-per-fermata (Functional Core).
struct ScheduleRefresher {
    let topology: RailwayTopology
    let taktEngine: TaktEngine

    init(topology: RailwayTopology) {
        self.topology = topology
        self.taktEngine = TaktEngine(
            topology: topology,
            kinematicCalculator: KinematicCalculator(topology: topology)
        )
    }

    func refreshMultiple(
        _ trains: inout [Train], preferredHubId: String? = nil
    ) {
        for i in trains.indices {
            refreshSingle(&trains[i], preferredHubId: preferredHubId)
        }
    }

    func refreshSingle(_ train: inout Train, preferredHubId: String? = nil) {
        if let (hIdx, hNode) = findHubNode(in: train, preferredId: preferredHubId) {
            taktEngine.refreshTaktSchedule(train: &train, hIdx: hIdx, hNode: hNode)
        } else {
            refreshStandardSchedule(train: &train)
        }
    }

    func findHubNode(in train: Train, preferredId: String?) -> (Int, Node)? {
        if let pid = preferredId,
           let idx = train.stops.firstIndex(where: { $0.stationId == pid }),
           let node = topology.nodes.first(where: { $0.id == pid && $0.taktMinutes != nil }) {
            return (idx, node)
        }
        for i in train.stops.indices {
            if let node = topology.nodes.first(where: {
                $0.id == train.stops[i].stationId && $0.taktMinutes != nil
            }) {
                return (i, node)
            }
        }
        return nil
    }

    func refreshStandardSchedule(train: inout Train) {
        guard let depTime = train.departureTime else { return }
        let nodes = topology.nodes
        let edges = topology.edges
        var currentTime = depTime.normalized()

        for j in train.stops.indices {
            if j == 0 {
                train.stops[j].arrival = nil
                train.stops[j].departure = currentTime
            } else {
                let prevId = train.stops[j - 1].stationId
                let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(
                    from: prevId, to: train.stops[j].stationId, train: train,
                    nodes: nodes, edges: edges, isStarting: j == 1, isStopping: true
                )
                currentTime = currentTime.addingTimeInterval(tt)
                let roundedArr = TaktEngine.roundToBusinessSeconds(currentTime)
                train.stops[j].arrival = roundedArr
                let extraDwell = train.stops[j].extraDwellTime
                let dwellDuration = (Double(train.stops[j].minDwellTime) + extraDwell) * 60
                currentTime = roundedArr.addingTimeInterval(dwellDuration)
                let roundedDep = TaktEngine.roundToBusinessSeconds(currentTime)
                train.stops[j].departure = (j < train.stops.count - 1) ? roundedDep : nil
                if let d = train.stops[j].departure { currentTime = d }
            }
        }
    }
}
