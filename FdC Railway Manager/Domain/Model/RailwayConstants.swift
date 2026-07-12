import Foundation

/// Core constants for the railway system.
/// Replaces "Magic Numbers" throughout the codebase.
public struct RailwayConstants {
    public static let standardTrackGauge: Double = 1.435
    public static let gravity: Double = 9.81
    public static let degreesToKm: Double = 111.0
    public static let defaultEarthRadius: Double = 6371.0
    public static let standardDwellTime: Int = 3
    public static let interchangeDwellTime: Int = 5
    public static let freightDwellTime: Int = 15
    public static let defaultStationCapacity: Int = 10
    public static let defaultSegmentCapacity: Int = 1
    public static let minTimeStep: Double = 1.0
    public static let maxTimeStep: Double = 60.0
    public static let maxPathAlternativeLengthMultiplier: Double = 1.5
    public static let maxRecursionDepth: Int = 100
}
