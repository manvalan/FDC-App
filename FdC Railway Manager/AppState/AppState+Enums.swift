import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case stations   = "stazioni"
    case tracks     = "binari"
    case infraLines = "ferrovie"     // physical infrastructure lines (ex ferrovie)
    case routes     = "routes"       // service route templates (ex lines)
    case lines      = "lines"        // kept for backward compat (legacy sidebar state)
    case vehicles   = "materiale_rotabile"
    case trains     = "trains"
    case timetable  = "tabella_oraria"
    case diagram    = "grafico_orario"
    case ai         = "railway_ai"
    case io         = "io"
    case settings   = "settings"
    case simulation = "simulation"
    
    var id: String { rawValue }
    
    var title: String {
        return self.rawValue.localized
    }
    
    var icon: String {
        switch self {
        case .stations:   return "building.2"
        case .tracks:     return "tram"
        case .infraLines: return "map.fill"
        case .routes:     return "signpost.right.and.left"
        case .lines:      return "point.topleft.down.to.point.bottomright.curvepath"
        case .vehicles:   return "tram.fill"
        case .trains:     return "train.side.front.car"
        case .timetable:  return "tablecells"
        case .diagram:    return "chart.xyaxis.line"
        case .ai:         return "sparkles"
        case .io:         return "doc.badge.arrow.up"
        case .simulation: return "play.desktopcomputer"
        case .settings:   return "gear"
        }
    }

    var isNetworkCategory: Bool {
        switch self {
        case .stations, .tracks, .infraLines:
            return true
        default:
            return false
        }
    }
}

enum AppMode: String, CaseIterable, Identifiable {
    case design, schedule, live, editor
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .design: return "Progetto"
        case .schedule: return "Programmazione"
        case .live: return "Esercizio"
        case .editor: return "Modifica"
        }
    }
}
enum DesignSubMode: String, CaseIterable, Identifiable {
    case infrastructure, services
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .infrastructure: return "Mappa"
        case .services: return "Linee & Profilo"
        }
    }
}
