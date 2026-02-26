import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public struct RelationStop: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var stationId: String
    public var minDwellTime: Int = 3 // Minuit di sosta base (default 3)
    public var extraDwellTime: Double = 0 // Ritardo extra da AI (minuti)
    public var isSkipped: Bool = false // Se true, il treno non ferma (transito)
    public var track: String? // Binario programmato (es: "1")
    public var isManualTrack: Bool = false // Se true, non viene sovrascritto da auto-resolve o sync
    public var isPreferredTrack: Bool = false // Se true, l'AI riceve un bonus se sceglie questo binario
    
    // Per treni specifici: orari pianificati (opzionali, sovrascrivono il calcolo)
    public var plannedArrival: Date?
    public var plannedDeparture: Date?
    
    // Custom dwell time in seconds (when user manually sets departure)
    // If set, this overrides minDwellTime + extraDwellTime
    public var customDwellSeconds: TimeInterval?
    
    // Campi calcolati per visualizzazione/validazione corrente
    public var arrival: Date?
    public var departure: Date?

    enum CodingKeys: String, CodingKey {
        case id, stationId, minDwellTime, extraDwellTime, isSkipped, track, isManualTrack, isPreferredTrack, plannedArrival, plannedDeparture, customDwellSeconds, arrival, departure
    }

    public init(id: UUID = UUID(), stationId: String, minDwellTime: Int = 3, extraDwellTime: Double = 0, isSkipped: Bool = false, track: String? = nil, isManualTrack: Bool = false, isPreferredTrack: Bool = false, plannedArrival: Date? = nil, plannedDeparture: Date? = nil, customDwellSeconds: TimeInterval? = nil, arrival: Date? = nil, departure: Date? = nil) {
        self.id = id
        self.stationId = stationId
        self.minDwellTime = minDwellTime
        self.extraDwellTime = extraDwellTime
        self.isSkipped = isSkipped
        self.track = track
        self.isManualTrack = isManualTrack
        self.isPreferredTrack = isPreferredTrack
        self.plannedArrival = plannedArrival
        self.plannedDeparture = plannedDeparture
        self.customDwellSeconds = customDwellSeconds
        self.arrival = arrival
        self.departure = departure
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        stationId = try container.decode(String.self, forKey: .stationId)
        minDwellTime = try container.decodeIfPresent(Int.self, forKey: .minDwellTime) ?? 3
        extraDwellTime = try container.decodeIfPresent(Double.self, forKey: .extraDwellTime) ?? 0
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
        track = try container.decodeIfPresent(String.self, forKey: .track)
        isManualTrack = try container.decodeIfPresent(Bool.self, forKey: .isManualTrack) ?? false
        isPreferredTrack = try container.decodeIfPresent(Bool.self, forKey: .isPreferredTrack) ?? false
        plannedArrival = try container.decodeIfPresent(Date.self, forKey: .plannedArrival)
        plannedDeparture = try container.decodeIfPresent(Date.self, forKey: .plannedDeparture)
        customDwellSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .customDwellSeconds)
        arrival = try container.decodeIfPresent(Date.self, forKey: .arrival)
        departure = try container.decodeIfPresent(Date.self, forKey: .departure)
    }
}
