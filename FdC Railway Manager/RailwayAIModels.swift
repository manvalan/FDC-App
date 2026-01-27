import Foundation

// MARK: - RailwayAI V2 API Models

/// Request for optimization
struct RailwayAIRequest: Codable {
    let conflicts: [RailwayAIConflictInput]
    let network: RailwayAINetworkInfo
    let preferences: [String: AnyCodable]?
}

struct RailwayAIConflictInput: Codable {
    let conflict_type: String
    let location: String
    let trains: [RailwayAITrainInfo]
    let severity: String
    let time_overlap_seconds: Int?
}

struct RailwayAITrainInfo: Codable {
    let train_id: String
    let arrival: String?
    let departure: String?
    let platform: Int?
    let current_speed_kmh: Double?
    let priority: Int
}

struct RailwayAINetworkInfo: Codable {
    let stations: [String]
    let available_platforms: [String: [Int]]
    let max_speeds: [String: Double]
}

/// Response from optimization
struct RailwayAIResponse: Codable {
    let success: Bool
    let total_impact_minutes: Double?
    let ml_confidence: Double?
    let modifications: [RailwayAIModification]?
    let conflict_analysis: RailwayAIConflictAnalysis?
    let error_message: String?
}

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
    
    // Support for training_update directly in the message or nested
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
            // Nil or unknown
            try container.encodeNil()
        }
    }
}
