import Foundation
import Combine

struct Train: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: String
    var maxSpeed: Int
}

final class TrainManager: ObservableObject {
    @Published var trains: [Train] = []
    init() {}
}
