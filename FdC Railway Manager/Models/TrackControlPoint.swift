import Foundation

/// A waypoint on a track segment with geographic position and optional altitude.
///
/// Replaces the split between `Edge.GeometryPoint` (lat/lon only, visual curve)
/// and the lat/lon/altitude fields of `TrackSegment` (simulation block with
/// altimetric data). A `TrackControlPoint` unifies both concerns: it drives
/// the map curve geometry AND carries the altimetric profile of the track.
///
/// - `altitude == nil` means the point's elevation is linearly interpolated
///   between the two adjacent station nodes (`Node.altitude`).
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
