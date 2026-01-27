import Foundation

// MARK: - Optimizer Request Schema (Integer Based)

struct OptimizerRequest: Codable {
    let trains: [OptimizerTrain]
    let tracks: [OptimizerTrack]
    let stations: [OptimizerStation]
    let max_iterations: Int
    let ga_max_iterations: Int?
    let ga_population_size: Int?
    
    enum CodingKeys: String, CodingKey {
        case trains, tracks, stations
        case max_iterations = "max_iterations"
        case ga_max_iterations = "ga_max_iterations"
        case ga_population_size = "ga_population_size"
    }
}

struct OptimizerTrain: Codable {
    let id: Int
    let position_km: Double
    let velocity_kmh: Double
    let current_track: Int
    let destination_station: Int
    let delay_minutes: Int
    let priority: Int
    let is_delayed: Bool
    
    // New fields for scheduled optimization
    let origin_station: Int?
    let scheduled_departure_time: String?
    let route: [Int]?
    let min_dwell_minutes: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, priority
        case position_km
        case velocity_kmh
        case current_track
        case destination_station
        case delay_minutes
        case is_delayed
        case origin_station
        case scheduled_departure_time
        case route = "planned_route"
        case min_dwell_minutes
    }
}

struct OptimizerTrack: Codable {
    let id: Int
    let length_km: Double
    let is_single_track: Bool
    let capacity: Int
    let station_ids: [Int]
    let max_speed: Int
}

struct OptimizerStation: Codable {
    let id: Int
    let name: String
    let num_platforms: Int
}

// MARK: - Optimizer Response Schema

struct OptimizerResponse: Codable {
    let success: Bool
    let resolutions: [OptimizerResolution]
    let total_delay_minutes: Double
    let inference_time_ms: Double
    let conflicts_detected: Int
    let conflicts_resolved: Int
    let timestamp: String
}

struct OptimizerResolution: Codable {
    let trainId: Int
    let timeAdjustmentMin: Double
    let trackAssignment: Int?
    let confidence: Double
    let dwellDelays: [Double]?
    
    enum CodingKeys: String, CodingKey {
        case trainId = "train_id"
        case timeAdjustmentMin = "time_adjustment_min"
        case trackAssignment = "track_assignment"
        case confidence
        case dwellDelays = "dwell_delays"
    }
}
