import SwiftUI

extension RailwayLine {
    public var displayColor: Color {
        color.flatMap { Color(hex: $0) } ?? .gray
    }
}
