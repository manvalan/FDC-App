import SwiftUI

struct FdCTheme: Equatable {
    var background: Color = Color(hex: "#F2F5F8")! // Default App Background
    var surface: Color = Color(hex: "#FFFFFF")!    // Card Surface
    var light: Color = Color(hex: "#E5E7EB")!      // Subtle Dividers / Unselected background
    var medium: Color = Color(hex: "#9CA3AF")!     // Secondary icons / text

    var dark: Color = Color(hex: "#4B5563")!       // Primary content / Sidebar labels
    var accent: Color = Color.blue                 // Selected items
    var line: Color = Color(hex: "#111827")!       // Graph Lines / Very dark accents
    var backgroundSecondary: Color = Color(hex: "#E5E7EB")! // Slightly darker/lighter background for contrast
    
    static let light = FdCTheme(
        background: Color(hex: "#F2F5F8")!,
        surface: Color(hex: "#FFFFFF")!,
        light: Color(hex: "#E5E7EB")!,
        medium: Color(hex: "#9CA3AF")!,
        dark: Color(hex: "#4B5563")!,
        accent: Color.blue,
        line: Color(hex: "#111827")!,
        backgroundSecondary: Color(hex: "#E5E7EB")!
    )
    
    static let dark = FdCTheme(
        background: Color(hex: "#1F2937")!,
        surface: Color(hex: "#374151")!,
        light: Color(hex: "#4B5563")!,
        medium: Color(hex: "#9CA3AF")!,
        dark: Color(hex: "#E5E7EB")!,
        accent: Color.blue,
        line: Color(hex: "#F9FAFB")!,
        backgroundSecondary: Color(hex: "#111827")!
    )
    
    static func == (lhs: FdCTheme, rhs: FdCTheme) -> Bool {
        // Simple comparison based on background color
        lhs.background == rhs.background && lhs.surface == rhs.surface
    }
}
