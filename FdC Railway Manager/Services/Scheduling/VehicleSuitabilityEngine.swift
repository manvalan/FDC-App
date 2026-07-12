import Foundation
import FDCDomain

/// Motore per il calcolo dell'idoneità dei veicoli rispetto alle caratteristiche di una linea.
public struct VehicleSuitabilityEngine {
    private let kinematicCalculator: KinematicCalculator

    public init(kinematicCalculator: KinematicCalculator) {
        self.kinematicCalculator = kinematicCalculator
    }

    public func calculateSuitabilityScore(
        vehicle: Vehicle,
        lineMaxSpeed: Double,
        stationSequence: [String],
        estimatedDistance: Double,
        isLineElectrified: Bool
    ) -> Double {
        let speedScore = scoreForSpeedMatch(vehicle: vehicle, lineMaxSpeed: lineMaxSpeed)
        let altitudeScore = scoreForAltitude(vehicle: vehicle, stationSequence: stationSequence)
        let stopScore = scoreForStopSpacing(vehicle: vehicle, lineMaxSpeed: lineMaxSpeed, stationSequence: stationSequence, estimatedDistance: estimatedDistance)
        let elecScore = scoreForElectrification(vehicle: vehicle, isLineElectrified: isLineElectrified)

        return speedScore + altitudeScore + stopScore + elecScore
    }

    private func scoreForSpeedMatch(vehicle: Vehicle, lineMaxSpeed: Double) -> Double {
        max(0, 100 - abs(vehicle.maxSpeed - lineMaxSpeed)) * 0.35
    }

    private func scoreForAltitude(vehicle: Vehicle, stationSequence: [String]) -> Double {
        let altInfo = kinematicCalculator.calculateAltitudeCharacteristics(stationSequence: stationSequence)
        guard let maxGrad = altInfo.maxGradient else { return 0 }

        let multiplier: Double
        if maxGrad > 25      { multiplier = 40 }
        else if maxGrad > 15 { multiplier = 30 }
        else if maxGrad > 10 { multiplier = 20 }
        else                 { return 50 * 0.15 }

        return min(vehicle.acceleration * multiplier, 100) * 0.15
    }

    private func scoreForStopSpacing(vehicle: Vehicle, lineMaxSpeed: Double, stationSequence: [String], estimatedDistance: Double) -> Double {
        let stopCount = max(stationSequence.count - 1, 1)
        let avgDist = estimatedDistance / Double(stopCount)

        if avgDist < 10 {
            return min(vehicle.acceleration * 30, 100) * 0.25
        } else if avgDist < 20 {
            let accelPart = min(vehicle.acceleration * 20, 100) * 0.15
            let speedPart = min((vehicle.maxSpeed / lineMaxSpeed) * 50, 50) * 0.1
            return accelPart + speedPart
        } else {
            return min((vehicle.maxSpeed / lineMaxSpeed) * 100, 100) * 0.25
        }
    }

    private func scoreForElectrification(vehicle: Vehicle, isLineElectrified: Bool) -> Double {
        let rawScore: Double
        if isLineElectrified == vehicle.isElectric { rawScore = 25 }
        else if isLineElectrified                  { rawScore = 10 }
        else                                       { rawScore = -100 }
        return rawScore * 0.10
    }
}
