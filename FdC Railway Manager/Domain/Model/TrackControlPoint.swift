import Foundation

/// A waypoint on a track segment with geographic position and optional altitude.
public struct TrackControlPoint: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double?

    public init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
}
