import Foundation

public struct TrackSegment: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var order: Int
    public var length: Double
    public var isOccupied: Bool = false
    public var signal: Signal?
    public var speedLimit: Int?

    enum CodingKeys: String, CodingKey {
        case id, order, length, isOccupied, signal, speedLimit
    }

    public init(
        id: UUID = UUID(), order: Int, length: Double,
        isOccupied: Bool = false, signal: Signal? = nil, speedLimit: Int? = nil
    ) {
        self.id = id
        self.order = order
        self.length = length
        self.isOccupied = isOccupied
        self.signal = signal
        self.speedLimit = speedLimit
    }
}
