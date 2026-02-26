import Foundation
import SwiftUI

/// Servizio centralizzato per la gestione dell'infrastruttura ferroviaria fisica.
///
/// Responsabilità:
/// - Gestione ferrovie (Ferrovia) e loro proprietà
/// - Calcoli di distanza con gestione junction nodes
/// - Validazione topologia della rete
/// - Generazione segmenti e segnali
/// - Query su percorsi e connessioni
///
/// Questo servizio segue i principi di "Code That Fits in Your Head":
/// - Single Responsibility: gestisce solo l'infrastruttura fisica
/// - Nessuna dipendenza da UI
/// - Facilmente testabile
final class InfrastructureService {
    private let network: NetworkModel
    
    init(network: NetworkModel) {
        self.network = network
    }
    
    // MARK: - Ferrovia Management
    
    /// Crea una nuova ferrovia dalla selezione di stazioni
    func createFerrovia(name: String, stationIds: [String], color: String?, electrification: ElectrificationType = .dc3kv) -> Result<Ferrovia, InfrastructureError> {
        // Valida il percorso
        switch validateFerroviaPath(stationIds) {
        case .success:
            let ferrovia = Ferrovia(name: name, color: color, nodeIds: stationIds, electrification: electrification)
            // Propagate electrification to nodes and edges immediately
            propagateElectrification(to: ferrovia)
            return .success(ferrovia)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Propaga il tipo di elettrificazione della ferrovia a tutti i nodi e binari che ne fanno parte
    func propagateElectrification(to ferrovia: Ferrovia) {
        // 1. Update nodes
        for stationId in ferrovia.nodeIds {
            if let nodeIdx = network.nodes.firstIndex(where: { $0.id == stationId }) {
                network.nodes[nodeIdx].electrification = ferrovia.electrification
            }
        }
        
        // 2. Update edges (including junctions between stations)
        for i in 0..<ferrovia.nodeIds.count - 1 {
            let fromId = ferrovia.nodeIds[i]
            let toId = ferrovia.nodeIds[i + 1]
            
            if let pathResult = findPath(from: fromId, to: toId) {
                // All nodes in the path (including junctions)
                for node in pathResult.nodes {
                    if let nodeIdx = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        network.nodes[nodeIdx].electrification = ferrovia.electrification
                    }
                }
                
                // All edges in the path
                for segment in pathResult.segments {
                    if let edgeIdx = network.edges.firstIndex(where: { $0.from == segment.from && $0.to == segment.to }) {
                        network.edges[edgeIdx].electrification = ferrovia.electrification
                    } else if let edgeIdx = network.edges.firstIndex(where: { $0.from == segment.to && $0.to == segment.from }) {
                        network.edges[edgeIdx].electrification = ferrovia.electrification
                    }
                }
            }
        }
    }
    
    /// Valida che una sequenza di stazioni formi un percorso valido
    func validateFerroviaPath(_ stationIds: [String]) -> Result<Void, InfrastructureError> {
        guard !stationIds.isEmpty else {
            return .failure(.emptyPath)
        }
        
        guard stationIds.count >= 2 else {
            return .failure(.invalidPath(reason: "A ferrovia must have at least 2 stations"))
        }
        
        // Check for duplicates
        let uniqueIds = Set(stationIds)
        if uniqueIds.count != stationIds.count {
            let duplicates = stationIds.filter { id in
                stationIds.filter { $0 == id }.count > 1
            }
            return .failure(.duplicateStations(Array(Set(duplicates))))
        }
        
        // Verify all nodes exist
        for id in stationIds {
            guard network.nodes.contains(where: { $0.id == id }) else {
                return .failure(.nodeNotFound(id: id))
            }
        }
        
        // Verify connectivity
        for i in 0..<stationIds.count - 1 {
            let from = stationIds[i]
            let to = stationIds[i + 1]
            
            if findPath(from: from, to: to) == nil {
                return .failure(.disconnectedNodes(from: from, to: to))
            }
        }
        
        return .success(())
    }
    
    /// Ottiene tutte le proprietà calcolate di una ferrovia
    func getFerroviaProperties(_ ferroviaId: String) -> FerroviaProperties? {
        guard let ferrovia = network.lines.first(where: { $0.id == ferroviaId }) else {
            return nil
        }
        
        return getFerroviaProperties(ferrovia: ferrovia)
    }
    
    /// Ottiene le proprietà calcolate di una ferrovia data
    func getFerroviaProperties(ferrovia: Ferrovia) -> FerroviaProperties {
        let nodes = ferrovia.nodeIds.compactMap { id in
            network.nodes.first(where: { $0.id == id })
        }
        
        let totalDistance = calculateTotalDistance(path: ferrovia.nodeIds)
        let altitudeProfile = buildAltitudeProfile(path: ferrovia.nodeIds)
        let segments = buildFerroviaSegments(path: ferrovia.nodeIds)
        
        let stationCount = nodes.filter { $0.type == .station || $0.type == .interchange }.count
        let junctionCount = altitudeProfile.filter { !$0.isStation }.count
        
        return FerroviaProperties(
            id: ferrovia.id,
            name: ferrovia.name,
            totalDistance: totalDistance,
            stationCount: stationCount,
            junctionCount: junctionCount,
            altitudeProfile: altitudeProfile,
            segments: segments
        )
    }
    
    // MARK: - Distance Calculations
    
    /// Calcola la distanza tra due nodi, gestendo junction nodes intermedi (BFS)
    func calculateDistance(from fromId: String, to toId: String) -> Double? {
        guard let pathResult = findPath(from: fromId, to: toId) else {
            return nil
        }
        return pathResult.totalDistance
    }
    
    /// Calcola la distanza totale di un percorso
    func calculateTotalDistance(path: [String]) -> Double {
        var total = 0.0
        for i in 0..<path.count - 1 {
            if let distance = calculateDistance(from: path[i], to: path[i + 1]) {
                total += distance
            }
        }
        return total
    }
    
    /// Trova il percorso tra due nodi (ritorna tutti i nodi, inclusi junction)
    func findPath(from fromId: String, to toId: String) -> PathResult? {
        // BFS to find shortest path including junction nodes
        var visited = Set<String>()
        var queue: [(nodeId: String, distance: Double, path: [String])] = [(fromId, 0.0, [fromId])]
        
        while !queue.isEmpty {
            let (currentId, distSoFar, path) = queue.removeFirst()
            
            if visited.contains(currentId) { continue }
            visited.insert(currentId)
            
            // Found destination
            if currentId == toId {
                let nodes = path.compactMap { id in
                    network.nodes.first(where: { $0.id == id })
                }
                
                // Build segments
                var segments: [(from: String, to: String, distance: Double)] = []
                for i in 0..<path.count - 1 {
                    if let edge = network.findEdge(from: path[i], to: path[i + 1]) {
                        segments.append((path[i], path[i + 1], edge.distance))
                    }
                }
                
                return PathResult(nodes: nodes, totalDistance: distSoFar, segments: segments)
            }
            
            // Explore neighbors (bidirectional - consider edges in both directions)
            let outEdges = network.edges.filter { $0.from == currentId }
            let inEdges = network.edges.filter { $0.to == currentId }
            
            // Outgoing edges (normal direction)
            for edge in outEdges {
                let targetId = edge.to
                let newDist = distSoFar + edge.distance
                var newPath = path
                newPath.append(targetId)
                queue.append((targetId, newDist, newPath))
            }
            
            // Incoming edges (reverse direction - treat as bidirectional)
            for edge in inEdges {
                let targetId = edge.from
                let newDist = distSoFar + edge.distance
                var newPath = path
                newPath.append(targetId)
                queue.append((targetId, newDist, newPath))
            }
        }
        
        return nil
    }
    
    /// Trova tutti i percorsi possibili tra due nodi (con limite di profondità)
    func findAllPaths(from fromId: String, to toId: String, maxDepth: Int = 10) -> [[String]] {
        var allPaths: [[String]] = []
        var visited = Set<String>()
        
        func dfs(currentId: String, path: [String], depth: Int) {
            if depth > maxDepth { return }
            
            if currentId == toId {
                allPaths.append(path)
                return
            }
            
            visited.insert(currentId)
            
            let outEdges = network.edges.filter { $0.from == currentId }
            for edge in outEdges {
                let targetId = edge.to
                if !visited.contains(targetId) {
                    var newPath = path
                    newPath.append(targetId)
                    dfs(currentId: targetId, path: newPath, depth: depth + 1)
                }
            }
            
            visited.remove(currentId)
        }
        
        dfs(currentId: fromId, path: [fromId], depth: 0)
        return allPaths
    }
    
    // MARK: - Electrification Queries
    
    /// Verifica se un percorso (sequenza di stazioni) è interamente elettrificato
    func checkPathElectrification(stationIds: [String]) -> Bool {
        guard stationIds.count >= 2 else { return true }
        
        for i in 0..<(stationIds.count - 1) {
            let from = stationIds[i]
            let to = stationIds[i+1]
            guard let path = findPath(from: from, to: to) else { continue }
            
                for segment in path.segments {
                    if let edge = network.edges.first(where: { ($0.from == segment.from && $0.to == segment.to) || ($0.from == segment.to && $0.to == segment.from) }) {
                        if !edge.electrification.isElectrified {
                            return false
                        }
                    }
                }
        }
        return true
    }
    
    // MARK: - Topology Queries
    
    /// Ottiene tutti i nodi connessi a un dato nodo
    func getConnectedNodes(nodeId: String, includingJunctions: Bool = true) -> [RailwayNode] {
        let connectedIds = network.getConnectedNodeIds(for: nodeId)
        let nodes = connectedIds.compactMap { id in
            network.nodes.first(where: { $0.id == id })
        }
        
        if includingJunctions {
            return nodes
        } else {
            return nodes.filter { $0.type == .station || $0.type == .interchange }
        }
    }
    
    /// Verifica se due nodi sono connessi direttamente o tramite junctions
    func areNodesConnected(_ node1: String, _ node2: String) -> Bool {
        return findPath(from: node1, to: node2) != nil
    }
    
    // MARK: - Segmentation & Signals
    
    /// Genera o aggiorna la segmentazione per tutti gli edge della rete
    func processNetworkSegmentation() {
        for i in 0..<network.edges.count {
            if network.edges[i].segments.isEmpty {
                network.edges[i].segments = generateSegments(for: network.edges[i])
            }
        }
    }
    
    /// Genera segmenti per un singolo edge
    func generateSegments(for edge: RailwayEdge) -> [TrackSegment] {
        let blockLength: Double = {
            switch edge.trackType {
            case .highSpeed: return 2.7
            case .double: return 1.35
            case .single, .regional: return 5.0
            }
        }()
        
        let totalDistance = edge.distance
        let numSegments = max(1, Int(ceil(totalDistance / blockLength)))
        let actualSegmentLength = totalDistance / Double(numSegments)
        
        var segments: [TrackSegment] = []
        for i in 0..<numSegments {
            let signal: Signal? = (i < numSegments - 1) ? Signal(
                id: UUID(),
                name: "S.\(edge.from)-\(edge.to).\(i+1)",
                aspect: .stop,
                positionAtEnd: true
            ) : nil
            
            let segment = TrackSegment(
                id: UUID(),
                order: i,
                length: actualSegmentLength,
                isOccupied: false,
                signal: signal
            )
            segments.append(segment)
        }
        
        return segments
    }
    
    // MARK: - Validation
    
    /// Valida l'integrità della rete (no nodi orfani, edge validi, etc)
    func validateNetworkIntegrity() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check for orphaned nodes
        let connectedNodeIds = Set(network.edges.flatMap { [$0.from, $0.to] })
        let orphanedNodes = network.nodes.filter { !connectedNodeIds.contains($0.id) && $0.type != .station }
        
        if !orphanedNodes.isEmpty {
            issues.append(ValidationIssue(
                severity: .warning,
                description: "Found \(orphanedNodes.count) orphaned nodes (not connected to any edge)",
                affectedNodes: orphanedNodes.map { $0.id }
            ))
        }
        
        // Check for edges with missing nodes
        for edge in network.edges {
            let fromExists = network.nodes.contains(where: { $0.id == edge.from })
            let toExists = network.nodes.contains(where: { $0.id == edge.to })
            
            if !fromExists || !toExists {
                issues.append(ValidationIssue(
                    severity: .error,
                    description: "Edge has missing nodes",
                    affectedNodes: [edge.from, edge.to].filter { id in
                        !network.nodes.contains(where: { $0.id == id })
                    },
                    affectedEdges: [edge.id]
                ))
            }
        }
        
        // Check for nodes without altitude
        let nodesWithoutAltitude = network.nodes.filter { $0.altitude == nil }
        if !nodesWithoutAltitude.isEmpty {
            issues.append(ValidationIssue(
                severity: .info,
                description: "Found \(nodesWithoutAltitude.count) nodes without altitude data",
                affectedNodes: nodesWithoutAltitude.map { $0.id }
            ))
        }
        
        return issues
    }
    
