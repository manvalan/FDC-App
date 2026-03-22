import Foundation
import SwiftUI

/// Gestisce la generazione e il mantenimento dell'infrastruttura dettagliata (blocchi, segnali).
class InfrastructureManager {
    static let shared = InfrastructureManager()
    
    // Lunghezze ufficiali dei blocchi (km)
    private let blockLengthAV: Double = 2.7
    private let blockLengthDouble: Double = 1.35
    private let blockLengthSingle: Double = 5.0
    
    /// Converte la rete esistente in una rete sezionata a blocchi.
    func processNetwork(_ network: NetworkModel) {
        for i in 0..<network.edges.count {
            if network.edges[i].segments.isEmpty {
                network.edges[i].segments = generateSegments(for: network.edges[i])
            }
        }
    }
    
    /// Genera la sequenza di segmenti per un determinato binario.
    private func generateSegments(for edge: Edge) -> [TrackSegment] {
        let blockLength: Double = {
            switch edge.trackType {
            case .highSpeed: return blockLengthAV
            case .double: return blockLengthDouble
            case .single, .regional: return blockLengthSingle
            }
        }()
        
        let totalDistance = edge.distance
        let numSegments = max(1, Int(ceil(totalDistance / blockLength)))
        let actualSegmentLength = totalDistance / Double(numSegments)
        
        var segments: [TrackSegment] = []
        for i in 0..<numSegments {
            // Crea un segnale di blocco alla fine di ogni segmento (tranne l'ultimo che precede la stazione)
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
}
