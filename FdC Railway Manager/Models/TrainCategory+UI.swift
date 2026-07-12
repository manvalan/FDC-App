import SwiftUI

extension TrainCategory {
    var localizedName: String {
        switch self {
        case .regional: return "regional_train".localized
        case .direct: return "intercity_train".localized
        case .highSpeed: return "highspeed_train".localized
        case .freight: return "freight_train".localized
        case .support: return "support_train".localized
        }
    }

    var color: Color {
        switch self {
        case .highSpeed: return .red
        case .direct: return .orange
        case .regional: return .green
        case .freight: return .indigo
        case .support: return .brown
        }
    }
}