    // MARK: - Private Helpers
    
    /// Costruisce il profilo altimetrico completo di un percorso
    private func buildAltitudeProfile(path: [String]) -> [AltitudePoint] {
        var points: [AltitudePoint] = []
        var cumulativeDistance = 0.0
        
        for i in 0..<path.count {
            let nodeId = path[i]
            guard let node = network.nodes.first(where: { $0.id == nodeId }) else {
                continue
            }
            
            let isStation = node.type == .station || node.type == .interchange
            let altitude = node.altitude ?? 0
            
            points.append(AltitudePoint(
                id: nodeId,
                nodeId: nodeId,
                distance: cumulativeDistance,
                altitude: altitude,
                isStation: isStation,
                node: node
            ))
            
            // Add distance to next node
            if i < path.count - 1 {
                if let pathResult = findPath(from: nodeId, to: path[i + 1]) {
                    cumulativeDistance += pathResult.totalDistance
                }
            }
        }
        
        return points
    }
    
    /// Costruisce i segmenti di una ferrovia
    private func buildFerroviaSegments(path: [String]) -> [FerroviaSegment] {
        var segments: [FerroviaSegment] = []
        
        for i in 0..<path.count - 1 {
            let fromId = path[i]
            let toId = path[i + 1]
            
            guard let pathResult = findPath(from: fromId, to: toId) else {
                continue
            }
            
            let junctionNodes = pathResult.nodes.filter { $0.type == .junction }
            
            segments.append(FerroviaSegment(
                fromNodeId: fromId,
                toNodeId: toId,
                distance: pathResult.totalDistance,
                hasJunctions: !junctionNodes.isEmpty,
                junctionNodes: junctionNodes
            ))
        }
        
        return segments
    }
}
