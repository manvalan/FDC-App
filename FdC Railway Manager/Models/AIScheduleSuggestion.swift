import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

struct AIScheduleSuggestion: Identifiable, Codable {
    var id: UUID = UUID()
    let trainId: UUID
    let newDepartureTime: String // HH:mm
    let stopAdjustments: [StopAdjustment]?
    
    struct StopAdjustment: Codable {
        let stationId: String
        let newMinDwellTime: Int
    }
}
