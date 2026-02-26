import Foundation

/// Servizio per la gestione dei percorsi e delle sequenze di stazioni.
final class PathResolver {
    private let network: RailwayNetwork
    
    init(network: RailwayNetwork) {
        self.network = network
    }
    
    /// Risolve la sequenza di stazioni tra partenza e arrivo su una data linea.
    func resolveStationSequence(route: TrainRoute, startId: String, endId: String) -> [String] {
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
    func presetTaktHub(stationSequence: [String], currentHubId: String) -> String {
        let taktNodesInPath = stationSequence.compactMap { sid in
            network.nodes.first(where: { $0.id == sid && $0.taktMinutes != nil })
        }
        
        guard !taktNodesInPath.isEmpty else { return "" }
        
        // Se l'ID corrente è ancora nel percorso, lo manteniamo
        if taktNodesInPath.contains(where: { $0.id == currentHubId }) { return currentHubId }
        
        // Altrimenti, cerchiamo il primo nodo di scambio con Takt
        if let interchange = taktNodesInPath.first(where: { $0.type == Node.NodeType.interchange }) {
            return interchange.id
        } else {
            // Fallback sul primo nodo Takt nel percorso
            return taktNodesInPath.first?.id ?? ""
        }
    }
    
    /// Verifica se la sequenza stazioni contiene tratte ad alta velocità.
    func hasHighSpeedTrack(stationSequence: [String]) -> Bool {
        guard stationSequence.count >= 2 else { return false }
        for i in 0..<(stationSequence.count - 1) {
            let from = stationSequence[i]
            let to = stationSequence[i + 1]
            let hasHS = network.edges.contains { edge in
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
        return network.calculatePathDistance(path: stationSequence)
    }
}
