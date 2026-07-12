import Foundation

/// Core constants for the railway system.
/// Replaces "Magic Numbers" throughout the codebase.
public struct RailwayConstants {
    // Physical Parameters
    static let standardTrackGauge: Double = 1.435 // meters
    static let gravity: Double = 9.81 // m/s^2
    
    // Geometry & Projection
    static let degreesToKm: Double = 111.0 // Approx km per degree of latitude
    static let defaultEarthRadius: Double = 6371.0 // km
    
    // Default Dwell Times (minutes)
    static let standardDwellTime: Int = 3
    static let interchangeDwellTime: Int = 5
    static let freightDwellTime: Int = 15
    
    // Default Capacities
    static let defaultStationCapacity: Int = 10
    static let defaultSegmentCapacity: Int = 1
    
    // Simulation
    static let minTimeStep: Double = 1.0 // seconds
    static let maxTimeStep: Double = 60.0 // seconds
    
    // Paths
    static let maxPathAlternativeLengthMultiplier: Double = 1.5
    static let maxRecursionDepth: Int = 100
}
