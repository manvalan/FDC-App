import Foundation

public struct Signal: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String

    public enum SignalAspect: String, Codable {
        case stop, proceed, caution
    }

    public var aspect: SignalAspect = .stop
    public let positionAtEnd: Bool

    public init(id: UUID, name: String, aspect: SignalAspect = .stop, positionAtEnd: Bool) {
        self.id = id
        self.name = name
        self.aspect = aspect
        self.positionAtEnd = positionAtEnd
    }
}
