import Foundation

public enum TrainCategory: String, CaseIterable, Identifiable, Codable {
    case regional = "Regionale"
    case direct = "Diretto"
    case highSpeed = "Alta Velocità"
    case freight = "Merci"
    case support = "Supporto"

    public var id: String { rawValue }

    public var defaultMaxSpeed: Int {
        switch self {
        case .highSpeed: return 300
        case .regional: return 140
        case .direct: return 160
        case .freight: return 100
        case .support: return 80
        }
    }

    public var defaultPriority: Int {
        switch self {
        case .highSpeed: return 10
        case .direct: return 7
        case .regional: return 5
        case .freight: return 3
        case .support: return 1
        }
    }
}
