import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public struct Vehicle: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var name: String // Matricola o Nome (es: "ETR521 #042")
    public var model: String // Modello (es: "Pop", "Rock", "Minuetto")
    public var length: Double = 200 // Lunghezza in metri
    public var maxSpeed: Double = 160
    public var acceleration: Double = 0.5
    public var deceleration: Double = 0.4
    public var mass: Double = 200 // Massa in tonnellate
    public var power: Double = 2500 // Potenza in kW
    public var imageName: String? // Optional image name or path
    
    // Per gestire il giro macchina
    public var notes: String?
    public var isElectric: Bool = true // Se il mezzo è elettrico o diesel
    
    enum CodingKeys: String, CodingKey {
        case id, name, model, length, maxSpeed, acceleration, deceleration, mass, power, notes, imageName, isElectric
    }
    
    public init(id: UUID = UUID(), name: String, model: String, length: Double = 200, maxSpeed: Double = 160, acceleration: Double = 0.5, deceleration: Double = 0.4, mass: Double = 200, power: Double = 2500, isElectric: Bool = true, imageName: String? = nil, notes: String? = nil) {
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
