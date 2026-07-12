import Foundation

/// Servizio per la gestione dei percorsi e delle sequenze di stazioni.
struct PathResolver {
    private let topology: RailwayTopology

    init(topology: RailwayTopology) {
        self.topology = topology
    }

    init(network: NetworkModel) {
        self.topology = RailwayTopology(network: network)
    }

    /// Risolve la sequenza di stazioni tra partenza e arrivo su una data linea.
    func resolveStationSequence(
        route: TrainRoute,
        startId: String,
        endId: String
    ) -> [String] {
        guard !startId.isEmpty, !endId.isEmpty else { return [] }
        let lineStations = route.stationIds
        guard let sIdx = lineStations.firstIndex(of: startId),
              let eIdx = lineStations.firstIndex(of: endId) else { return [] }

        let range = sIdx <= eIdx
            ? Array(lineStations[sIdx...eIdx])
            : Array(lineStations[eIdx...sIdx].reversed())

        return range
    }

    /// Pre-seleziona un hub Takt sensato nel percorso.
    func presetTaktHub(
        stationSequence: [String],
        currentHubId: String
    ) -> String {
        let taktNodesInPath = stationSequence.compactMap { sid in
            topology.node(id: sid).flatMap { node in
                node.taktMinutes != nil ? node : nil
            }
        }

        guard !taktNodesInPath.isEmpty else { return "" }

        if taktNodesInPath.contains(where: { $0.id == currentHubId }) {
            return currentHubId
        }

        if let interchange = taktNodesInPath.first(
            where: { $0.type == Node.NodeType.interchange }
        ) {
            return interchange.id
        }
        return taktNodesInPath.first?.id ?? ""
    }

    /// Verifica se la sequenza stazioni contiene tratte ad alta velocità.
    func hasHighSpeedTrack(stationSequence: [String]) -> Bool {
        guard stationSequence.count >= 2 else { return false }
        for i in 0..<(stationSequence.count - 1) {
            let from = stationSequence[i]
            let to = stationSequence[i + 1]
            let hasHS = topology.edges.contains { edge in
                let matchesDirection = (edge.from == from && edge.to == to)
                    || (edge.from == to && edge.to == from)
                return matchesDirection && edge.trackType == .highSpeed
            }
            if hasHS { return true }
        }
        return false
    }

    /// Calcola la distanza totale di un percorso.
    func calculatePathDistance(stationSequence: [String]) -> Double {
        topology.calculatePathDistance(path: stationSequence)
    }
}
