import Foundation

// MARK: - RailwayAI V2 API Models (PIGNOLO PROTOCOL SYNC)

/// Request for optimization (Standard & Advanced unified to V2 Scheduled Schema)
struct RailwayAIRequest: Codable {
    let trains: [RailwayAITrainInfo]
    let tracks: [RailwayAITrackInfo]
    let stations: [RailwayAIStationInfo]
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

struct RailwayAIStationInfo: Codable {
    let id: Int
    let name: String
    let num_platforms: Int
}

struct RailwayAITrackInfo: Codable {
    let id: Int
    let station_ids: [Int]
    let length_km: Double
    let is_single_track: Bool
    let capacity: Int
}

struct RailwayAITrainInfo: Codable {
    let id: Int
    let priority: Int
    let position_km: Double
    let velocity_kmh: Double
    let current_track: Int
    let destination_station: Int
    let delay_minutes: Int
    let is_delayed: Bool
    
    // New fields for scheduled optimization
    let origin_station: Int
    let scheduled_departure_time: String
    let planned_route: [Int]
    let min_dwell_minutes: Int
    
    enum CodingKeys: String, CodingKey {
        case id, priority, position_km, velocity_kmh, current_track, destination_station, delay_minutes, is_delayed
        case origin_station, scheduled_departure_time
        case planned_route = "planned_route"
        case min_dwell_minutes
    }
}

/// Response from optimization
struct RailwayAIResponse: Codable {
    let success: Bool
    let total_delay_minutes: Double?
    let resolutions: [RailwayAIResolution]?
    let inference_time_ms: Double?
    let conflicts_detected: Int?
    let conflicts_resolved: Int?
    let error_message: String?
    
    // Legacy support for V1 UI components
    let ml_confidence: Double?
    let modifications: [RailwayAIModification]?
    let conflict_analysis: RailwayAIConflictAnalysis?
    let total_impact_minutes: Double?
    
    enum CodingKeys: String, CodingKey {
        case success
        case total_delay_minutes = "total_delay_minutes"
        case resolutions
        case inference_time_ms = "inference_time_ms"
        case conflicts_detected = "conflicts_detected"
        case conflicts_resolved = "conflicts_resolved"
        case error_message = "error_message"
        case ml_confidence = "ml_confidence"
        case modifications
        case conflict_analysis = "conflict_analysis"
        case total_impact_minutes = "total_impact_minutes"
    }
}

struct RailwayAIResolution: Codable {
    let train_id: Int
    let time_adjustment_min: Double
    let track_assignment: Int?
    let dwell_delays: [Double]?
}

// MARK: - Legacy V1 Models (Keeping for compatibility during transition if needed)
// These might be removed later if we fully commit to V2 Scheduled

struct RailwayAIModification: Codable, Identifiable {
    let id = UUID()
    let train_id: String
    let modification_type: String
    let section: RailwayAISection
    let parameters: [String: AnyCodable]
    let impact: RailwayAIImpact
    let reason: String
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case train_id, modification_type, section, parameters, impact, reason, confidence
    }
}

struct RailwayAISection: Codable {
    let station: String?
    let from_station: String?
    let to_station: String?
}

struct RailwayAIImpact: Codable {
    let time_increase_seconds: Int
    let affected_stations: [String]
    let passenger_impact_score: Double?
}

struct RailwayAIConflictAnalysis: Codable {
    let original_conflicts: Int
    let resolved_conflicts: Int
    let remaining_conflicts: Int
}

// MARK: - Admin API Models
struct AdminUser: Codable, Identifiable {
    let username: String
    let is_active: Bool
    
    var id: String { username }
}

struct AddUserRequest: Codable {
    let username: String
    let password: String
}

// MARK: - Scenario & Training Models
struct ScenarioGenerateRequest: Codable {
    let area: String
}

struct TrainRequest: Codable {
    let scenario_path: String
}

struct OptimizeRequestWithScenario: Codable {
    let scenario_path: String
}

// MARK: - WebSocket Messages
struct WSMessage: Codable {
    let type: String
    let level: String?
    let message: String?
    let scenario_path: String?
    let training_update: TrainingUpdate?
    
    let episode: Int?
    let reward: Double?
    let conflicts: Int?
}

struct TrainingUpdate: Codable {
    let episode: Int
    let reward: Double
    let conflicts: Int
}

// MARK: - AnyCodable for dynamic parameters
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Bool.self) {
            value = x
        } else if let x = try? container.decode(Int.self) {
            value = x
        } else if let x = try? container.decode(Double.self) {
            value = x
        } else if let x = try? container.decode(String.self) {
            value = x
        } else if let x = try? container.decode([String: AnyCodable].self) {
            value = x.mapValues { $0.value }
        } else if let x = try? container.decode([AnyCodable].self) {
            value = x.map { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for AnyCodable"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let x = value as? Bool {
            try container.encode(x)
        } else if let x = value as? Int {
            try container.encode(x)
        } else if let x = value as? Double {
            try container.encode(x)
        } else if let x = value as? String {
            try container.encode(x)
        } else if let x = value as? [String: Any] {
            try container.encode(x.mapValues { AnyCodable($0) })
        } else if let x = value as? [Any] {
            try container.encode(x.map { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}
