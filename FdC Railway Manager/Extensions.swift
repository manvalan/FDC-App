import SwiftUI
import Foundation
import UIKit

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
    
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX",
                          lroundf(r * 255),
                          lroundf(g * 255),
                          lroundf(b * 255),
                          lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX",
                          lroundf(r * 255),
                          lroundf(g * 255),
                          lroundf(b * 255))
        }
    }
}

extension Date {
    private static let referenceDateJan1st2001: TimeInterval = 0.0 // Jan 1st 2001 00:00:00 UTC
    private static let secondsPerDay: TimeInterval = 86400.0

    /// Returns a date with the SAME time but fixed to Jan 1st 2001 (High Performance)
    /// This avoids slow Calendar/DateComponents calls in optimization loops.
    func normalized() -> Date {
        let secondsPerDay: TimeInterval = 86400.0
        let secondsSinceRef = self.timeIntervalSinceReferenceDate
        // Use floor and remainder to get seconds since the start of whichever day 'self' belongs to.
        // Then add to our fixed reference date (Jan 1 2001).
        let dayOffset = secondsSinceRef.truncatingRemainder(dividingBy: secondsPerDay)
        let normalizedSeconds = dayOffset < 0 ? dayOffset + secondsPerDay : dayOffset
        return Date(timeIntervalSinceReferenceDate: normalizedSeconds)
    }
    
    /// Returns a date rounded to the nearest minute, clearing seconds and milliseconds.
    /// Crucial for consistency between table, graph and inspector.
    func cleanSeconds() -> Date {
        let secondsSinceRef = self.timeIntervalSinceReferenceDate
        let rounded = floor(secondsSinceRef / 60.0 + 0.5) * 60.0
        return Date(timeIntervalSinceReferenceDate: rounded)
    }
    
    var timeFormat: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: self)
    }
}

struct IdentifiableString: Identifiable {
    let id: String
}
