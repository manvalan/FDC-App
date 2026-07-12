import SwiftUI

extension TrainRoute {
    public var displayColor: Color {
        color.flatMap { Color(hex: $0) } ?? .accentColor
    }
}
