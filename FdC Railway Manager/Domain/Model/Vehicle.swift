import Foundation

public struct Vehicle: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var model: String
    public var length: Double = 200
    public var maxSpeed: Double = 160
    public var acceleration: Double = 0.5
    public var deceleration: Double = 0.4
    public var mass: Double = 200
    public var power: Double = 2500
    public var imageName: String?
    public var notes: String?
    public var isElectric: Bool = true

    enum CodingKeys: String, CodingKey {
        case id, name, model, length, maxSpeed, acceleration, deceleration, mass, power, notes, imageName, isElectric
    }

    public init(
        id: UUID = UUID(), name: String, model: String, length: Double = 200,
        maxSpeed: Double = 160, acceleration: Double = 0.5, deceleration: Double = 0.4,
        mass: Double = 200, power: Double = 2500, isElectric: Bool = true,
        imageName: String? = nil, notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.length = length
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.mass = mass
        self.power = power
        self.isElectric = isElectric
        self.imageName = imageName
        self.notes = notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        model = try container.decode(String.self, forKey: .model)
        length = try container.decodeIfPresent(Double.self, forKey: .length) ?? 200
        maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed) ?? 160
        acceleration = try container.decodeIfPresent(Double.self, forKey: .acceleration) ?? 0.5
        deceleration = try container.decodeIfPresent(Double.self, forKey: .deceleration) ?? 0.4
        mass = try container.decodeIfPresent(Double.self, forKey: .mass) ?? 200
        power = try container.decodeIfPresent(Double.self, forKey: .power) ?? 2500
        isElectric = try container.decodeIfPresent(Bool.self, forKey: .isElectric) ?? true
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}
