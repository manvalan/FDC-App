import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct TrackSnippet: Decodable {
    let from: String
    let to: String
    let distance: Double
    let maxSpeed: Int
    let type: String?
}
