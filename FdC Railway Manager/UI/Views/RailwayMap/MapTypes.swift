import SwiftUI

enum MapEditMode: String, CaseIterable, Identifiable {
    case explore = "explore"
    case addTrack = "create_tracks"
    case addStation = "add_station"
    case createLine = "create_line" 
    
    var id: String { rawValue }
    
    var title: String {
        self.rawValue.localized
    }
}

struct MapBounds: Sendable {
    let minLat, maxLat, minLon, maxLon: Double
    let xRange, yRange: Double
}

