import Foundation

public protocol TrainTravelTimeCalculating: Sendable {
    func travelTimeHours(
        distanceKm: Double,
        maxSpeedKmh: Double,
        train: Train,
        initialSpeedKmh: Double,
        finalSpeedKmh: Double,
        gradient: Double
    ) -> Double

    func travelTimeBetweenNodes(
        from: String,
        to: String,
        train: Train,
        nodes: [Node],
        edges: [Edge],
        isStarting: Bool,
        isStopping: Bool
    ) -> TimeInterval
}
