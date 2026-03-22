import SwiftUI

enum MapVisualizationMode: String, CaseIterable {
    case infrastructure
    case scheduler

    var displayName: String {
        switch self {
        case .infrastructure: return "Infrastruttura"
        case .scheduler: return "Train Director"
        }
    }

    var icon: String {
        switch self {
        case .infrastructure: return "road.lanes"
        case .scheduler: return "clock.arrow.circlepath"
        }
    }

    var description: String {
        switch self {
        case .infrastructure: return "Dettagli tecnici: segmenti e segnali"
        case .scheduler: return "Gestione orari e conflitti"
        }
    }

    var isInfrastructureMode: Bool { self == .infrastructure }
    var isSchedulerMode: Bool { self == .scheduler }
}

enum MapEditMode: String, CaseIterable, Identifiable {
    case explore = "explore"
    case addTrack = "create_tracks"
    case addStation = "add_station"
    case createLine = "create_line" 
    case brushPath = "brush_path"
    case erasePath = "erase_path"
    
    var id: String { rawValue }
    
    var title: String {
        self.rawValue.localized
    }
}

struct MapBounds: Sendable {
    let minLat, maxLat, minLon, maxLon: Double
    let xRange, yRange: Double
}

