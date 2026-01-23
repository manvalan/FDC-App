import Foundation
import Combine

struct Train: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: String
    var maxSpeed: Int
    var priority: Int = 5 // 1-10, 10 is max priority (AV)
    var acceleration: Double = 0.5 // m/s^2
    var deceleration: Double = 0.5 // m/s^2
    
    init(id: UUID, name: String, type: String, maxSpeed: Int, priority: Int = 5, acceleration: Double = 0.5, deceleration: Double = 0.5) {
        self.id = id
        self.name = name
        self.type = type
        self.maxSpeed = maxSpeed
        self.priority = priority
        self.acceleration = acceleration
        self.deceleration = deceleration
    }
}

@MainActor
final class TrainManager: ObservableObject {
    @Published var trains: [Train] = []
    init() {}
}
