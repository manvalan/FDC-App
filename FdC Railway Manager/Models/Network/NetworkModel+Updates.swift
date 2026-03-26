import Foundation
import SwiftUI

extension NetworkModel {
    // MARK: - Infrastructure Updates
    
    /// Sets the altitude of a single TrackControlPoint on an edge.
    /// Does not create a checkpoint — the caller must do so before the drag.
    func updateControlPoint(edgeId: String, index: Int, altitude: Double) {
        guard let uuid = UUID(uuidString: edgeId),
              let idx = edges.firstIndex(where: { $0.id == uuid }),
              index < edges[idx].controlPoints.count
        else { return }
        edges[idx].controlPoints[index].altitude = altitude
    }

    func updateNode(_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil) {
        let (found, index) = findNodeIndex(id: id)
        guard found else { return }
        
        var node = nodes[index]
        if let lat = lat { node.latitude = lat }
        if let lon = lon { node.longitude = lon }
        if let alt = alt { node.altitude = alt }
        nodes[index] = node
        
        // Spring Model: Recalculate distances for all connected edges
        recalculateDistances(for: id)
    }

    private func findNodeIndex(id: String) -> (Bool, Int) {
        if let idx = nodes.firstIndex(where: { $0.id == id }) {
            return (true, idx)
        }
        return (false, 0)
    }

    /// Recalculates distancies for all edges connected to the specified node
    func recalculateDistances(for nodeId: String) {
        for idx in edges.indices {
            let edge = edges[idx]
            if edge.from == nodeId || edge.to == nodeId {
                updateEdgeDistance(at: idx)
            }
        }
    }

    private func updateEdgeDistance(at index: Int) {
        let edge = edges[index]
        // Se la distanza è stata impostata manualmente, non ricalcolarla in base alle coordinate
        guard !edge.hasManualDistance else { return }
        
        guard let n1 = findNode(id: edge.from),
              let n2 = findNode(id: edge.to) else { return }
        
        let newDist = calculateDistance(from: n1, to: n2)
        var updatedEdge = edge
        updatedEdge.distance = newDist
        edges[index] = updatedEdge
    }

    /// Calculate distance in km between two nodes based on coordinates
    func calculateDistance(from n1: Node, to n2: Node) -> Double {
        // Se un nodo appartiene a un Hub, usa le coordinate del genitore per il calcolo logico della distanza
        let eff1Lat = if let pid = n1.parentHubId, let parent = nodes.first(where: { $0.id == pid }) { parent.latitude ?? 0 } else { n1.latitude ?? 0 }
        let eff1Lon = if let pid = n1.parentHubId, let parent = nodes.first(where: { $0.id == pid }) { parent.longitude ?? 0 } else { n1.longitude ?? 0 }
        
        let eff2Lat = if let pid = n2.parentHubId, let parent = nodes.first(where: { $0.id == pid }) { parent.latitude ?? 0 } else { n2.latitude ?? 0 }
        let eff2Lon = if let pid = n2.parentHubId, let parent = nodes.first(where: { $0.id == pid }) { parent.longitude ?? 0 } else { n2.longitude ?? 0 }

        let dLat = eff1Lat - eff2Lat
        let dLon = eff1Lon - eff2Lon
        
        // Se i nodi sono nello stesso hub (stesse coordinate logiche), la distanza è 0
        if dLat == 0 && dLon == 0 { return 0.0 }
        
        let dist = sqrt(dLat * dLat + dLon * dLon) * 111.0 
        return max(0.1, round(dist * 10) / 10.0) // Arrotonda a 100m
    }

    func updateEdge(_ id: UUID, distance: Double? = nil, speed: Int? = nil, manual: Bool? = nil) {
        owner?.createCheckpoint()
        if let idx = edges.firstIndex(where: { $0.id == id }) {
            var edge = edges[idx]
            if let d = distance { 
                edge.distance = d 
                edge.hasManualDistance = true
            }
            if let s = speed { edge.maxSpeed = s }
            if let m = manual { edge.hasManualDistance = m }
            edges[idx] = edge
        }
    }
    
    func generateSegments(for edge: Edge) {
        if let idx = edges.firstIndex(where: { $0.id == edge.id }) {
            var newEdge = edge
            let segmentLength = 2.0 
            let count = max(1, Int(ceil(edge.distance / segmentLength)))
            var segments: [TrackSegment] = []
            
            for i in 0..<count {
                let len = (i == count - 1) ? (edge.distance - Double(i) * segmentLength) : segmentLength
                segments.append(TrackSegment(
                    order: i,
                    length: len,
                    speedLimit: edge.maxSpeed
                ))
            }
            newEdge.segments = segments
            edges[idx] = newEdge
        }
    }
    
    func updateSegment(_ edgeId: UUID, index: Int, speed: Double) {
        if let idx = edges.firstIndex(where: { $0.id == edgeId }) {
            var edge = edges[idx]
            if index < edge.segments.count {
                var seg = edge.segments[index]
                seg.speedLimit = Int(speed)
                edge.segments[index] = seg
                edges[idx] = edge
            }
        }
    }
    
    func splitEdge(_ edge: Edge) {
        owner?.createCheckpoint()
        guard let n1 = nodes.first(where: { $0.id == edge.from }),
              let n2 = nodes.first(where: { $0.id == edge.to }) else { return }
              
        let lat1 = n1.latitude ?? 0; let lon1 = n1.longitude ?? 0
        let lat2 = n2.latitude ?? 0; let lon2 = n2.longitude ?? 0
        let midLat = (lat1 + lat2) / 2; let midLon = (lon1 + lon2) / 2
        let midAlt = ((n1.altitude ?? 0) + (n2.altitude ?? 0)) / 2
        
        let checkpointId = "CP-\(Int.random(in: 1000...9999))"
        let newNode = Node(
            id: checkpointId,
            name: "Checkpoint \(checkpointId)",
            type: .junction,
            latitude: midLat,
            longitude: midLon,
            altitude: midAlt
        )
        
        addNode(newNode)
        removeEdge(edge.id)
        
        let d1 = edge.distance / 2.0
        addEdge(Edge(from: edge.from, to: newNode.id, distance: d1, trackType: edge.trackType, maxSpeed: edge.maxSpeed))
        addEdge(Edge(from: newNode.id, to: edge.to, distance: d1, trackType: edge.trackType, maxSpeed: edge.maxSpeed))
    }
    

}
