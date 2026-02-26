import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public enum TrainCategory: String, CaseIterable, Identifiable {
    case regional = "Regionale"
    case direct = "Diretto"
    case highSpeed = "Alta Velocità"
    case freight = "Merci"
    case support = "Supporto"
    
    public var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .regional: return "regional_train".localized
        case .direct: return "intercity_train".localized
        case .highSpeed: return "highspeed_train".localized
        case .freight: return "freight_train".localized
        case .support: return "support_train".localized
        }
    }
    
    var defaultMaxSpeed: Int {
        switch self {
        case .highSpeed: return 300
        case .regional: return 140
        case .direct: return 160
        case .freight: return 100
        case .support: return 80
        }
    }
    
    var defaultPriority: Int {
        switch self {
        case .highSpeed: return 10
        case .direct: return 7
        case .regional: return 5
        case .freight: return 3
        case .support: return 1
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
