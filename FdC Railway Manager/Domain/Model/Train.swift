import Foundation

public struct Train: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var number: Int?
    public var name: String
    public var type: String
    public var routeId: String?
    public var isElectric: Bool = true
    public var departureTime: Date?
    public var stops: [RelationStop] = []
    public var vehicleId: UUID?
    public var maxSpeed: Double = 120
    public var acceleration: Double = 0.5
    public var deceleration: Double = 0.5
    public var mass: Double = 200
    public var power: Double = 2500
    public var priority: Int = 5
    public var isMainTrain: Bool = false
    public var schedulingError: String?

    public init(
        id: UUID = UUID(), number: Int? = nil, name: String, type: String,
        lineId: String? = nil, departureTime: Date? = nil, stops: [RelationStop] = [],
        vehicleId: UUID? = nil, maxSpeed: Double = 160, acceleration: Double = 0.5,
        deceleration: Double = 0.4, mass: Double = 200, power: Double = 2500,
        priority: Int = 5, isElectric: Bool = true, isMainTrain: Bool = false
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.type = type
        self.routeId = lineId
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
        case id, number, name, type, routeId, lineId
        case departureTime, stops, maxSpeed, acceleration, deceleration
        case mass, power, priority, vehicleId, schedulingError, isElectric, isMainTrain
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
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
    func getPreferredTracks(
        at node: Node, prevStationId: String?, nextStationId: String?,
        for route: TrainRoute?, isSkipping: Bool = false
    ) -> [String] {
        let maxPlatforms = node.platforms ?? 2
        let allPlatforms = (1...maxPlatforms).map { "\($0)" }
        let targetRouteId = route?.id ?? self.routeId ?? ""
        let lineConstraints = node.routingConstraints.filter { $0.routeId == targetRouteId }
        let matchingConstraint = lineConstraints.first { $0.directionStationId == nextStationId }
            ?? lineConstraints.first { $0.directionStationId == nil }
        var preferred: [String] = []
        if let constraint = matchingConstraint {
            if isSkipping {
                preferred.append(contentsOf: constraint.transitTracks ?? [])
                preferred.append(contentsOf: constraint.stopTracks ?? [])
                preferred.append(contentsOf: constraint.allowedTracks)
            } else {
                preferred.append(contentsOf: constraint.stopTracks ?? [])
                preferred.append(contentsOf: constraint.transitTracks ?? [])
                preferred.append(contentsOf: constraint.allowedTracks)
            }
        }
        if preferred.isEmpty { return allPlatforms }
        var finalList: [String] = []
        for p in preferred where !finalList.contains(p) { finalList.append(p) }
        for platform in allPlatforms where !finalList.contains(platform) { finalList.append(platform) }
        return finalList
    }

    func isTrackPreferred(
        _ track: String, at node: Node, prevStationId: String?,
        nextStationId: String?, for routeId: String?
    ) -> Bool {
        let targetRouteId = routeId ?? self.routeId ?? ""
        let lineConstraints = node.routingConstraints.filter { $0.routeId == targetRouteId }
        let matchingConstraint = lineConstraints.first { $0.directionStationId == nextStationId }
            ?? lineConstraints.first { $0.directionStationId == nil }
        return matchingConstraint?.allowedTracks.contains(track) ?? false
    }
}
