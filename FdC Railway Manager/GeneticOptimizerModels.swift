import Foundation

/// PIGNOLO SPEED: Using structs for memory efficiency and arrays for O(1) access
struct TrainGene: Codable, Equatable {
    let trainId: UUID
    var departureOffset: Double // in seconds
    var stopDwellOffsets: [Double] // Indexed by stop index
    var stopTracks: [String] // Indexed by stop index
    var legTransitTimes: [Double] // seconds
}

/// LITE MODELS: Minimal data package for the evaluation loop to avoid cloning Train classes
struct LiteStop: Codable, Equatable {
    let stationId: String
    var arrival: Double? // timeIntervalSinceReferenceDate
    var departure: Double? // timeIntervalSinceReferenceDate
    var extraDwell: Double // minutes
    var track: String
    let isManualTrack: Bool
    let isPreferredTrack: Bool
    let isSkipped: Bool
    let minDwell: Double
    let plannedArrival: Double?
    let plannedDeparture: Double?
}

struct LiteTrain: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let lineId: String?
    var departureTime: Double
    var stops: [LiteStop]
    let maxSpeed: Double
    let acceleration: Double
    let deceleration: Double
}

struct Chromosome {
    var genes: [TrainGene]
    var fitness: Double = 0.0
    var conflictingTrainIds: Set<UUID> = []
    var conflictLocations: [UUID: Set<String>] = [:] // trainId -> Set of resourceIds
}
