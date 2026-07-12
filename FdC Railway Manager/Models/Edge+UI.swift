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
