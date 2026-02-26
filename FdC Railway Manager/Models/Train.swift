import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public struct Train: Identifiable, Codable, Hashable {
    // MARK: - Train Properties

    public var id: UUID = UUID()
    public var number: Int?
    public var name: String
    public var type: String
    /// ID of the TrainRoute this train belongs to (used for cataloguing and train-number ordering).
    /// Backward-compatible: decoded from both `"routeId"` (new) and `"lineId"` (legacy).
    public var routeId: String?
    public var isElectric: Bool = true
    public var departureTime: Date?
    public var stops: [RelationStop] = []
    
    // Collegamento al materiale rotante
    public var vehicleId: UUID?
    
    // Technical specs
    public var maxSpeed: Double = 120
    public var acceleration: Double = 0.5
    public var deceleration: Double = 0.5
    public var mass: Double = 200
    public var power: Double = 2500
    public var priority: Int = 5
    public var isMainTrain: Bool = false
    public var schedulingError: String?
    
    public init(id: UUID = UUID(), number: Int? = nil, name: String, type: String, lineId: String? = nil, departureTime: Date? = nil, stops: [RelationStop] = [], vehicleId: UUID? = nil, maxSpeed: Double = 160, acceleration: Double = 0.5, deceleration: Double = 0.4, mass: Double = 200, power: Double = 2500, priority: Int = 5, isElectric: Bool = true, isMainTrain: Bool = false) {
        self.id = id
        self.number = number
        self.name = name
        self.type = type
        self.routeId = lineId   // init param kept as lineId for call-site compat during migration
        self.stops = stops
        self.vehicleId = vehicleId
        self.departureTime = departureTime
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.mass = mass
        self.power = power
        self.priority = priority
        self.isElectric = isElectric
        self.isMainTrain = isMainTrain
    }
    
    enum CodingKeys: String, CodingKey {
        case id, number, name, type
        case routeId             // new key
        case lineId              // legacy key (read-only for migration)
        case departureTime, stops, maxSpeed, acceleration, deceleration
        case mass, power, priority, vehicleId, schedulingError, isElectric, isMainTrain
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        // Backward compat: prefer new routeId key, fall back to legacy lineId
        routeId = try container.decodeIfPresent(String.self, forKey: .routeId)
            ?? container.decodeIfPresent(String.self, forKey: .lineId)
        departureTime = try container.decodeIfPresent(Date.self, forKey: .departureTime)
        stops = try container.decodeIfPresent([RelationStop].self, forKey: .stops) ?? []
        vehicleId = try container.decodeIfPresent(UUID.self, forKey: .vehicleId)
        maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed) ?? 120
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration) ?? 0.5
        deceleration = try container.decodeIfPresent(Double.self, forKey: .deceleration) ?? 0.5
        mass = try container.decodeIfPresent(Double.self, forKey: .mass) ?? 200
        power = try container.decodeIfPresent(Double.self, forKey: .power) ?? 2500
        isElectric = try container.decodeIfPresent(Bool.self, forKey: .isElectric) ?? true
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 5
        isMainTrain = try container.decodeIfPresent(Bool.self, forKey: .isMainTrain) ?? false
        schedulingError = try container.decodeIfPresent(String.self, forKey: .schedulingError)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(number, forKey: .number)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(routeId, forKey: .routeId)
        try container.encodeIfPresent(departureTime, forKey: .departureTime)
        try container.encode(stops, forKey: .stops)
        try container.encodeIfPresent(vehicleId, forKey: .vehicleId)
        try container.encode(maxSpeed, forKey: .maxSpeed)
        try container.encode(acceleration, forKey: .acceleration)
        try container.encode(deceleration, forKey: .deceleration)
        try container.encode(mass, forKey: .mass)
        try container.encode(power, forKey: .power)
        try container.encode(priority, forKey: .priority)
        try container.encode(isElectric, forKey: .isElectric)
        try container.encode(isMainTrain, forKey: .isMainTrain)
        try container.encodeIfPresent(schedulingError, forKey: .schedulingError)
    }
}

extension Train {
    /// Restituisce la lista dei binari preferenziali ordinati per priorità.
    /// - Parameters:
    ///   - node: La stazione in oggetto.
    ///   - prevStationId: L'ID della stazione da cui proviene il treno (opzionale).
    ///   - nextStationId: L'ID della stazione successiva (opzionale).
    ///   - line: La linea di appartenenza del treno (se nil, usa quella del treno).
    ///   - isSkipping: Se il treno transita senza fermarsi in questa stazione.
    /// - Returns: Una lista di stringhe (es: ["2", "1", "3"]) dove il primo è il preferito.
    func getPreferredTracks(at node: Node, prevStationId: String?, nextStationId: String?, for route: TrainRoute?, isSkipping: Bool = false) -> [String] {
        let maxPlatforms = node.platforms ?? 2
        let allPlatforms = (1...maxPlatforms).map { "\($0)" }
        let targetRouteId = route?.id ?? self.routeId ?? ""
        
        // Cerchiamo i vincoli specifici per questa linea in questa stazione
        let lineConstraints = node.routingConstraints.filter { $0.routeId == targetRouteId }
        
        // 1. Cerchiamo un vincolo che corrisponda esattamente alla direzione (prossima stazione)
        let matchingConstraint = lineConstraints.first { $0.directionStationId == nextStationId } 
                              ?? lineConstraints.first { $0.directionStationId == nil }
        
        var preferred: [String] = []
        
        if let constraint = matchingConstraint {
            if isSkipping {
                // Priorità Transito: transitTracks -> stopTracks -> allowedTracks
                preferred.append(contentsOf: constraint.transitTracks ?? [])
                preferred.append(contentsOf: constraint.stopTracks ?? [])
                preferred.append(contentsOf: constraint.allowedTracks)
            } else {
                // Priorità Sosta: stopTracks -> transitTracks -> allowedTracks
                preferred.append(contentsOf: constraint.stopTracks ?? [])
                preferred.append(contentsOf: constraint.transitTracks ?? [])
                preferred.append(contentsOf: constraint.allowedTracks)
            }
        }
        
        // Se non abbiamo preferenze, restituiamo tutti i binari (es: ["1", "2"])
        if preferred.isEmpty {
            return allPlatforms
        }
        
        // Costruiamo la lista finale: prima i preferiti (evitando duplicati), poi gli altri come alternative
        var finalList: [String] = []
        for p in preferred {
            if !finalList.contains(p) { finalList.append(p) }
        }
        
        for platform in allPlatforms {
            if !finalList.contains(platform) {
                finalList.append(platform)
            }
        }
        
        return finalList
    }

    func isTrackPreferred(_ track: String, at node: Node, prevStationId: String?, nextStationId: String?, for routeId: String?) -> Bool {
        let targetRouteId = routeId ?? self.routeId ?? ""
        let lineConstraints = node.routingConstraints.filter { $0.routeId == targetRouteId }
        let matchingConstraint = lineConstraints.first { $0.directionStationId == nextStationId } 
                              ?? lineConstraints.first { $0.directionStationId == nil }
        return matchingConstraint?.allowedTracks.contains(track) ?? false
    }
}
