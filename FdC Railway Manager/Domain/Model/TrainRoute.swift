import Foundation
import SwiftUI

// MARK: - TrainRoute (Service Route Template)

/// A TrainRoute is a lightweight template that defines a service path
/// from an origin station to a destination station, through an ordered
/// sequence of intermediate stations.
///
/// It is used only as a **template** to guide timetable creation:
/// - The actual track assignment and stop times are stored in each `Train`'s stops.
/// - The actual next station for a train is determined by its timetable, not by the route.
///
/// A TrainRoute does NOT contain timetable data (no arrival/departure times, no track info).
public struct TrainRoute: Identifiable, Codable, Hashable {

    public let id: String
    public var name: String
    public var color: String?                   // Hex color for UI display

    // MARK: - Path definition

    public var originStationId: String          // First station of the route
    public var destinationStationId: String     // Last station of the route
    public var stationIds: [String]             // Ordered sequence of station IDs (includes origin and destination)

    // MARK: - Train numbering (optional, for schedule creation defaults)

    public var serviceCodePrefix: String?       // e.g. "RE", "IC", "EC" — prepended to train numbers
    public var numberPrefix: Int?               // e.g. 5 → trains numbered 5001, 5002, 5003...

    // MARK: - Computed

    public var displayColor: Color {
        color.flatMap { Color(hex: $0) } ?? .accentColor
    }

    /// Convenience: intermediate stations (excluding origin and destination)
    public var intermediateStationIds: [String] {
        guard stationIds.count > 2 else { return [] }
        return Array(stationIds.dropFirst().dropLast())
    }

    // MARK: - Init

    public init(
        id: String = UUID().uuidString,
        name: String,
        color: String? = nil,
        originStationId: String = "",
        destinationStationId: String = "",
        stationIds: [String] = [],
        serviceCodePrefix: String? = nil,
        numberPrefix: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.originStationId = originStationId
        self.destinationStationId = destinationStationId
        self.stationIds = stationIds
        self.serviceCodePrefix = serviceCodePrefix
        self.numberPrefix = numberPrefix
    }
}


