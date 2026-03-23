import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public struct TrackSegment: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var order: Int
    public var length: Double // km
    public var isOccupied: Bool = false
    public var signal: Signal?
    
    // Physical Properties
    /// Altitude in metres. Retained for legacy file compatibility until
    /// AltimetricProfileView is migrated to Edge.controlPoints in Phase 3c.
    public var altitude: Double?
    public var speedLimit: Int?

    enum CodingKeys: String, CodingKey {
        case id, order, length, isOccupied, signal, altitude, speedLimit
    }

    public init(
        id: UUID = UUID(),
        order: Int,
        length: Double,
        isOccupied: Bool = false,
        signal: Signal? = nil,
        altitude: Double? = nil,
        speedLimit: Int? = nil
    ) {
        self.id = id
        self.order = order
        self.length = length
        self.isOccupied = isOccupied
        self.signal = signal
        self.altitude = altitude
        self.speedLimit = speedLimit
    }
}
