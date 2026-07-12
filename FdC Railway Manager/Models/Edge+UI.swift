import SwiftUI

/// UI-only: colore per tipo binario (separato dal modello Domain).
extension Edge.TrackType {
    var color: Color {
        switch self {
        case .highSpeed: return .red
        case .regional: return .blue
        case .single: return .gray
        }
    }
}

/// Modello UI: singolo, doppio, AV (indipendente da `pairedEdgeId` sottostante).
enum TrackLayoutMode: String, CaseIterable, Identifiable, Equatable {
    case single
    case double
    case highSpeed

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .single: return "1.circle"
        case .double: return "2.circle"
        case .highSpeed: return "bolt.fill"
        }
    }

    var localizationKey: String {
        switch self {
        case .single: return "single_track"
        case .double: return "double_track"
        case .highSpeed: return "high_speed_track"
        }
    }

    static func from(_ edge: Edge, in edges: [Edge]) -> TrackLayoutMode {
        if edge.trackType == .highSpeed { return .highSpeed }
        return isInPair(edge, in: edges) ? .double : .single
    }

    static func isInPair(_ edge: Edge, in edges: [Edge]) -> Bool {
        edge.pairedEdgeId != nil || edges.contains { $0.pairedEdgeId == edge.id }
    }
}

extension Edge {
    /// Offset perpendicolare canvas: 0 = una linea (singolo), ±spacing = due linee (doppio / AV accoppiato).
    static func visualRailOffset(for edge: Edge, in corridorEdges: [Edge], spacing: CGFloat = 4) -> CGFloat {
        guard TrackLayoutMode.isInPair(edge, in: corridorEdges) else { return 0 }
        let pairedCorridor = corridorEdges.filter { TrackLayoutMode.isInPair($0, in: corridorEdges) }
        guard pairedCorridor.count == 2 else { return 0 }
        let anchor = [edge.from, edge.to].sorted().first ?? edge.from
        return edge.from == anchor ? -spacing : spacing
    }
}
