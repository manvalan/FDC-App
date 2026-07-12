import Foundation

public struct Switch: Identifiable, Codable, Hashable {
    public let id: UUID
    public let nodeId: String
    public var state: SwitchState = .normal
    public let connectedEdges: [UUID]

    public enum SwitchState: String, Codable {
        case normal, reverse
    }
}
