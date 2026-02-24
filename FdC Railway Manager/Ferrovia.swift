import Foundation
import SwiftUI

// MARK: - Ferrovia (Infrastruttura Fisica)
/// Una Ferrovia rappresenta un percorso fisico dell'infrastruttura ferroviaria:
/// un segmento della rete composto da una sequenza ordinata di stazioni/nodi collegati da binari.
/// NON contiene informazioni di servizio (treni, orari, cadenzamento).
public struct Ferrovia: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var color: String? // Colore per visualizzazione (hex)
    public var stationIds: [String] // Sequenza ordinata di stazioni/nodi
    public var electrification: ElectrificationType = .dc3kv // Tipo di elettrificazione
    
    public var uiColor: Color {
        if let hex = color, let c = Color(hex: hex) {
            return c
        }
        return .gray
    }
    
    public init(id: String = UUID().uuidString, name: String, color: String? = nil, stationIds: [String] = [], electrification: ElectrificationType = .dc3kv) {
        self.id = id
        self.name = name
        self.color = color
        self.stationIds = stationIds
        self.electrification = electrification
    }
}
