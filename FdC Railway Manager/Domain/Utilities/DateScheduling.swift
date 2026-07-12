import Foundation

public extension Date {
    /// Stesso orario su Jan 1 2001 — evita Calendar nei loop di ottimizzazione.
    func schedulingNormalized() -> Date {
        let secondsPerDay: TimeInterval = 86_400
        let secondsSinceRef = timeIntervalSinceReferenceDate
        let dayOffset = secondsSinceRef.truncatingRemainder(dividingBy: secondsPerDay)
        let normalizedSeconds = dayOffset < 0 ? dayOffset + secondsPerDay : dayOffset
        return Date(timeIntervalSinceReferenceDate: normalizedSeconds)
    }
}
