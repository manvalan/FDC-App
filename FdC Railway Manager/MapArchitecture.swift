import SwiftUI

/// Costanti centralizzate per la visualizzazione della mappa ferroviaria.
/// Segue il principio "Code that fits in your head" evitando Magic Numbers sparsi.
struct MapConstants {
    // Dimensioni e Padding
    static let canvasPadding: CGFloat = 50.0
    static let stationRadius: CGFloat = 20.0
    static let hitTestRadius: CGFloat = 40.0
    static let nodeLabelOffset: CGFloat = 28.0
    
    // Linee e Binari
    static let lineOffsetBase: CGFloat = 6.0
    static let infrastructureLineWidth: CGFloat = 1.5
    static let highSpeedDash: [CGFloat] = [3, 3]
    static let selectionOutlineWidth: CGFloat = 4.0
    static let commercialLineSelectionMultiplier: CGFloat = 1.5
    
    // Zoom
    static let minZoom: CGFloat = 1.0
    static let maxZoom: CGFloat = 5.0
    static let defaultZoom: CGFloat = 2.0
    static let zoomStep: CGFloat = 0.5
    
    // Animazioni
    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.8
    
    // Interazione
    static let longPressDuration: Double = 0.6
    static let dragMinimumDistance: CGFloat = 5.0
}

/// Rappresenta lo stato unitario dell'interazione con la mappa.
/// Previene stati impossibili (es. aggiungere binari mentre si sposta una stazione).
enum MapInteractionState: Equatable {
    case explore
    case addingStation
    case addingTrack(from: Node?, to: Node? = nil)
    case movingStation(nodeId: String)
    case pickingStation // Per callback esterne
    
    var isEditMode: Bool {
        switch self {
        case .explore, .pickingStation: return false
        default: return true
        }
    }
}

/// Modello dati per il rendering della mappa (parte Query del CQS).
/// Questo oggetto contiene tutto il necessario per il disegno, pre-calcolato.
struct MapRenderData {
    let size: CGSize
    let bounds: MapBounds
    let nodePositions: [String: CGPoint]
    let edgeGeometries: [String: [CGPoint]] // Chiave: canonicalKey degli edge
    let hubGeometries: [String: [CGPoint]] // Chiave: hubId
    let commercialLines: [SegmentKey: [PrecomputedLine]]
    
    // Hit-test Index (Pre-calculated for instant interaction)
    let selectionIndex: [HitTarget]
    
    struct HitTarget {
        enum TargetType { case node, edge }
        let id: String
        let type: TargetType
        let bounds: CGRect // Bounding box with threshold for fast rejection
        let center: CGPoint? // For node distance
        let points: [CGPoint]? // For edge precise distance
    }
    
    struct PrecomputedLine {
        let line: TrainRoute
        let color: Color
        let bundleSize: Int  // Number of parallel lines on this segment
    }
}

/// Chiave hashable per identificare segmenti tra due nodi (indipendentemente dall'ordine).
struct SegmentKey: Hashable {
    let from: String
    let to: String
    
    init(_ a: String, _ b: String) {
        if a < b {
            from = a
            to = b
        } else {
            from = b
            to = a
        }
    }
}
