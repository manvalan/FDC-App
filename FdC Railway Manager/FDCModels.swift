import Foundation

enum FDCParserError: Error {
    case invalidData
    case empty
}

struct FDCStation: Codable, Hashable {
    var id: String
    var name: String
    var type: String?
    var latitude: Double?
    var longitude: Double?
    var capacity: Int?
    var platformCount: Int?
}

struct FDCEdge: Codable, Hashable {
    var from: String
    var to: String
    var distance: Double?
    var trackType: String?
    var maxSpeed: Double?
    var capacity: Int?
    var bidirectional: Bool?
}

struct FDCTrain: Codable, Hashable {
    var id: String
    var name: String
    var type: String?
    var maxSpeed: Int?
    var acceleration: Double?
    var deceleration: Double?
    var priority: Int?
}

struct FDCTimetableEntry: Codable, Hashable {
    var trainId: String
    var stationId: String
    var time: String
}

struct FDCNetworkParsed {
    var name: String
    var stations: [FDCStation]
    var edges: [FDCEdge]
    var trains: [FDCTrain]
    var rawSchedules: [FDCScheduleData]
    var lines: [RailwayLine]
}

// MARK: - FDC File Structures (Official)

struct FDCFileRoot: Codable {
    let network: FDCNetworkData
    let trains: [FDCTrainData]
    let lines: [FDCLineData]?
    let schedules: [FDCScheduleData]?
}

struct FDCNetworkData: Codable {
    let nodes: [FDCNodeData]
    let edges: [FDCEdgeData]
}

struct FDCNodeData: Codable {
    let id: String
    let name: String
    let type: String
    let latitude: Double?
    let longitude: Double?
    let capacity: Int?
    let platform_count: Int?
    let platforms: Int? // legacy support
}

struct FDCEdgeData: Codable {
    let from_node: String
    let to_node: String
    let distance: Double
    let track_type: String
    let max_speed: Double
    let capacity: Int?
    let bidirectional: Bool
}

struct FDCTrainData: Codable {
    let id: String
    let name: String
    let type: String
    let max_speed: Double
    let acceleration: Double?
    let deceleration: Double?
    let priority: Int?
}

struct FDCLineData: Codable {
    let id: String
    let name: String
    let color: String?
    let stations: [String]
}

struct FDCScheduleData: Codable {
    let schedule_id: String
    let train_id: String
    let stops: [FDCStopData]
}

struct FDCStopData: Codable {
    let node_id: String
    let arrival: String
    let departure: String
    let is_stop: Bool
    let platform: Int?
}
