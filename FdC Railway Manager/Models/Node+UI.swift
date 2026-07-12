import Foundation

extension Node.StationVisualType {
    public var localizedName: String {
        switch self {
        case .filledStar: return "filled_star".localized
        case .filledSquare: return "filled_square".localized
        case .emptySquare: return "empty_square".localized
        case .filledCircle: return "filled_circle".localized
        case .emptyCircle: return "empty_circle".localized
        }
    }
}

extension Node.HubOffsetDirection {
    public var localizedName: String {
        switch self {
        case .topLeft: return "top_left_offset".localized
        case .topRight: return "top_right_offset".localized
        case .bottomLeft: return "bottom_left_offset".localized
        case .bottomRight: return "bottom_right_offset".localized
        }
    }
}
